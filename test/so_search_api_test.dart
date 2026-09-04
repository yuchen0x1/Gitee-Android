import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/api/api_client.dart';
import 'package:gitee_client/api/so_search_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SoSearchApi', () {
    test('解析 Indexea 搜索响应并映射到 Repo', () async {
      const body = '''
{
  "took": 125,
  "hits": {
    "total": {"value": 200, "relation": "gte"},
    "hits": [
      {
        "_id": "30031183",
        "fields": {
          "title": ["dromara/easy-query"],
          "description": ["java最强orm没有之一(支持kotlin)零sql纯面向对象关系"],
          "url": ["https://gitee.com/dromara/easy-query"],
          "count.star": [509],
          "count.fork": [98],
          "langs": ["Java", "Kotlin"],
          "last_push_at": ["2026-08-27 17:21:26"],
          "owner.path.keyword": ["yu199195"]
        }
      },
      {
        "_id": "12104806",
        "fields": {
          "title": ["simple-robot/simpler-robot"],
          "description": [],
          "count.star": ["50"]
        }
      }
    ]
  }
}
''';
      late Uri captured;
      final api = SoSearchApi(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(body, 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );
      final repos = await api.searchRepos('Kotlin', from: 30, size: 10);

      expect(captured.host, 'so.gitee.com');
      expect(captured.path, '/v1/search/widget/wong1slagnlmzwvsu5ya');
      expect(captured.queryParameters['q'], 'Kotlin');
      expect(captured.queryParameters['from'], '30');
      expect(captured.queryParameters['size'], '10');

      expect(repos, hasLength(2));
      expect(repos[0].fullName, 'dromara/easy-query');
      expect(repos[0].name, 'easy-query');
      expect(repos[0].ownerLogin, 'yu199195');
      expect(repos[0].stars, 509);
      expect(repos[0].forks, 98);
      expect(repos[0].language, 'Java');
      expect(repos[0].updatedAt, '2026-08-27 17:21:26');
      expect(repos[0].htmlUrl, 'https://gitee.com/dromara/easy-query');

      // 字段缺失 / 空数组时兜底
      expect(repos[1].stars, 50);
      expect(repos[1].description, '暂无描述');
      expect(repos[1].ownerLogin, isEmpty);
      expect(repos[1].language, isEmpty);
    });

    test('非 200 响应抛出 GiteeApiException', () async {
      final api = SoSearchApi(
        client: MockClient((_) async => http.Response('{"error":"boom"}', 500)),
      );
      await expectLater(
        api.searchRepos('flutter'),
        throwsA(isA<GiteeApiException>()
            .having((e) => e.message, 'message', contains('500'))),
      );
    });

    test('响应缺 hits 字段时抛出 GiteeApiException', () async {
      final api = SoSearchApi(
        client: MockClient((_) async => http.Response('{"foo":1}', 200)),
      );
      await expectLater(
        api.searchRepos('flutter'),
        throwsA(isA<GiteeApiException>()
            .having((e) => e.message, 'message', contains('格式'))),
      );
    });
  });
}
