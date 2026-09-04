int _intVal(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

class User {
  final int id;
  final String login;
  final String name;
  final String avatarUrl;
  final String bio;
  final int publicRepos;
  final int followers;
  final int following;
  final String htmlUrl;
  final String createdAt;

  User({
    required this.id,
    required this.login,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.publicRepos,
    required this.followers,
    required this.following,
    this.htmlUrl = '',
    this.createdAt = '',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _intVal(json['id']),
      login: json['login'] ?? '',
      name: json['name'] ?? json['login'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      bio: json['bio'] ?? '这个人很懒，什么都没有写',
      publicRepos: _intVal(json['public_repos']),
      followers: _intVal(json['followers']),
      following: _intVal(json['following']),
      htmlUrl: json['html_url'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
