import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/utils/launch_url.dart';

void main() {
  test('仅放行 http/https 外部链接', () async {
    expect(await launchExternalUrl('intent://evil/'), isFalse);
    expect(await launchExternalUrl('tel:123456'), isFalse);
    expect(await launchExternalUrl('sms:123456'), isFalse);
    expect(await launchExternalUrl('javascript:alert(1)'), isFalse);
    expect(await launchExternalUrl('not a url'), isFalse);
    expect(await launchExternalUrl(''), isFalse);
  });
}
