import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gitee_client/api/api_client.dart';

void main() {
  for (final status in [200, 401]) {
    test('old-account $status cannot affect a new session', () async {
      final ready = Completer<http.Response>();
      final client =
          ApiClient(token: 'old', client: MockClient((_) => ready.future));
      var loggedOut = false;
      client.onUnauthorized = () => loggedOut = true;
      final pending = client.requestCached('/user');
      client.setToken('new');
      final check = expectLater(pending, throwsA(isA<GiteeApiException>()));
      ready.complete(http.Response('{"login":"old"}', status));
      await check;
      expect(client.token, 'new');
      expect(loggedOut, isFalse);
    });
  }

  test('old multipart 401 cannot log out the new account', () async {
    final ready = Completer<http.Response>();
    final client =
        ApiClient(token: 'old', client: MockClient((_) => ready.future));
    var loggedOut = false;
    client.onUnauthorized = () => loggedOut = true;
    final pending = client.uploadMultipart('/releases/assets',
        fileField: 'file', fileBytes: [1], filename: 'a.txt');
    client.setToken('new');
    final check = expectLater(pending, throwsA(isA<GiteeApiException>()));
    ready.complete(http.Response('{}', 401));
    await check;
    expect(client.token, 'new');
    expect(loggedOut, isFalse);
  });
}
