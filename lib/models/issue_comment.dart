import 'user.dart';

class IssueComment {
  final int id;
  final String body;
  final User? user;
  final String createdAt;
  final String updatedAt;
  final String htmlUrl;

  const IssueComment({
    required this.id,
    required this.body,
    required this.user,
    required this.createdAt,
    required this.updatedAt,
    required this.htmlUrl,
  });

  factory IssueComment.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return IssueComment(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      body: json['body']?.toString() ?? '',
      user: rawUser is Map
          ? User.fromJson(Map<String, dynamic>.from(rawUser))
          : null,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      htmlUrl: json['html_url']?.toString() ?? '',
    );
  }
}
