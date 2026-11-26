import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/auth/session_expiry_handler.dart';

void main() {
  test('duplicate expiry is coalesced until cleanup finishes', () async {
    final cleanup = Completer<void>();
    var clears = 0;
    var redirects = 0;
    final handler = SessionExpiryHandler(
      currentSession: () => 1,
      clearCredentials: () {
        clears++;
        return cleanup.future;
      },
      clearOfflineCache: () async {},
      onExpired: () => redirects++,
    );

    final first = handler.handle();
    await handler.handle();
    expect(clears, 1);
    expect(redirects, 0);
    cleanup.complete();
    await first;
    expect(redirects, 1);
  });

  test('new login during old cleanup is not redirected', () async {
    final cleanup = Completer<void>();
    var session = 1;
    var redirects = 0;
    final handler = SessionExpiryHandler(
      currentSession: () => session,
      clearCredentials: () => cleanup.future,
      clearOfflineCache: () async {},
      onExpired: () => redirects++,
    );

    final pending = handler.handle();
    session = 2;
    cleanup.complete();
    await pending;
    expect(redirects, 0);
  });

  test('expiry of a newer session is not suppressed by old cleanup', () async {
    final firstCleanup = Completer<void>();
    final secondCleanup = Completer<void>();
    var session = 1;
    var clears = 0;
    var redirects = 0;
    final handler = SessionExpiryHandler(
      currentSession: () => session,
      clearCredentials: () =>
          ++clears == 1 ? firstCleanup.future : secondCleanup.future,
      clearOfflineCache: () async {},
      onExpired: () => redirects++,
    );

    final first = handler.handle();
    session = 2;
    final second = handler.handle();
    expect(clears, 2);
    firstCleanup.complete();
    await first;
    expect(redirects, 0);
    secondCleanup.complete();
    await second;
    expect(redirects, 1);

    // The previous route need not be popped before another expiry is handled.
    session = 3;
    await handler.handle();
    expect(redirects, 2);
  });

  test('storage failure still redirects and allows later expiry handling',
      () async {
    var session = 1;
    var redirects = 0;
    final handler = SessionExpiryHandler(
      currentSession: () => session,
      clearCredentials: () async => throw StateError('storage unavailable'),
      clearOfflineCache: () async {},
      onExpired: () => redirects++,
    );

    await handler.handle();
    session = 2;
    await handler.handle();
    expect(redirects, 2);
  });
}
