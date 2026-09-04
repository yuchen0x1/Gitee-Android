int _intVal(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

class Repo {
  final int id;
  final String fullName;
  final String name;
  final String description;
  final String ownerLogin;
  final String ownerAvatar;
  final int stars;
  final int forks;
  final int watchers;
  final String language;
  final bool isPrivate;
  final String htmlUrl;
  final String defaultBranch;
  final String createdAt;
  final String updatedAt;
  final String? readme;

  Repo({
    required this.id,
    required this.fullName,
    required this.name,
    required this.description,
    required this.ownerLogin,
    required this.ownerAvatar,
    required this.stars,
    required this.forks,
    required this.watchers,
    required this.language,
    required this.isPrivate,
    required this.htmlUrl,
    this.defaultBranch = 'master',
    this.createdAt = '',
    this.updatedAt = '',
    this.readme,
  });

  factory Repo.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'];
    final ownerMap = owner is Map ? owner : const <String, dynamic>{};
    return Repo(
      id: _intVal(json['id']),
      fullName: json['full_name'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '暂无描述',
      ownerLogin: ownerMap['login'] ?? '',
      ownerAvatar: ownerMap['avatar_url'] ?? '',
      stars: _intVal(json['stargazers_count']),
      forks: _intVal(json['forks_count']),
      watchers: _intVal(json['watchers_count']),
      language: json['language'] ?? '未知',
      isPrivate: json['private'] ?? false,
      htmlUrl: json['html_url'] ?? '',
      defaultBranch: json['default_branch'] ?? 'master',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? json['pushed_at'] ?? '',
    );
  }
}
