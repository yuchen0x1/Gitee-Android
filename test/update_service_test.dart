import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gitee_client/models/app_update.dart';
import 'package:gitee_client/services/update_service.dart';

void main() {
  final releaseJson = {
    'tag_name': 'v2.1.0',
    'name': 'Gitee Client 2.1.0',
    'body': '新增在线更新',
    'html_url':
        'https://gitee.com/yuchen0x1/Gitee-Android/releases/tag/v2.1.0',
    'published_at': '2026-08-29T00:00:00Z',
    'assets': [
      {
        'name': 'gitee-client-v2.1.0-android-universal.apk',
        'browser_download_url': 'https://example.com/app-release.apk',
        'size': 123,
      },
      {
        'name': 'gitee-client-v2.1.0-windows-x64.zip',
        'browser_download_url': 'https://example.com/windows.zip',
      },
    ],
  };

  test('版本比较兼容 v 前缀和缺省小版本', () {
    expect(compareAppVersions('v2.1.0', '2.0.9'), greaterThan(0));
    expect(compareAppVersions('2.0', '2.0.0'), 0);
    expect(compareAppVersions('1.9.9', '2.0.0'), lessThan(0));
  });

  test('解析 Release 并选择 Android/Windows 安装包', () {
    final update = AppUpdate.fromGitHubJson(releaseJson);
    expect(update.version, 'v2.1.0');
    expect(update.assetForPlatform(TargetPlatform.android)?.url,
        'https://example.com/app-release.apk');
    expect(update.assetForPlatform(TargetPlatform.windows)?.url,
        'https://example.com/windows.zip');
  });

  test('发现比当前版本更新的 Release', () async {
    final service = UpdateService(
      client: MockClient((request) async => http.Response(
            jsonEncode(releaseJson),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );
    final update = await service.checkForUpdate(currentVersion: '2.0.0');
    expect(update?.version, 'v2.1.0');
    expect(update?.notes, contains('在线更新'));
  });

  test('当前版本等于或高于 Release 时不提示更新', () async {
    final service = UpdateService(
      client: MockClient((request) async => http.Response(
            jsonEncode(releaseJson),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );
    expect(await service.checkForUpdate(currentVersion: '2.1.0'), isNull);
    expect(await service.checkForUpdate(currentVersion: '3.0.0'), isNull);
  });

  test('GitHub API 受限时从 Releases 网页兜底识别更新', () async {
    final service = UpdateService(
      client: MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response('', 403);
        }
        return http.Response(
          '<a href="/yuchen0x1/Gitee-Android/releases/tag/v2.1.0">',
          200,
        );
      }),
    );
    final update = await service.checkForUpdate(currentVersion: '2.0.0');
    expect(update?.version, 'v2.1.0');
    expect(update?.htmlUrl, UpdateService.githubLatestReleasePageUrl);
  });

  test('GitHub 通道不发送用户 Token', () async {
    late http.Request captured;
    final service = UpdateService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({...releaseJson, 'html_url': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await service.checkForUpdate(currentVersion: '2.0.0');
    expect(captured.url.host, 'api.github.com');
    expect(captured.headers.containsKey('authorization'), isFalse);
  });

  test('相同服务在缓存期内复用更新结果', () async {
    var calls = 0;
    final service = UpdateService(
      client: MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode(releaseJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await service.checkForUpdate(currentVersion: '2.0.0');
    await service.checkForUpdate(currentVersion: '2.0.0');
    expect(calls, 1);
    await service.checkForUpdate(
      currentVersion: '2.0.0',
      forceRefresh: true,
    );
    expect(calls, 2);
  });

  test('并发检查复用同一个进行中的请求', () async {
    var calls = 0;
    final service = UpdateService(
      client: MockClient((request) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response(
          jsonEncode(releaseJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final results = await Future.wait([
      service.checkForUpdate(currentVersion: '2.0.0'),
      service.checkForUpdate(currentVersion: '2.0.0'),
    ]);
    expect(calls, 1);
    expect(results[0]?.version, 'v2.1.0');
    expect(results[1]?.version, 'v2.1.0');
  });

  test('缓存按当前版本隔离，避免跨版本误复用', () async {
    var calls = 0;
    final service = UpdateService(
      client: MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode(releaseJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await service.checkForUpdate(currentVersion: '2.1.0');
    final update = await service.checkForUpdate(currentVersion: '2.0.0');
    expect(calls, 2);
    expect(update?.version, 'v2.1.0');
  });

  test('GitHub API 成功时不再访问网页兜底', () async {
    final stale = Map<String, dynamic>.from(releaseJson)
      ..['tag_name'] = 'v2.0.0';
    var pageCalls = 0;
    final service = UpdateService(
      client: MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response(jsonEncode(stale), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        pageCalls++;
        return http.Response('', 200);
      }),
    );
    // GitHub API 返回与当前版本一致的 v2.0.0：视为已最新，不触发网页兜底。
    final update = await service.checkForUpdate(currentVersion: '2.0.0');
    expect(update, isNull);
    expect(pageCalls, 0);
  });

  test('GitHub API 与网页兜底均失败时抛出异常', () async {
    final service = UpdateService(
      client: MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.Response('', 403);
        }
        return http.Response('', 500);
      }),
    );
    await expectLater(
      service.checkForUpdate(currentVersion: '2.0.0'),
      throwsA(isA<UpdateCheckException>()),
    );
  });
}
