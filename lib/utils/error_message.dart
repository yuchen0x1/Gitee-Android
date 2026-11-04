import '../api/api_client.dart';

/// 把任意异常转换为用户可读的中文提示。
/// GiteeApiException 已携带业务文案（如“令牌无效”）直接透传；
/// 其它异常（网络层、解析等）统一归类描述，避免把原始堆栈直出给用户。
String friendlyError(Object error) {
  if (error is GiteeApiException) {
    return error.message;
  }
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Connection') ||
      text.contains('Failed host') ||
      text.contains('Network')) {
    return '网络异常，请检查网络连接后重试';
  }
  if (text.contains('TimeoutException')) {
    return '请求超时，请稍后重试';
  }
  if (text.contains('FormatException') ||
      text.contains('type cast') ||
      text.contains('JSON')) {
    return '数据解析异常，请稍后重试';
  }
  return '操作失败，请稍后重试';
}
