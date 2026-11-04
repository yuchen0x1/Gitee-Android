import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_update.dart';

/// 公开 Release 在线更新服务。
///
/// 更新检查不需要登录，也不会发送 Gitee Token。Gitee 是唯一发行通道：
/// 先查 Open API，被限流或不可达时回退 Gitee 网页版发布页。
class UpdateService {
  static final shared = UpdateService();

  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  static const repositoryOwner = 'yuchen0x1';
  static const repositoryName = 'Gitee-Android';
  static const giteeLatestReleaseUrl =
      'https://gitee.com/api/v5/repos/$repositoryOwner/$repositoryName/releases/latest';
  static const giteeLatestReleasePageUrl =
      'https://gitee.com/$repositoryOwner/$repositoryName/releases/latest';
  static const giteeReleasePageBaseUrl =
      'https://gitee.com/$repositoryOwner/$repositoryName/releases';

  static const _allowedHosts = {'gitee.com'};
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
      final release = await _fetchGiteeRelease();
      // Gitee 是唯一发行通道：成功返回即以它为准。
      return _newerReleaseOrNull(release, version);
    } catch (_) {
      // API 受限、限流或不可达时回退 Gitee 网页版发布页。
    }
    return _checkGiteeReleasePage(version);
  }

  Future<AppUpdate> _fetchGiteeRelease() async {
    final response = await _client.get(
      _validatedUri(giteeLatestReleaseUrl),
      headers: const {
        'Accept': 'application/json',
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
    return AppUpdate.fromGiteeJson(
      Map<String, dynamic>.from(decoded),
      htmlUrlFallback: giteeReleasePageBaseUrl,
    );
  }

  /// 网页版兜底：/releases/latest 会 302 到 /releases/tag/{tag}，
  /// 且不占用 Open API 的匿名限流配额。
  Future<AppUpdate?> _checkGiteeReleasePage(String currentVersion) async {
    final response = await _client.get(
      _validatedUri(giteeLatestReleasePageUrl),
      headers: const {'User-Agent': _requestUserAgent},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw UpdateCheckException('更新服务暂时不可用（${response.statusCode}）');
    }

    final finalUrl = response.request?.url.toString() ?? '';
    final page = utf8.decode(response.bodyBytes);
    final match = RegExp(r'/releases/tag/([^"?#/<]+)').firstMatch(
      '$finalUrl\n$page',
    );
    if (match == null) return null;
    final version = Uri.decodeComponent(match.group(1)!);
    return _newerReleaseOrNull(
      AppUpdate(
        version: version,
        name: version,
        notes: '',
        htmlUrl: finalUrl.isEmpty ? giteeLatestReleasePageUrl : finalUrl,
        publishedAt: '',
        assets: const [],
      ),
      currentVersion,
    );
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
}

class UpdateCheckException implements Exception {
  final String message;

  const UpdateCheckException(this.message);

  @override
  String toString() => message;
}
