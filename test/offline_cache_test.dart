import 'package:flutter_test/flutter_test.dart';

import 'package:gitee_client/models/file.dart';
import 'package:gitee_client/models/repo.dart';
import 'package:gitee_client/services/offline_cache.dart';

void main() {
  test('offline cache keys isolate accounts without storing tokens', () {
    final first = OfflineCache.key(
      token: 'token-a',
      type: 'file',
      parts: ['owner', 'repo', 'lib/main.dart', 'master'],
    );
    final second = OfflineCache.key(
      token: 'token-b',
      type: 'file',
      parts: ['owner', 'repo', 'lib/main.dart', 'master'],
    );

    expect(first, isNot(second));
    expect(first, isNot(contains('token-a')));
    expect(first, isNot(contains('token-b')));
  });

  test('repo and file models round trip through JSON', () {
    final repo = Repo(
      id: 1,
      fullName: 'owner/repo',
      name: 'repo',
      description: 'description',
      ownerLogin: 'owner',
      ownerAvatar: 'avatar',
      stars: 2,
      forks: 3,
      watchers: 4,
      language: 'Dart',
      isPrivate: true,
      htmlUrl: 'https://gitee.com/owner/repo',
      defaultBranch: 'main',
      updatedAt: '2026-11-08T00:00:00Z',
    );
    final restoredRepo = Repo.fromJson(repo.toJson());
    expect(restoredRepo.fullName, repo.fullName);
    expect(restoredRepo.defaultBranch, repo.defaultBranch);
    expect(restoredRepo.isPrivate, isTrue);

    final file = RepoFile(
      name: 'main.dart',
      path: 'lib/main.dart',
      type: 'file',
      size: 42,
      sha: 'sha',
    );
    final restoredFile = RepoFile.fromJson(file.toJson());
    expect(restoredFile.path, file.path);
    expect(restoredFile.size, file.size);
    expect(restoredFile.sha, file.sha);
  });
}
