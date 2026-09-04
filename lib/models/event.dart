import 'user.dart';

class Event {
  final String id;
  final String type;
  final User? actor;
  final String repoName;
  final String createdAt;
  final String payload;

  Event({
    this.id = '',
    required this.type,
    required this.actor,
    required this.repoName,
    required this.createdAt,
    required this.payload,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    final rawActor = json['actor'];
    final rawRepo =
        json['repo'] is Map ? json['repo'] as Map : const <dynamic, dynamic>{};
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    return Event(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? '',
      actor: rawActor is Map
          ? User.fromJson(Map<String, dynamic>.from(rawActor))
          : null,
      repoName:
          rawRepo['full_name']?.toString() ?? rawRepo['name']?.toString() ?? '',
      createdAt: json['created_at'] ?? '',
      payload: _payloadSummary(json['type'] ?? '', payload),
    );
  }
}

String _payloadSummary(String type, Map<String, dynamic> payload) {
  switch (type) {
    case 'PushEvent':
      final ref =
          (payload['ref'] ?? '').toString().replaceFirst('refs/heads/', '');
      final commits =
          payload['commits'] is List ? payload['commits'] as List : const [];
      return '推送了 ${commits.length} 个提交到分支 $ref';
    case 'IssuesEvent':
      final issue = payload['issue'] is Map
          ? payload['issue'] as Map
          : const <dynamic, dynamic>{};
      return '${payload['action'] ?? '更新'}了 Issue：${issue['title'] ?? ''}';
    case 'WatchEvent':
      return 'Star 了仓库';
    case 'ForkEvent':
      return 'Fork 了仓库';
    case 'CreateEvent':
      return '创建了 ${payload['ref_type'] ?? '仓库'} ${payload['ref'] ?? ''}';
    case 'DeleteEvent':
      return '删除了 ${payload['ref_type'] ?? '仓库'} ${payload['ref'] ?? ''}';
    case 'PullRequestEvent':
      return '${payload['action'] ?? '更新'}了 Pull Request';
    case 'ReleaseEvent':
      final release = payload['release'] is Map
          ? payload['release'] as Map
          : const <dynamic, dynamic>{};
      return '发布了版本 ${release['tag_name'] ?? ''}';
    case 'ForkApplyEvent':
      return '提交了 Pull Request';
    default:
      return '产生了新的动态';
  }
}
