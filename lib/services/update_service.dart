import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_update.dart';

/// 更新通道。默认先检查 Gitee，再回退 GitHub。
enum UpdateChannel { gitee, github }

/// 公开 Release 在线更新服务。
///
/// 更新检查不需要登录，也不会发送 Gitee Token。Gitee 适合国内网络，
/// GitHub 作为跨网络环境的回退来源。
class UpdateService {
  static final shared = UpdateService();

  UpdateService({http.Client? client, UpdateChannel? preferredChannel})
      : _client = client ?? http.Client(),
        _preferredChannel = preferredChannel;

  static const repositoryOwner = 'yuchen0x1';
  static const repositoryName = 'gitee-mobile-client';
  static const latestReleaseUrl =
      'https://api.github.com/repos/$repositoryOwner/$repositoryName/releases/latest';
  static const latestReleasePageUrl =
      'https://github.com/$repositoryOwner/$repositoryName/releases/latest';
  static const giteeLatestReleaseUrl =
      'https://gitee.com/api/v5/repos/$repositoryOwner/$repositoryName/releases/latest';
  static const giteeReleasePageBaseUrl =
      'https://gitee.com/$repositoryOwner/$repositoryName/releases';

  static const _allowedHosts = {
    'gitee.com',
    'api.github.com',
    'github.com',
  };
  static const _requestUserAgent = 'Gitee-Client-Update-Checker';

  final http.Client _client;
  final UpdateChannel? _preferredChannel;
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
    if (_preferredChannel == UpdateChannel.github) {
      return _checkGitHubRelease(version);
    }

    try {
      final release = await _fetchGiteeRelease();
      final update = _newerReleaseOrNull(release, version);
      if (update != null) return update;
    } catch (_) {
      // Gitee 受限、限流或不可达时回退 GitHub。
    }
    // Gitee 可能是延迟同步的镜像；即使它成功返回旧版本，也继续检查 GitHub。
    return _checkGitHubRelease(version);
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

  Future<AppUpdate?> _checkGitHubRelease(String currentVersion) async {
    try {
      final response = await _client.get(
        _validatedUri(latestReleaseUrl),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': _requestUserAgent,
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map) {
          throw const UpdateCheckException('更新服务返回了无效数据');
        }
        return _newerReleaseOrNull(
          AppUpdate.fromGitHubJson(Map<String, dynamic>.from(decoded)),
          currentVersion,
        );
      }
      if (response.statusCode != 403 && response.statusCode != 404) {
        throw UpdateCheckException('更新服务暂时不可用（${response.statusCode}）');
      }
    } on UpdateCheckException catch (error) {
      if (!error.message.contains('暂时不可用')) rethrow;
    } catch (_) {
      // 页面重定向兜底可能仍可用。
    }

    return _checkReleasePage(currentVersion);
  }

  AppUpdate? _newerReleaseOrNull(AppUpdate release, String currentVersion) {
    if (release.version.isEmpty ||
        compareAppVersions(release.version, currentVersion) <= 0) {
      return null;
    }
    return release;
  }

  Future<AppUpdate?> _checkReleasePage(String currentVersion) async {
    final response = await _client.get(
      _validatedUri(latestReleasePageUrl),
      headers: const {'User-Agent': _requestUserAgent},
    ).timeout(const Duration(seconds: 12));
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
        htmlUrl: finalUrl.isEmpty ? latestReleasePageUrl : finalUrl,
        publishedAt: '',
        assets: const [],
      ),
      currentVersion,
    );
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
