class AppNotification {
  final String id;
  final String type;
  final String title;
  final String repository;
  final bool unread;
  final String updatedAt;
  final String htmlUrl;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.repository,
    required this.unread,
    required this.updatedAt,
    required this.htmlUrl,
  });

  AppNotification asRead() => AppNotification(
        id: id,
        type: type,
        title: title,
        repository: repository,
        unread: false,
        updatedAt: updatedAt,
        htmlUrl: htmlUrl,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'] is Map
        ? Map<String, dynamic>.from(json['subject'] as Map)
        : <String, dynamic>{};
    final repo = json['repository'] is Map
        ? Map<String, dynamic>.from(json['repository'] as Map)
        : <String, dynamic>{};
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: subject['type']?.toString() ?? json['type']?.toString() ?? '通知',
      title:
          subject['title']?.toString() ?? json['content']?.toString() ?? '通知',
      repository: repo['full_name']?.toString() ?? '',
      unread: json['unread'] == true ||
          json['unread'] == 1 ||
          json['unread']?.toString().toLowerCase() == 'true',
      updatedAt:
          (json['updated_at'] ?? subject['updated_at'])?.toString() ?? '',
      htmlUrl:
          json['html_url']?.toString() ?? subject['html_url']?.toString() ?? '',
    );
  }
}
