import 'user.dart';

class PullRequest {
  final int number;
  final String title;
  final String state; // open / closed / merged
  final User? user;
  final String headBranch;
  final String baseBranch;
  final String createdAt;
  final String updatedAt;
  final String body;
  final bool merged;
  final String htmlUrl;

  PullRequest({
    required this.number,
    required this.title,
    required this.state,
    required this.user,
    required this.headBranch,
    required this.baseBranch,
    required this.createdAt,
    required this.updatedAt,
    required this.body,
    required this.merged,
    required this.htmlUrl,
  });

  factory PullRequest.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final rawHead = json['head'];
    final rawBase = json['base'];
    final head = rawHead is Map
        ? Map<String, dynamic>.from(rawHead)
        : <String, dynamic>{'ref': rawHead?.toString()};
    final base = rawBase is Map
        ? Map<String, dynamic>.from(rawBase)
        : <String, dynamic>{'ref': rawBase?.toString()};
    final mergedAt = json['merged_at']?.toString() ?? '';
    final merged = json['merged'] == true ||
        mergedAt.isNotEmpty ||
        json['state'] == 'merged';
    return PullRequest(
      number: int.tryParse(json['number']?.toString() ?? '') ?? 0,
      title: json['title'] ?? '',
      state: merged ? 'merged' : (json['state'] ?? 'open'),
      user: rawUser is Map
          ? User.fromJson(Map<String, dynamic>.from(rawUser))
          : null,
      headBranch: head['ref'] ?? '',
      baseBranch: base['ref'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      body: json['body'] ?? '',
      merged: merged,
      htmlUrl: json['html_url'] ?? '',
    );
  }
}
