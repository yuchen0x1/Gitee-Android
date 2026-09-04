import 'user.dart';

class CommitFile {
  final String filename;
  final String status;
  final int additions;
  final int deletions;
  final String? patch;

  CommitFile({
    required this.filename,
    required this.status,
    required this.additions,
    required this.deletions,
    this.patch,
  });

  factory CommitFile.fromJson(Map<String, dynamic> json) {
    return CommitFile(
      filename: json['filename'] ?? '',
      status: json['status'] ?? '',
      additions: _int(json['additions']),
      deletions: _int(json['deletions']),
      patch: json['patch'],
    );
  }
}

class Commit {
  final String sha;
  final String message;
  final User? author;
  final String date;
  final int additions;
  final int deletions;
  final int totalChanges;
  final List<CommitFile> files;

  Commit({
    required this.sha,
    required this.message,
    required this.author,
    required this.date,
    required this.additions,
    required this.deletions,
    required this.totalChanges,
    required this.files,
  });

  factory Commit.fromJson(Map<String, dynamic> json) {
    final commitMap = json['commit'] is Map
        ? Map<String, dynamic>.from(json['commit'] as Map)
        : <String, dynamic>{};
    final authorMap = commitMap['author'] is Map
        ? Map<String, dynamic>.from(commitMap['author'] as Map)
        : <String, dynamic>{};
    final rawAuthor = json['author'];
    final stats = json['stats'] is Map
        ? Map<String, dynamic>.from(json['stats'] as Map)
        : <String, dynamic>{};
    final rawFiles = json['files'];
    return Commit(
      sha: json['sha'] ?? '',
      message: commitMap['message'] ?? '',
      author: rawAuthor is Map
          ? User.fromJson(Map<String, dynamic>.from(rawAuthor))
          : null,
      date: authorMap['date'] ?? json['created_at'] ?? '',
      additions: _int(stats['additions']),
      deletions: _int(stats['deletions']),
      totalChanges: _int(stats['total']),
      files: rawFiles is List
          ? rawFiles
              .whereType<Map>()
              .map((e) => CommitFile.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
