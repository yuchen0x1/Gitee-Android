/// 仓库访问统计（POST /repos/{owner}/{repo}/traffic-data）。
class RepoTraffic {
  final int ip;
  final int pull;
  final int push;
  final int downloadZip;
  final List<RepoTrafficDay> days;

  RepoTraffic({
    required this.ip,
    required this.pull,
    required this.push,
    required this.downloadZip,
    required this.days,
  });

  factory RepoTraffic.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : <String, dynamic>{};
    final counts = json['counts'] is List ? json['counts'] as List : const [];
    return RepoTraffic(
      ip: (summary['ip'] ?? 0) is num ? (summary['ip'] as num).toInt() : 0,
      pull:
          (summary['pull'] ?? 0) is num ? (summary['pull'] as num).toInt() : 0,
      push:
          (summary['push'] ?? 0) is num ? (summary['push'] as num).toInt() : 0,
      downloadZip: (summary['download_zip'] ?? 0) is num
          ? (summary['download_zip'] as num).toInt()
          : 0,
      days: counts
          .map((e) => RepoTrafficDay.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// 单日访问明细，bucket 为当日 0 点的时间戳（秒）。
class RepoTrafficDay {
  final int bucket;
  final int ip;
  final int pull;
  final int push;
  final int downloadZip;

  RepoTrafficDay({
    required this.bucket,
    required this.ip,
    required this.pull,
    required this.push,
    required this.downloadZip,
  });

  DateTime get date =>
      DateTime.fromMillisecondsSinceEpoch(bucket * 1000, isUtc: true);

  factory RepoTrafficDay.fromJson(Map<String, dynamic> json) {
    int toInt(Object? v) => v is num ? v.toInt() : 0;
    return RepoTrafficDay(
      bucket: toInt(json['bucket']),
      ip: toInt(json['ip']),
      pull: toInt(json['pull']),
      push: toInt(json['push']),
      downloadZip: toInt(json['download_zip']),
    );
  }
}
