/// Release 附件（/repos/{owner}/{repo}/releases/{release_id}/attach_files）。
class ReleaseAttachFile {
  final String id;
  final String name;
  final int size;
  final String downloadUrl;
  final String uploader;

  ReleaseAttachFile({
    required this.id,
    required this.name,
    required this.size,
    required this.downloadUrl,
    required this.uploader,
  });

  factory ReleaseAttachFile.fromJson(Map<String, dynamic> json) {
    final uploader = json['uploader'] is Map
        ? Map<String, dynamic>.from(json['uploader'] as Map)
        : <String, dynamic>{};
    return ReleaseAttachFile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      size: json['size'] is num ? (json['size'] as num).toInt() : 0,
      downloadUrl: json['browser_download_url']?.toString() ?? '',
      uploader: uploader['login']?.toString() ?? '',
    );
  }

  String get sizeText {
    if (size <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = size.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final text = value < 10 && unit > 0
        ? value.toStringAsFixed(1)
        : value.toStringAsFixed(0);
    return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text} ${units[unit]}';
  }
}
