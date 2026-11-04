/// CI 检查项（GET /repos/{owner}/{repo}/commits/{ref}/check-runs）。
class CheckRun {
  final String name;
  final String status;
  final String conclusion;
  final String headSha;
  final String detailsUrl;
  final String startedAt;
  final String completedAt;

  CheckRun({
    required this.name,
    required this.status,
    required this.conclusion,
    required this.headSha,
    required this.detailsUrl,
    required this.startedAt,
    required this.completedAt,
  });

  /// 结论：success/failure/cancelled/neutral/timeout/timed_out/action_required
  /// 或空（尚在运行）。
  bool get isSuccess =>
      conclusion == 'success' ||
      conclusion == 'neutral' ||
      (conclusion.isEmpty && status == 'completed');
  bool get isFailure =>
      conclusion == 'failure' ||
      conclusion == 'timeout' ||
      conclusion == 'timed_out' ||
      conclusion == 'cancelled' ||
      conclusion == 'action_required';
  bool get isRunning =>
      conclusion.isEmpty && status != 'completed' && status.isNotEmpty;

  factory CheckRun.fromJson(Map<String, dynamic> json) {
    return CheckRun(
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      conclusion: json['conclusion']?.toString() ?? '',
      headSha: json['head_sha']?.toString() ?? '',
      detailsUrl: json['details_url']?.toString() ?? '',
      startedAt: json['started_at']?.toString() ?? '',
      completedAt: json['completed_at']?.toString() ?? '',
    );
  }
}
