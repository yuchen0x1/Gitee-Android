/// 把 ISO8601 时间转成“刚刚 / x分钟前 / x天前”这种相对时间。
String formatRelativeTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final time = DateTime.tryParse(iso)?.toLocal();
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
  if (diff.inDays < 1) return '${diff.inHours}小时前';
  if (diff.inDays < 30) return '${diff.inDays}天前';
  return formatDate(iso);
}

/// 输出 YYYY-MM-DD 格式的日期。
String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final time = DateTime.tryParse(iso)?.toLocal();
  if (time == null) return iso;
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '${time.year}-$month-$day';
}
