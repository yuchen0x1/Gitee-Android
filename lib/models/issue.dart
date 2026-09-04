import 'user.dart';

int _intVal(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

class Label {
  final String name;
  final String color;

  const Label({required this.name, required this.color});

  factory Label.fromJson(Map<String, dynamic> json) {
    return Label(
      name: json['name'] ?? '',
      color: json['color'] ?? '',
    );
  }
}

class Issue {
  final String number;
  final String title;
  final String state; // open / closed
  final User? user;
  final List<Label> labels;
  final String createdAt;
  final String updatedAt;
  final String body;
  final int comments;
  final String htmlUrl;
  final String repositoryFullName;
  final String repositoryOwner;
  final String repositoryName;

  Issue({
    required this.number,
    required this.title,
    required this.state,
    required this.user,
    required this.labels,
    required this.createdAt,
    required this.updatedAt,
    required this.body,
    required this.comments,
    required this.htmlUrl,
    this.repositoryFullName = '',
    this.repositoryOwner = '',
    this.repositoryName = '',
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final rawLabels = json['labels'];
    final rawRepository = json['repository'];
    final repository = rawRepository is Map
        ? Map<String, dynamic>.from(rawRepository)
        : const <String, dynamic>{};
    var fullName = repository['full_name']?.toString() ?? '';
    if (fullName.isEmpty) {
      final rawUrl = json['repository_url']?.toString() ?? '';
      final uri = Uri.tryParse(rawUrl);
      if (uri != null && uri.pathSegments.length >= 2) {
        fullName =
            uri.pathSegments.sublist(uri.pathSegments.length - 2).join('/');
      }
    }
    final parts = fullName.split('/');
    return Issue(
      number: json['number']?.toString() ?? '',
      title: json['title'] ?? '',
      state: json['state'] ?? 'open',
      user: rawUser is Map
          ? User.fromJson(Map<String, dynamic>.from(rawUser))
          : null,
      labels: rawLabels is List
          ? rawLabels
              .whereType<Map>()
              .map((e) => Label.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      body: json['body'] ?? '',
      comments: _intVal(json['comments']),
      htmlUrl: json['html_url'] ?? '',
      repositoryFullName: fullName,
      repositoryOwner: parts.isNotEmpty ? parts.first : '',
      repositoryName: parts.length > 1 ? parts.last : '',
    );
  }
}
