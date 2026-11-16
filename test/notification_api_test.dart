import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gitee_client/api/api_client.dart';
import 'package:gitee_client/api/gitee_api.dart';
import 'package:gitee_client/models/notification.dart';

void main() {
  tearDown(() => GiteeApi.setClientForTest(ApiClient()));

  test('notification filtering uses Gitee unread parameter and list envelope',
      () async {
    final requests = <http.Request>[];
    GiteeApi.setClientForTest(ApiClient(
        token: 'fixture',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
              jsonEncode({
                'total_count': 1,
                'list': [
                  {
                    'id': 1,
                    'unread': true,
                    'type': 'referer',
                    'content': 'A mention'
                  },
                ]
              }),
              200);
        })));
    final unread = await GiteeApi.getNotifications(unread: true, page: 2);
    await GiteeApi.getNotifications(unread: false);
    expect(requests.first.url.queryParameters,
        {'page': '2', 'per_page': '20', 'unread': 'true'});
    expect(requests.last.url.queryParameters['unread'], 'false');
    expect(requests.first.headers['Authorization'], 'token fixture');
    expect(unread.single.title, 'A mention');
    expect(unread.single.type, 'referer');
  });

  test('counts are coalesced, isolated by filter and cleared on account switch',
      () async {
    var requests = 0;
    final client = ApiClient(
        token: 'alice',
        client: MockClient((request) async {
          requests++;
          return http.Response(
              jsonEncode({
                'notification_count':
                    request.headers['Authorization'] == 'token bob'
                        ? 2
                        : request.url.queryParameters['unread'] == 'true'
                            ? 3
                            : 10
              }),
              200);
        }));
    GiteeApi.setClientForTest(client);
    expect(
        await Future.wait(
            [GiteeApi.getNotificationCount(), GiteeApi.getNotificationCount()]),
        [3, 3]);
    expect(requests, 1);
    expect(await GiteeApi.getNotificationCount(unread: false), 10);
    expect(requests, 2);
    GiteeApi.setToken('bob');
    expect(await GiteeApi.getNotificationCount(), 2);
    expect(requests, 3);
  });

  test('successful single and bulk writes invalidate count immediately',
      () async {
    var count = 2;
    var countReads = 0;
    GiteeApi.setClientForTest(ApiClient(client: MockClient((request) async {
      if (request.method == 'PATCH') {
        count--;
        return http.Response('', 205);
      }
      if (request.method == 'PUT') {
        count = 0;
        return http.Response('', 205);
      }
      countReads++;
      return http.Response('{"notification_count":$count}', 200);
    })));
    expect(await GiteeApi.getNotificationCount(), 2);
    await GiteeApi.markNotificationRead('1');
    expect(await GiteeApi.getNotificationCount(), 1);
    await GiteeApi.markAllNotificationsRead();
    expect(await GiteeApi.getNotificationCount(), 0);
    expect(countReads, 3);
  });

  test('old account count completion cannot populate new account cache',
      () async {
    final old = Completer<http.Response>();
    final client = ApiClient(
        token: 'alice',
        client: MockClient((request) async {
          if (request.headers['Authorization'] == 'token alice') {
            return old.future;
          }
          return http.Response('{"notification_count":1}', 200);
        }));
    GiteeApi.setClientForTest(client);
    final pending = GiteeApi.getNotificationCount();
    final check = expectLater(pending, throwsA(isA<GiteeApiException>()));
    GiteeApi.setToken('bob');
    old.complete(http.Response('{"notification_count":99}', 200));
    await check;
    expect(await GiteeApi.getNotificationCount(), 1);
  });

  test(
      'notification parsing accepts documented fields and read updates retain identity',
      () {
    for (final value in [true, 1, 'true']) {
      final notification = AppNotification.fromJson({
        'id': 1,
        'unread': value,
        'content': 'mention',
        'type': 'referer',
        'repository': {'full_name': 'o/r'}
      });
      expect(notification.unread, isTrue);
      expect(notification.asRead().unread, isFalse);
      expect(notification.asRead().id, notification.id);
      expect(notification.asRead().title, 'mention');
    }
    expect(AppNotification.fromJson({'unread': 'false'}).unread, isFalse);
  });
}
