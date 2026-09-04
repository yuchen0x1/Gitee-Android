import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/widgets/app_markdown.dart';

void main() {
  group('AppMarkdown.normalize', () {
    test('converts html images and preserves inline code', () {
      final result = AppMarkdown.normalize(
        'before `<br>` after <img src="https://example.com/a.png" alt="Logo">',
      );

      expect(result, contains('`<br>`'));
      expect(result, contains('![Logo](https://example.com/a.png)'));
    });

    test('preserves fenced code blocks', () {
      final result = AppMarkdown.normalize('```html\n<br/>\n```');

      expect(result, contains('```html'));
      expect(result, contains('<br/>'));
    });

    test('resolves relative markdown images against repository raw URL', () {
      final result = AppMarkdown.normalize(
        '![logo](docs/logo.png)',
        owner: 'yuchen0x1',
        repo: 'gitee_client',
        branch: 'main',
      );

      expect(
        result,
        contains(
          '![logo](https://gitee.com/yuchen0x1/gitee_client/raw/main/docs/logo.png)',
        ),
      );
    });

    test('resolves relative markdown links against repository raw URL', () {
      final result = AppMarkdown.normalize(
        '[guide](../guide.md)',
        owner: 'yuchen0x1',
        repo: 'gitee_client',
        branch: 'main',
      );

      expect(
        result,
        contains(
          '[guide](https://gitee.com/yuchen0x1/gitee_client/raw/guide.md)',
        ),
      );
    });
  });
}
