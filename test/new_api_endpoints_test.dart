import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gitee_client/api/api_client.dart';
import 'package:gitee_client/api/gitee_api.dart';

/// 支持 multipart 的 Mock 传输层（MockClient 不接受 MultipartRequest）。
class _AnyMock extends http.BaseClient {
  _AnyMock(this.handler);

  final Future<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await handler(request);
    return http.StreamedResponse(
      http.ByteStream.fromBytes(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
    );
  }
}

void main() {
  setUp(() {
    GiteeApi.setClientForTest(ApiClient(
      client: MockClient((_) async => http.Response('[]', 200)),
      token: 'abc',
    ));
  });

  group('新版/新增接口封装', () {
    test('getRepoTraffic 走 POST 且解析汇总与明细', () async {
      late String capturedMethod;
      late Uri capturedUri;
      final client = ApiClient(
        client: MockClient((request) async {
          capturedMethod = request.method;
          capturedUri = request.url;
          return http.Response(
            jsonEncode({
              'summary': {'ip': 12, 'pull': 34, 'push': 5, 'download_zip': 2},
              'counts': [
                {'bucket': 1735660800, 'ip': 3, 'pull': 8, 'push': 1, 'download_zip': 0},
              ],
            }),
            201,
          );
        }),
        token: 'abc',
      );
      GiteeApi.setClientForTest(client);
      final traffic = await GiteeApi.getRepoTraffic('o', 'r');
      expect(capturedMethod, 'POST');
      expect(
        capturedUri.path,
        '/api/v5/repos/o/r/traffic-data',
      );
      expect(traffic.ip, 12);
      expect(traffic.pull, 34);
      expect(traffic.days.single.ip, 3);
      expect(traffic.days.single.date.year, 2024);
    });

    test('getCommitCheckRuns 解析检查项', () async {
      late Uri capturedUri;
      final client = ApiClient(
        client: MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode([
              {
                'name': 'build',
                'status': 'completed',
                'conclusion': 'success',
                'head_sha': 'abc123',
                'details_url': 'https://gitee.com/go/1',
                'started_at': '2024-01-01T00:00:00+08:00',
                'completed_at': '2024-01-01T00:05:00+08:00',
              },
              {
                'name': 'lint',
                'status': 'running',
                'conclusion': null,
                'head_sha': 'abc123',
                'details_url': '',
                'started_at': '',
                'completed_at': '',
              },
            ]),
            200,
          );
        }),
        token: 'abc',
      );
      GiteeApi.setClientForTest(client);
      final runs = await GiteeApi.getCommitCheckRuns('o', 'r', 'abc123');
      expect(capturedUri.path, '/api/v5/repos/o/r/commits/abc123/check-runs');
      expect(runs.length, 2);
      expect(runs[0].isSuccess, isTrue);
      expect(runs[0].isFailure, isFalse);
      expect(runs[1].isRunning, isTrue);
    });

    test('getReleaseAttachFiles 解析附件列表', () async {
      late Uri capturedUri;
      final client = ApiClient(
        client: MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'name': 'app.apk',
                'size': 2048,
                'uploader': {'login': 'alice'},
                'browser_download_url': 'https://gitee.com/f/1',
              },
            ]),
            200,
          );
        }),
        token: 'abc',
      );
      GiteeApi.setClientForTest(client);
      final files = await GiteeApi.getReleaseAttachFiles('o', 'r', 9);
      expect(
        capturedUri.path,
        '/api/v5/repos/o/r/releases/9/attach_files',
      );
      expect(files.single.name, 'app.apk');
      expect(files.single.uploader, 'alice');
      expect(files.single.sizeText, '2 KB');
    });

    test('getIssuePullRequests 路径无 repo 段且支持 repo 过滤', () async {
      late Uri capturedUri;
      final client = ApiClient(
        client: MockClient((request) async {
          capturedUri = request.url;
          return http.Response.bytes(
            utf8.encode(jsonEncode([
              {
                'id': 1,
                'number': 8,
                'title': '修复崩溃',
                'state': 'open',
                'head': 'f',
                'base': 'b',
                'user': {'login': 'a', 'avatar_url': ''},
              },
            ])),
            200,
          );
        }),
        token: 'abc',
      );
      GiteeApi.setClientForTest(client);
      final prs = await GiteeApi.getIssuePullRequests('o', '3', repo: 'r');
      expect(capturedUri.path, '/api/v5/repos/o/issues/3/pull_requests');
      expect(capturedUri.queryParameters['repo'], 'r');
      expect(prs.single.number, 8);
    });

    test('getPullRequestIssues 解析关联 Issue', () async {
      late Uri capturedUri;
      final client = ApiClient(
        client: MockClient((request) async {
          capturedUri = request.url;
          return http.Response.bytes(
            utf8.encode(jsonEncode([
              {
                'id': 2,
                'number': '3',
                'title': '崩溃报告',
                'state': 'closed',
                'user': {'login': 'a', 'avatar_url': ''},
                'labels': [],
              },
            ])),
            200,
          );
        }),
        token: 'abc',
      );
      GiteeApi.setClientForTest(client);
      final issues = await GiteeApi.getPullRequestIssues('o', 'r', 8);
      expect(capturedUri.path, '/api/v5/repos/o/r/pulls/8/issues');
      expect(issues.single.number, '3');
      expect(issues.single.state, 'closed');
    });

    test('getUserNamespaces / 模板列表解析', () async {
      late Uri nsUri;
      Uri? licenseUri;
      Uri? gitignoreUri;
      final client = ApiClient(
        client: MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/user/namespaces')) {
            nsUri = request.url;
            return http.Response(
              jsonEncode([
                {'id': 1, 'type': 'personal', 'name': 'alice', 'path': 'alice'},
                {'id': 2, 'type': 'organization', 'name': 'org1', 'path': 'org1'},
              ]),
              200,
            );
          }
          if (path.endsWith('/licenses')) {
            licenseUri = request.url;
            return http.Response(
              jsonEncode(['MIT', 'Apache-2.0']),
              200,
            );
          }
          if (path.endsWith('/gitignore/templates')) {
            gitignoreUri = request.url;
            return http.Response(
              jsonEncode(['Dart', 'Android']),
              200,
            );
          }
          return http.Response('[]', 200);
        }),
        token: 'abc',
      );
      GiteeApi.setClientForTest(client);
      final namespaces = await GiteeApi.getUserNamespaces();
      final licenses = await GiteeApi.getLicenseTemplates();
      final gitignores = await GiteeApi.getGitignoreTemplates();
      expect(nsUri.path, '/api/v5/user/namespaces');
      expect(namespaces.first.isOrganization, isFalse);
      expect(namespaces.last.isOrganization, isTrue);
      expect(licenseUri!.path, '/api/v5/licenses');
      expect(licenses, ['MIT', 'Apache-2.0']);
      expect(gitignoreUri!.path, '/api/v5/gitignore/templates');
      expect(gitignores, ['Dart', 'Android']);
    });

    test('deleteRepoLabel 按名称寻址', () async {
      late String capturedMethod;
      late Uri capturedUri;
      final client = ApiClient(
        client: MockClient((request) async {
          capturedMethod = request.method;
          capturedUri = request.url;
          return http.Response('', 204);
        }),
        token: 'abc',
      );
      GiteeApi.setClientForTest(client);
      await GiteeApi.deleteRepoLabel('o', 'r', 'bug');
      expect(capturedMethod, 'DELETE');
      expect(capturedUri.path, '/api/v5/repos/o/r/labels/bug');
    });

    test('updateMilestone 走 PATCH', () async {
      late String capturedMethod;
      final client = ApiClient(
        client: MockClient((request) async {
          capturedMethod = request.method;
          return http.Response('{}', 200);
        }),
        token: 'abc',
      );
      GiteeApi.setClientForTest(client);
      await GiteeApi.updateMilestone(owner: 'o', repo: 'r', id: 3, state: 'closed');
      expect(capturedMethod, 'PATCH');
    });

    test('uploadMultipart 携带文件与鉴权头', () async {
      Object? capturedRequest;
      final client = ApiClient(
        client: _AnyMock((request) async {
          capturedRequest = request;
          return http.Response('', 201);
        }),
        token: 'abc',
      );
      final bytes = utf8.encode('hello');
      await client.uploadMultipart(
        '/repos/o/r/releases/9/attach_files',
        fileField: 'file',
        fileBytes: bytes,
        filename: 'a.txt',
      );
      expect(capturedRequest, isA<http.MultipartRequest>());
      final request = capturedRequest as http.MultipartRequest;
      expect(request.url.path, '/api/v5/repos/o/r/releases/9/attach_files');
      expect(request.headers['Authorization'], 'token abc');
      expect(request.files.single.filename, 'a.txt');
      expect(request.files.single.field, 'file');
    });
  });
}
