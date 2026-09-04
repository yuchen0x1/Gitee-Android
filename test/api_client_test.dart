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
  });
}
