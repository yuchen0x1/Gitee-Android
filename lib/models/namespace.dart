/// 创建仓库时的归属空间（GET /user/namespaces）。
class Namespace {
  final String id;
  final String type;
  final String name;
  final String path;
  final String htmlUrl;

  Namespace({
    required this.id,
    required this.type,
    required this.name,
    required this.path,
    required this.htmlUrl,
  });

  bool get isOrganization => type.toLowerCase().contains('org');

  factory Namespace.fromJson(Map<String, dynamic> json) {
    return Namespace(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      htmlUrl: json['html_url']?.toString() ?? '',
    );
  }
}
