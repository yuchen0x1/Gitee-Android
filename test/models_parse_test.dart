import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/models/commit.dart';
import 'package:gitee_client/models/issue.dart';
import 'package:gitee_client/models/pull_request.dart';

void main() {
  test(
      'Commit falls back to Git author name when Gitee account author is absent',
      () {
    final commit = Commit.fromJson({
      'sha': 'abc123',
      'commit': {
        'message': 'fix',
        'author': {
          'name': 'lenmo181',
          'date': '2026-11-10T00:00:00Z',
        },
      },
      'author': null,
    });

    expect(commit.author, isNull);
    expect(commit.authorName, 'lenmo181');
    expect(commit.authorLabel, 'lenmo181');
  });

  test('Issue keeps official numeric and string issue numbers', () {
    final numeric = Issue.fromJson({'number': 42});
    final string = Issue.fromJson({'number': '7'});

    expect(numeric.number, '42');
    expect(string.number, '7');
  });

  test('PullRequest parses string head and base refs', () {
    final pr = PullRequest.fromJson({
      'number': '9',
      'state': 'open',
      'head': 'feature/a',
      'base': 'main',
      'merged': false,
    });

    expect(pr.number, 9);
    expect(pr.headBranch, 'feature/a');
    expect(pr.baseBranch, 'main');
  });

  test('PullRequest treats merged_at as merged', () {
    final pr = PullRequest.fromJson({
      'number': 3,
      'state': 'closed',
      'merged_at': '2026-01-01T00:00:00Z',
    });

    expect(pr.merged, isTrue);
    expect(pr.state, 'merged');
  });
}
