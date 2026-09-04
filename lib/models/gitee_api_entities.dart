import 'user.dart';

class PullRequestComment {
  final int id;
  final String body;
  final User? user;
  final String createdAt;
  final String updatedAt;
  final String path;
  final String? position;
  final String htmlUrl;

  PullRequestComment({
    required this.id,
    required this.body,
    required this.user,
    required this.createdAt,
    required this.updatedAt,
    required this.path,
    required this.position,
    required this.htmlUrl,
  });

  factory PullRequestComment.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return PullRequestComment(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      body: json['body']?.toString() ?? '',
      user: rawUser is Map
          ? User.fromJson(Map<String, dynamic>.from(rawUser))
          : null,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      path: json['path']?.toString() ?? json['file']?.toString() ?? '',
      position: json['position']?.toString(),
      htmlUrl: json['html_url']?.toString() ?? '',
    );
  }
}

class PullRequestReview {
  final int id;
  final String body;
  final String state;
  final User? user;
  final String submittedAt;
  final String htmlUrl;

  PullRequestReview({
    required this.id,
    required this.body,
    required this.state,
    required this.user,
    required this.submittedAt,
    required this.htmlUrl,
  });

  factory PullRequestReview.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return PullRequestReview(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      body: json['body']?.toString() ?? '',
      state: json['state']?.toString() ?? json['event']?.toString() ?? '',
      user: rawUser is Map
          ? User.fromJson(Map<String, dynamic>.from(rawUser))
          : null,
      submittedAt: json['submitted_at']?.toString() ??
          json['created_at']?.toString() ??
          '',
      htmlUrl: json['html_url']?.toString() ?? '',
    );
  }
}

class PullRequestFile {
  final String filename;
  final String status;
  final int additions;
  final int deletions;
  final int changes;
  final String rawUrl;
  final String blobUrl;
  final String patch;

  PullRequestFile({
    required this.filename,
    required this.status,
    required this.additions,
    required this.deletions,
    required this.changes,
    required this.rawUrl,
    required this.blobUrl,
    required this.patch,
  });

  factory PullRequestFile.fromJson(Map<String, dynamic> json) {
    return PullRequestFile(
      filename: json['filename']?.toString() ?? json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      additions: _intValue(json['additions']),
      deletions: _intValue(json['deletions']),
      changes: _intValue(json['changes']),
      rawUrl: json['raw_url']?.toString() ?? '',
      blobUrl: json['blob_url']?.toString() ??
          json['contents_url']?.toString() ??
          '',
      patch: json['patch']?.toString() ?? '',
    );
  }
}

class RepositoryTag {
  final String name;
  final String sha;
  final String message;
  final String tarballUrl;
  final String zipballUrl;

  RepositoryTag({
    required this.name,
    required this.sha,
    required this.message,
    required this.tarballUrl,
    required this.zipballUrl,
  });

  factory RepositoryTag.fromJson(Map<String, dynamic> json) {
    final rawCommit = json['commit'];
    final commit = rawCommit is Map
        ? Map<String, dynamic>.from(rawCommit)
        : const <String, dynamic>{};
    return RepositoryTag(
      name: json['name']?.toString() ?? '',
      sha: rawCommit is Map
          ? commit['sha']?.toString() ?? ''
          : rawCommit?.toString() ?? json['sha']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      tarballUrl: json['tarball_url']?.toString() ?? '',
      zipballUrl: json['zipball_url']?.toString() ?? '',
    );
  }
}

class RepositoryBranch {
  final String name;
  final String sha;
  final bool protected;

  RepositoryBranch(
      {required this.name, required this.sha, required this.protected});

  factory RepositoryBranch.fromJson(Map<String, dynamic> json) {
    final rawCommit = json['commit'];
    final commit = rawCommit is Map
        ? Map<String, dynamic>.from(rawCommit)
        : const <String, dynamic>{};
    return RepositoryBranch(
      name: json['name']?.toString() ?? '',
      sha: rawCommit is Map
          ? commit['sha']?.toString() ?? ''
          : rawCommit?.toString() ?? json['sha']?.toString() ?? '',
      protected: json['protected'] == true,
    );
  }
}

class Webhook {
  final int id;
  final String url;
  final String title;
  final String password;
  final String result;
  final int projectId;
  final int resultCode;
  final String createdAt;
  final bool pushEvents;
  final bool tagPushEvents;
  final bool issuesEvents;
  final bool noteEvents;
  final bool mergeRequestsEvents;

  Webhook({
    required this.id,
    required this.url,
    required this.title,
    required this.password,
    required this.result,
    required this.projectId,
    required this.resultCode,
    required this.createdAt,
    required this.pushEvents,
    required this.tagPushEvents,
    required this.issuesEvents,
    required this.noteEvents,
    required this.mergeRequestsEvents,
  });

  factory Webhook.fromJson(Map<String, dynamic> json) {
    return Webhook(
      id: _intValue(json['id']),
      url: json['url']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      result: json['result']?.toString() ?? '',
      projectId: _intValue(json['project_id']),
      resultCode: _intValue(json['result_code']),
      createdAt: json['created_at']?.toString() ?? '',
      pushEvents: json['push_events'] == true,
      tagPushEvents: json['tag_push_events'] == true,
      issuesEvents: json['issues_events'] == true,
      noteEvents: json['note_events'] == true,
      mergeRequestsEvents: json['merge_requests_events'] == true,
    );
  }
}

class Organization {
  final int id;
  final String login;
  final String name;
  final String description;
  final String htmlUrl;
  final String avatarUrl;
  final String url;
  final int followCount;

  Organization({
    required this.id,
    required this.login,
    required this.name,
    required this.description,
    required this.htmlUrl,
    required this.avatarUrl,
    required this.url,
    required this.followCount,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: _intValue(json['id']),
      login: json['login']?.toString() ?? '',
      name: json['name']?.toString() ?? json['login']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      htmlUrl: json['html_url']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? '',
      url: json['url']?.toString() ?? json['html_url']?.toString() ?? '',
      followCount: _intValue(json['follow_count']),
    );
  }
}

class Contributor {
  final String email;
  final String name;
  final int contributions;

  Contributor({
    required this.email,
    required this.name,
    required this.contributions,
  });

  factory Contributor.fromJson(Map<String, dynamic> json) {
    return Contributor(
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      contributions: _intValue(json['contributions']),
    );
  }
}

class CompareResult {
  final dynamic baseCommit;
  final dynamic mergeBaseCommit;
  final List<dynamic> commits;
  final List<dynamic> files;
  final bool truncated;

  CompareResult({
    required this.baseCommit,
    required this.mergeBaseCommit,
    required this.commits,
    required this.files,
    required this.truncated,
  });

  factory CompareResult.fromJson(Map<String, dynamic> json) {
    return CompareResult(
      baseCommit: json['base_commit'],
      mergeBaseCommit: json['merge_base_commit'],
      commits: json['commits'] is List ? json['commits'] as List : const [],
      files: json['files'] is List ? json['files'] as List : const [],
      truncated: json['truncated'] == true,
    );
  }
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
