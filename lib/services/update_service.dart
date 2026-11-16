import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_update.dart';
import '../models/release.dart';

/// 公开 Release 在线更新服务。
///
/// 更新检查不需要登录，也不会发送任何 Token。GitHub 是唯一发行通道：
/// 先查 REST API，不可达时回退 GitHub 网页版发布页。
class UpdateService {
  static final shared = UpdateService();

  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  static const repositoryOwner = 'yuchen0x1';
  static const repositoryName = 'Gitee-Android';
  static const githubLatestReleaseUrl =
      'https://api.github.com/repos/$repositoryOwner/$repositoryName/releases/latest';
  static const githubReleasesApiUrl =
      'https://api.github.com/repos/$repositoryOwner/$repositoryName/releases';
  static const githubLatestReleasePageUrl =
      'https://github.com/$repositoryOwner/$repositoryName/releases/latest';
  static const githubReleasesAtomUrl =
      'https://github.com/$repositoryOwner/$repositoryName/releases.atom';
  static const githubReleasePageBaseUrl =
      'https://github.com/$repositoryOwner/$repositoryName/releases';

  static const _allowedHosts = {'github.com', 'api.github.com'};
  static const _allowedDownloadHosts = {
    'github.com',
    'api.github.com',
    'objects.githubusercontent.com',
    'github-releases.githubusercontent.com',
    'release-assets.githubusercontent.com',
  };
  static const _requestUserAgent = 'Gitee-Client-Update-Checker';

  final http.Client _client;
  AppUpdate? _cachedUpdate;
  String? _cachedForVersion;
  DateTime? _lastCheckedAt;
  Future<AppUpdate?>? _checking;

  static const cacheDuration = Duration(minutes: 10);

  Future<AppUpdate?> checkForUpdate({
    String? currentVersion,
    bool forceRefresh = false,
  }) async {
    final version = currentVersion ?? (await _currentVersion());
    final lastChecked = _lastCheckedAt;
    if (!forceRefresh &&
        _cachedForVersion == version &&
        lastChecked != null &&
        DateTime.now().difference(lastChecked) < cacheDuration) {
      return _cachedUpdate;
    }
    final pending = _checking;
    if (pending != null) return pending;

    final future = _checkForUpdate(version);
    _checking = future;
    try {
      final result = await future;
      _cachedUpdate = result;
      _cachedForVersion = version;
      _lastCheckedAt = DateTime.now();
      return result;
    } finally {
      _checking = null;
    }
  }

  Future<AppUpdate?> _checkForUpdate(String version) async {
    try {
      final release = await _fetchGitHubRelease();
      // GitHub 是唯一发行通道：成功返回即以它为准。
      return _newerReleaseOrNull(release, version);
    } catch (_) {
      // API 受限、限流或不可达时回退 GitHub 网页版发布页。
    }
    return _checkGitHubReleasePage(version);
  }

