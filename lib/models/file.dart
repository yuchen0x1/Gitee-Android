class RepoFile {
  final String name;
  final String path;
  final String type; // file / dir
  final int? size;
  final String? content;
  final String? downloadUrl;
  final String? sha;

  RepoFile({
    required this.name,
    required this.path,
    required this.type,
    this.size,
    this.content,
    this.downloadUrl,
    this.sha,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'type': type,
        'size': size,
        'content': content,
        'download_url': downloadUrl,
        'sha': sha,
      };

  factory RepoFile.fromJson(Map<String, dynamic> json) {
    return RepoFile(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      type: json['type'] ?? 'file',
      size: json['size'],
      content: json['content'],
      downloadUrl: json['download_url'],
      sha: json['sha'],
    );
  }
}
