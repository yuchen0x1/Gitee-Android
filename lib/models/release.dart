class Release {
  final int id;
  final String tagName;
  final String name;
  final String body;
  final String createdAt;
  final String tarballUrl;
  final String zipballUrl;
  final String htmlUrl;
  final bool prerelease;
  final String targetCommitish;
  final String author;
  final List<dynamic> assets;

  Release({
    this.prerelease = false,
    this.id = 0,
    this.targetCommitish = '',
    this.author = '',
    this.assets = const [],
    required this.tagName,
    required this.name,
    required this.body,
    required this.createdAt,
    required this.tarballUrl,
    required this.zipballUrl,
    required this.htmlUrl,
  });

  factory Release.fromJson(Map<String, dynamic> json) {
    return Release(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      tagName: json['tag_name'] ?? '',
      name: json['name'] ?? json['tag_name'] ?? '',
      body: json['body'] ?? '',
      createdAt: json['created_at'] ?? '',
      tarballUrl: json['tarball_url'] ?? '',
      zipballUrl: json['zipball_url'] ?? '',
      htmlUrl: json['html_url'] ?? '',
      prerelease: json['prerelease'] == true,
      targetCommitish: json['target_commitish']?.toString() ?? '',
      author: json['author'] is Map
          ? json['author']['login']?.toString() ?? ''
          : json['author']?.toString() ?? '',
      assets: json['assets'] is List ? json['assets'] as List : const [],
    );
  }
}