  Future<AppUpdate> _fetchGitHubRelease() async {
    final response = await _client.get(
      _validatedUri(githubLatestReleaseUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': _requestUserAgent,
      },
    ).timeout(const Duration(seconds: 6));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UpdateCheckException('更新服务暂时不可用（${response.statusCode}）');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const UpdateCheckException('更新服务返回了无效数据');
    }
    return AppUpdate.fromGitHubJson(Map<String, dynamic>.from(decoded));
  }

  /// 网页版兜底：/releases/latest 会 302 到 /releases/tag/{tag}，
  /// 且不占用 REST API 的匿名限流配额。
  Future<AppUpdate?> _checkGitHubReleasePage(String currentVersion) async {
    final response = await _client.get(
      _validatedUri(githubLatestReleasePageUrl),
      headers: const {'User-Agent': _requestUserAgent},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw UpdateCheckException('更新服务暂时不可用（${response.statusCode}）');
    }

    final finalUrl = response.request?.url.toString() ?? '';
    final page = utf8.decode(response.bodyBytes);
    final match =
        RegExp(r'/releases/tag/([^"?#/<]+)').firstMatch('$finalUrl\n$page');
    if (match == null) return null;
    final version = Uri.decodeComponent(match.group(1)!);
    return _newerReleaseOrNull(
      AppUpdate(
        version: version,
        name: version,
        notes: '',
        htmlUrl: finalUrl.isEmpty ? githubLatestReleasePageUrl : finalUrl,
        publishedAt: '',
        assets: const [],
      ),
      currentVersion,
    );
  }

  /// 更新日志：分页列出仓库全部版本发布。
  /// 优先 REST API；被限流或不可达时回退 Releases 的 Atom Feed
  /// （普通网页资源，不占用 API 匿名限流配额，但不含安装包附件）。
  Future<List<Release>> fetchReleases({int page = 1, int perPage = 20}) async {
    try {
      return await _fetchReleasesViaApi(page: page, perPage: perPage);
    } catch (_) {
      // API 受限、限流或不可达时回退 Releases Atom Feed。
    }
    return _fetchReleasesViaAtom(page);
  }

  /// Downloads and verifies an APK. The file is never offered to Android's
  /// installer until a SHA-256 value from the Release metadata or checksum
  /// sidecar matches the downloaded bytes.
  Future<File> downloadApk(
    AppUpdate update, {
    required AppUpdateAsset asset,
    void Function(int received, int total, double? bytesPerSecond)? onProgress,
    int maxAttempts = 3,
  }) async {
    if (!asset.name.toLowerCase().endsWith('.apk')) {
      throw const UpdateDownloadException('发布资产不是 Android APK');
    }
    final uri = _validatedDownloadUri(asset.url);
    final expected = await _expectedSha256(update, asset);
    if (expected == null) {
      throw const UpdateDownloadException('发布资产缺少 SHA-256 校验值');
    }
    final directory = await getTemporaryDirectory();
    final safeName = asset.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${directory.path}/$safeName');
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _downloadToFile(uri, file, onProgress: onProgress);
        final actual = await _sha256File(file);
        if (actual != expected) {
          await _deleteQuietly(file);
          throw const UpdateDownloadException('下载文件 SHA-256 校验失败');
        }
        if (asset.size > 0 && await file.length() != asset.size) {
          await _deleteQuietly(file);
          throw const UpdateDownloadException('下载文件大小校验失败');
        }
        return file;
      } catch (error) {
        lastError = error;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }
    throw lastError is UpdateDownloadException
        ? lastError
        : UpdateDownloadException('下载更新失败：$lastError');
  }

  Future<String?> _expectedSha256(
    AppUpdate update,
    AppUpdateAsset asset,
  ) async {
    if (asset.sha256 != null) return asset.sha256;
    final checksum = update.checksumAssetFor(asset);
    if (checksum == null) return null;
    final response = await _client.get(
      _validatedDownloadUri(checksum.url),
      headers: const {'User-Agent': _requestUserAgent},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final text = utf8.decode(response.bodyBytes);
    final matches = <String>{};
    final expectedName = asset.name.toLowerCase();
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final match =
          RegExp(r'^\s*([0-9a-fA-F]{64})\s+[*]?(.+?)\s*$').firstMatch(line);
      if (match == null) continue;
      final fileName = match.group(2)!.trim().replaceAll('\\', '/');
      final baseName = fileName.split('/').last.toLowerCase();
      if (baseName == expectedName) {
        matches.add(match.group(1)!.toLowerCase());
      }
    }
    // A checksum sidecar may contain many assets. Never use the first hash as
    // a positional fallback: an unrelated hash must not be accepted for this
    // APK, and conflicting duplicate entries are treated as invalid metadata.
    return matches.length == 1 ? matches.single : null;
  }

  Future<void> _downloadToFile(
    Uri uri,
    File file, {
    void Function(int received, int total, double? bytesPerSecond)? onProgress,
  }) async {
    final request = http.Request('GET', uri)
      ..headers['Accept'] = 'application/vnd.github+json'
      ..headers['User-Agent'] = _requestUserAgent;
    final response =
        await _client.send(request).timeout(const Duration(seconds: 60));
    final finalHost = response.request?.url.host.toLowerCase() ?? '';
    if (!_allowedDownloadHosts.contains(finalHost)) {
      throw const UpdateDownloadException('下载重定向地址不受信任');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UpdateDownloadException('下载服务返回了 ${response.statusCode}');
    }
    final total = response.contentLength ?? 0;
    var received = 0;
    final started = DateTime.now();
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        final elapsed = DateTime.now().difference(started).inMilliseconds;
        final speed = elapsed <= 0 ? null : received * 1000 / elapsed;
        onProgress?.call(received, total, speed);
      }
    } finally {
      await sink.close();
    }
  }

  Future<String> _sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } catch (_) {}
  }

  Future<List<Release>> _fetchReleasesViaApi({
    required int page,
    required int perPage,
  }) async {
    final uri = _validatedUri(
      '$githubReleasesApiUrl?per_page=$perPage&page=$page',
    );
    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': _requestUserAgent,
      },
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UpdateCheckException('更新日志暂时不可用（${response.statusCode}）');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const UpdateCheckException('更新日志返回了无效数据');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Release.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<List<Release>> _fetchReleasesViaAtom(int page) async {
    // Atom Feed 只有最近若干条发布且无分页参数，翻到后面页时视为没有更多。
    if (page > 1) return const [];
    final response = await _client.get(
      _validatedUri(githubReleasesAtomUrl),
      headers: const {'User-Agent': _requestUserAgent},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UpdateCheckException('更新日志暂时不可用（${response.statusCode}）');
    }
    final feed = utf8.decode(response.bodyBytes);
    return RegExp(r'<entry>[\s\S]*?</entry>')
        .allMatches(feed)
        .map(_releaseFromAtomEntry)
        .toList(growable: false);
  }

  Release _releaseFromAtomEntry(RegExpMatch entry) {
    final block = entry.group(0)!;
    final title = _atomText(block, 'title');
    final updated = _atomText(block, 'updated');
    final author =
        RegExp(r'<author>\s*<name>([^<]+)</name>').firstMatch(block)?.group(1);
    final idMatch = RegExp(r'<id>[^<]*Release/(\d+)</id>').firstMatch(block);
    final tagMatch = RegExp(r'/releases/tag/([^"<]+)').firstMatch(block);
    final tagName =
        tagMatch == null ? '' : Uri.decodeComponent(tagMatch.group(1)!);
    return Release(
      id: int.tryParse(idMatch?.group(1) ?? '') ?? 0,
      tagName: tagName,
      name: title.isEmpty ? tagName : title,
      body: _plainTextFromHtml(_atomText(block, 'content')),
      createdAt: updated,
      tarballUrl: '',
      zipballUrl: '',
      htmlUrl: tagName.isEmpty
          ? githubReleasePageBaseUrl
          : '$githubReleasePageBaseUrl/tag/$tagName',
      prerelease: false,
      author: author ?? '',
      assets: const [],
    );
  }

  String _atomText(String block, String tag) {
    final match = RegExp('<$tag[^>]*>([\\s\\S]*?)</$tag>').firstMatch(block);
    return match == null ? '' : match.group(1)!.trim();
  }

  String _plainTextFromHtml(String html) {
    if (html.isEmpty) return '';
    final unescaped = html
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
    return unescaped
        .replaceAll(RegExp(r'<(br|/p|/div|/li|/h[1-6])[^>]*>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  AppUpdate? _newerReleaseOrNull(AppUpdate release, String currentVersion) {
    if (release.version.isEmpty ||
        compareAppVersions(release.version, currentVersion) <= 0) {
      return null;
    }
    return release;
  }

  Future<String> _currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Uri _validatedUri(String raw) {
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null || uri.scheme != 'https' || !_allowedHosts.contains(host)) {
      throw ArgumentError.value(raw, 'uri', '更新服务地址不在允许范围内');
    }
    return uri;
  }

  Uri _validatedDownloadUri(String raw) {
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        !_allowedDownloadHosts.contains(host)) {
      throw ArgumentError.value(raw, 'uri', '更新下载地址不在允许范围内');
    }
    return uri;
  }
}

class UpdateCheckException implements Exception {
  final String message;

  const UpdateCheckException(this.message);

  @override
  String toString() => message;
}

class UpdateDownloadException implements Exception {
  final String message;

  const UpdateDownloadException(this.message);

  @override
  String toString() => message;
}
