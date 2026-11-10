import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gitee_client/api/api_client.dart';
import 'package:gitee_client/api/gitee_api.dart';

void main() {
  group('ApiClient', () {
    test('401 清空令牌并触发登出回调', () async {
      final client = ApiClient(
        client: MockClient((_) async => http.Response('{}', 401)),
        token: 'abc',
      );
      var called = false;
      client.onUnauthorized = () => called = true;
      await expectLater(
        client.request('GET', '/user'),
        throwsA(isA<GiteeApiException>()),
      );
      expect(client.token, isNull);
      expect(called, isTrue);
    });

    test('订阅列表只发送 Gitee 支持的分页参数', () async {
      late Uri captured;
      final client = ApiClient(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response('[]', 200);
        }),
        token: 'secret',
      );
      GiteeApi.setClientForTest(client);
      final repos = await GiteeApi.getSubscriptions(page: 2, perPage: 20);
      expect(repos, isEmpty);
      expect(captured.path, '/api/v5/user/subscriptions');
      expect(captured.queryParameters, {'page': '2', 'per_page': '20'});
    });

    test('成功响应携带鉴权头与分页参数', () async {
      late Uri captured;
      late Map<String, String> capturedHeaders;
      final client = ApiClient(
        client: MockClient((request) async {
          captured = request.url;
          capturedHeaders = request.headers;
          return http.Response('[]', 200);
        }),
        token: 'secret',
      );
      GiteeApi.setClientForTest(client);
      final repos = await GiteeApi.getStarredRepos(page: 2);
      expect(repos, isEmpty);
      expect(captured.path, '/api/v5/user/starred');
      expect(captured.queryParameters['page'], '2');
      expect(captured.queryParameters['per_page'], '20');
      expect(capturedHeaders['Authorization'], 'token secret');
    });

    test('错误响应携带服务端 message', () async {
      final client = ApiClient(
        client: MockClient((_) async => http.Response(
              jsonEncode({'message': '仓库不存在'}),
              404,
              headers: {'content-type': 'application/json; charset=utf-8'},
            )),
      );
      await expectLater(
        client.request('GET', '/repos/x/y'),
        throwsA(isA<GiteeApiException>()
            .having((e) => e.message, 'message', contains('仓库不存在'))),
      );
    });

    test('requestCached 在 TTL 内复用结果', () async {
      var calls = 0;
      final client = ApiClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('[]', 200);
        }),
      );
      await client.requestCached('/user/starred');
      await client.requestCached('/user/starred');
      expect(calls, 1);
    });

    test('写请求成功后仅清除同路径层级的 GET 缓存', () async {
      var calls = 0;
      final client = ApiClient(
        client: MockClient((request) async {
          calls++;
          return http.Response(request.method == 'GET' ? '[]' : '{}', 200);
        }),
      );
      await client.requestCached('/repos/x/y');
      await client.requestCached('/repos/other/repo');
      await client.request(
        'PATCH',
        '/repos/x/y/issues/3',
        body: {'title': 'new'},
      );
      await client.requestCached('/repos/x/y');
      await client.requestCached('/repos/other/repo');
      // Two initial reads, the mutation, and the refreshed matching resource;
      // the unrelated resource remains cached.
      expect(calls, 4);
    });

    test('缓存键对查询参数顺序不敏感', () async {
      var calls = 0;
      final client = ApiClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('[]', 200);
        }),
      );
      await client.requestCached('/search', query: {'page': '1', 'q': 'dart'});
      await client.requestCached('/search', query: {'q': 'dart', 'page': '1'});
      expect(calls, 1);
    });
  });
}
