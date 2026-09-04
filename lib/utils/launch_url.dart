import 'package:url_launcher/url_launcher.dart';

/// 打开外部链接；仅放行 http/https，防止 README、通知等服务器可控内容
/// 通过 intent://、tel:、sms: 等任意 scheme 唤起系统能力。
Future<bool> launchExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
