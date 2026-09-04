import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/models/gitee_api_entities.dart';

void main() {
  test('RepositoryBranch parses string commit sha', () {
    final branch = RepositoryBranch.fromJson({
      'name': 'main',
      'commit': 'abc123',
      'protected': true,
    });

    expect(branch.name, 'main');
    expect(branch.sha, 'abc123');
    expect(branch.protected, isTrue);
  });

  test('RepositoryTag parses string commit sha', () {
    final tag = RepositoryTag.fromJson({
      'name': 'v1.0.0',
      'commit': 'def456',
      'message': 'release',
    });

    expect(tag.name, 'v1.0.0');
    expect(tag.sha, 'def456');
    expect(tag.message, 'release');
  });

  test('CompareResult uses Gitee fields', () {
    final result = CompareResult.fromJson({
      'base_commit': {'sha': 'base'},
      'merge_base_commit': {'sha': 'merge'},
      'commits': [
        {'sha': 'c1'},
      ],
      'files': [
        {'filename': 'a.txt'},
      ],
      'truncated': true,
    });

    expect(result.baseCommit, isA<Map>());
    expect(result.mergeBaseCommit, isA<Map>());
    expect(result.commits, hasLength(1));
    expect(result.files, hasLength(1));
    expect(result.truncated, isTrue);
  });

  test('Webhook parses official Hook fields', () {
    final webhook = Webhook.fromJson({
      'id': 7,
      'url': 'https://example.com/hook',
      'title': 'CI',
      'result_code': 0,
      'push_events': true,
      'merge_requests_events': true,
    });

    expect(webhook.id, 7);
    expect(webhook.title, 'CI');
    expect(webhook.pushEvents, isTrue);
    expect(webhook.mergeRequestsEvents, isTrue);
  });
}
