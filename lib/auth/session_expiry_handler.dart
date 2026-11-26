/// Coordinates asynchronous cleanup without redirecting a newer login session.
class SessionExpiryHandler {
  SessionExpiryHandler({
    required this.currentSession,
    required this.clearCredentials,
    required this.clearOfflineCache,
    required this.onExpired,
  });

  final int Function() currentSession;
  final Future<void> Function() clearCredentials;
  final Future<void> Function() clearOfflineCache;
  final void Function() onExpired;
  final Set<int> _pendingSessions = {};

  Future<void> handle() async {
    final session = currentSession();
    if (!_pendingSessions.add(session)) return;
    try {
      // Storage failures must not strand an already-invalidated session.
      try {
        await clearCredentials();
      } catch (_) {}
      try {
        await clearOfflineCache();
      } catch (_) {}
      if (currentSession() == session) onExpired();
    } finally {
      _pendingSessions.remove(session);
    }
  }
}
