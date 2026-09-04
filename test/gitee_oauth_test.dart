import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gitee_client/auth/gitee_oauth.dart';
import 'package:gitee_client/auth/oauth_token.dart';

void main() {
  test('builds authorization URL and validates callback state', () async {
    var storedState;
    Uri? opened;
    final service = GiteeOAuthService(
      clientId: 'client-id',
      clientSecret: 'client-secret',
      redirectUri: 'gitee://oauth/callback',
      writeState: (state) async => storedState = state,
      readState: () async => storedState,
      clearState: () async => storedState = null,
      openUrl: (uri) async {
        opened = uri;
        return true;
      },
      client: MockClient((_) async => http.Response(
            jsonEncode({'access_token': 'access'}),
            200,
          )),
    );

    await service.beginAuthorization();
    expect(opened, isNotNull);
    expect(opened!.queryParameters['client_id'], 'client-id');
    expect(opened!.queryParameters['redirect_uri'], 'gitee://oauth/callback');
    expect(opened!.queryParameters['response_type'], 'code');
    expect(opened!.queryParameters['state'], isNotEmpty);

    final token = await service.completeAuthorization(Uri.parse(
      'gitee://oauth/callback?code=one&state=${opened!.queryParameters['state']}',
    ));
    expect(token.accessToken, 'access');

    expect(
      () => service.completeAuthorization(
        Uri.parse('gitee://oauth/callback?code=two&state=wrong'),
      ),
      throwsA(isA<GiteeOAuthException>()),
    );
  });

  test('exchanges code with form fields and parses refresh token', () async {
    late Map<String, String> body;
    final service = GiteeOAuthService(
      clientId: 'client-id',
      clientSecret: 'client-secret',
      redirectUri: 'gitee://oauth/callback',
      writeState: (_) async {},
      readState: () async => null,
      clearState: () async {},
      client: MockClient((request) async {
        body = request.bodyFields;
        return http.Response(
          jsonEncode({
            'access_token': 'access',
            'refresh_token': 'refresh',
            'expires_in': 3600,
            'token_type': 'Bearer',
          }),
          200,
        );
      }),
    );

    final authUri = await service.createAuthorizationUri();
    final token = await service.completeAuthorization(Uri.parse(
      'gitee://oauth/callback?code=one&state=${authUri.queryParameters['state']}',
    ));

    expect(body['grant_type'], 'authorization_code');
    expect(body['code'], 'one');
    expect(body['client_id'], 'client-id');
    expect(body['client_secret'], 'client-secret');
    expect(token.refreshToken, 'refresh');
    expect(token.expiresAt, isNotNull);
  });

  test('surfaces OAuth provider errors', () async {
    final service = GiteeOAuthService(
      clientId: 'client-id',
      clientSecret: 'client-secret',
      redirectUri: 'gitee://oauth/callback',
      writeState: (_) async {},
      readState: () async => null,
      clearState: () async {},
      client: MockClient((_) async => http.Response(
            jsonEncode({'error_description': 'invalid code'}),
            400,
          )),
    );
    final authUri = await service.createAuthorizationUri();

    await expectLater(
      service.completeAuthorization(Uri.parse(
        'gitee://oauth/callback?code=one&state=${authUri.queryParameters['state']}',
      )),
      throwsA(
        isA<GiteeOAuthException>().having(
          (e) => e.message,
          'message',
          contains('invalid code'),
        ),
      ),
    );
  });

  test('parses stored OAuth token expiration', () {
    final token = OAuthToken.fromStoredJson({
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'expiresAt':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    });
    expect(token.accessToken, 'access');
    expect(token.refreshToken, 'refresh');
    expect(token.isExpired, isFalse);
  });
}
