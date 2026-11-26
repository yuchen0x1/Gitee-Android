import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gitee_client/models/app_update.dart';
import 'package:gitee_client/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() async {
    final root = Directory(
      '${Directory.current.path}/build/update-download-tests',
    );
    await root.create(recursive: true);
    directory = await root.createTemp('fixture-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => directory.path);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    for (final file in directory.listSync()) {
      await file.delete(recursive: true);
    }
    await directory.delete();
  });

  final bytes = utf8.encode('APK fixture, not an installable APK');
  AppUpdate release(String hash, {int? size}) => AppUpdate.fromGitHubJson({
        'tag_name': 'v2.0.0',
        'assets': [
          {
            'name': 'app.apk',
            'size': size ?? bytes.length,
            'browser_download_url':
                'https://github.com/yuchen0x1/Gitee-Android/releases/download/v2.0.0/app.apk',
            'digest': 'sha256:$hash',
          },
        ],
      });

  test('download hashes actual file bytes and reports real progress', () async {
    final update = release(sha256.convert(bytes).toString());
    final service = UpdateService(
      client: MockClient(
        (request) async => http.Response.bytes(bytes, 200, request: request),
      ),
    );
    var received = 0;
    final file = await service.downloadApk(
      update,
      asset: update.assets.single,
      maxAttempts: 1,
      onProgress: (count, total, speed) => received = count,
    );
    expect(await file.readAsBytes(), bytes);
    expect(received, bytes.length);
  });

  test('hash mismatch rejects and deletes the downloaded file', () async {
    final update = release('0' * 64);
    final service = UpdateService(
      client: MockClient(
        (request) async => http.Response.bytes(bytes, 200, request: request),
      ),
    );
    await expectLater(
      service.downloadApk(update, asset: update.assets.single, maxAttempts: 1),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(directory.listSync(), isEmpty);
  });

  test('size mismatch rejects even when the hash matches', () async {
    final update = release(
      sha256.convert(bytes).toString(),
      size: bytes.length + 1,
    );
    final service = UpdateService(
      client: MockClient(
        (request) async => http.Response.bytes(bytes, 200, request: request),
      ),
    );
    await expectLater(
      service.downloadApk(update, asset: update.assets.single, maxAttempts: 1),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(directory.listSync(), isEmpty);
  });

  test('transient download failure retries within the limit', () async {
    final update = release(sha256.convert(bytes).toString());
    var calls = 0;
    final service = UpdateService(
      client: MockClient((request) async {
        calls++;
        return http.Response.bytes(
          bytes,
          calls == 1 ? 503 : 200,
          request: request,
        );
      }),
    );
    final file = await service.downloadApk(
      update,
      asset: update.assets.single,
      maxAttempts: 2,
    );
    expect(calls, 2);
    expect(await file.readAsBytes(), bytes);
  });

  test('failed response stream removes its partial APK and directory', () async {
    final update = release(sha256.convert(bytes).toString());
    Stream<List<int>> failingBody() async* {
      yield bytes.sublist(0, 4);
      throw const SocketException('connection interrupted');
    }

    final service = UpdateService(
      client: MockClient.streaming((request, body) async {
        return http.StreamedResponse(failingBody(), 200, request: request);
      }),
    );
    await expectLater(
      service.downloadApk(update, asset: update.assets.single, maxAttempts: 1),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(directory.listSync(), isEmpty);
  });

  test('stalled response body times out and removes its partial APK', () async {
    final update = release(sha256.convert(bytes).toString());
    final body = StreamController<List<int>>();
    addTearDown(body.close);
    body.add(bytes.sublist(0, 4));
    final service = UpdateService(
      downloadInactivityTimeout: const Duration(milliseconds: 30),
      client: MockClient.streaming((request, _) async {
        return http.StreamedResponse(body.stream, 200, request: request);
      }),
    );
    await expectLater(
      service.downloadApk(update, asset: update.assets.single, maxAttempts: 1),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(directory.listSync(), isEmpty);
  });

  test('concurrent APK downloads have independent verified files', () async {
    final update = release(sha256.convert(bytes).toString());
    final service = UpdateService(
      client: MockClient(
        (request) async => http.Response.bytes(bytes, 200, request: request),
      ),
    );
    final files = await Future.wait([
      service.downloadApk(update, asset: update.assets.single, maxAttempts: 1),
      service.downloadApk(update, asset: update.assets.single, maxAttempts: 1),
    ]);
    expect(files[0].path, isNot(files[1].path));
    for (final file in files) {
      expect(await file.readAsBytes(), bytes);
    }
  });

  test('zero download attempts fails before creating temporary files', () async {
    final update = release(sha256.convert(bytes).toString());
    final service = UpdateService(
      client: MockClient((_) async {
        fail('invalid attempt count must not send a request');
      }),
    );
    await expectLater(
      service.downloadApk(update, asset: update.assets.single, maxAttempts: 0),
      throwsArgumentError,
    );
    expect(directory.listSync(), isEmpty);
  });

  test(
    'checksum sidecar selects the named APK instead of the first hash',
    () async {
      final hash = sha256.convert(bytes).toString();
      final other = '1' * 64;
      final update = AppUpdate.fromGitHubJson({
        'tag_name': 'v2.0.0',
        'assets': [
          {
            'name': 'app-universal.apk',
            'size': bytes.length,
            'browser_download_url':
                'https://github.com/yuchen0x1/Gitee-Android/releases/download/v2.0.0/app-universal.apk',
          },
          {
            'name': 'SHA256SUMS.txt',
            'browser_download_url':
                'https://github.com/yuchen0x1/Gitee-Android/releases/download/v2.0.0/SHA256SUMS.txt',
          },
        ],
      });
      final service = UpdateService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('SHA256SUMS.txt')) {
            return http.Response(
              '$other  other.apk\n$hash  app-universal.apk\n',
              200,
              request: request,
            );
          }
          return http.Response.bytes(bytes, 200, request: request);
        }),
      );
      final file = await service.downloadApk(
        update,
        asset: update.assets.first,
        maxAttempts: 1,
      );
      expect(await file.readAsBytes(), bytes);
    },
  );

  test('checksum sidecar without a matching filename is rejected', () async {
    final update = AppUpdate.fromGitHubJson({
      'tag_name': 'v2.0.0',
      'assets': [
        {
          'name': 'app-universal.apk',
          'size': bytes.length,
          'browser_download_url':
              'https://github.com/yuchen0x1/Gitee-Android/releases/download/v2.0.0/app-universal.apk',
        },
        {
          'name': 'SHA256SUMS.txt',
          'browser_download_url':
              'https://github.com/yuchen0x1/Gitee-Android/releases/download/v2.0.0/SHA256SUMS.txt',
        },
      ],
    });
    final service = UpdateService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('SHA256SUMS.txt')) {
          return http.Response(
            '${'0' * 64}  another.apk\n',
            200,
            request: request,
          );
        }
        return http.Response.bytes(bytes, 200, request: request);
      }),
    );
    await expectLater(
      service.downloadApk(update, asset: update.assets.first, maxAttempts: 1),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(directory.listSync(), isEmpty);
  });
}
