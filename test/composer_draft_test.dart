import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/services/composer_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('draft scope separates account, repo, and form kind', () {
    final key = DraftStore.key('secret', 'issue', 'o', 'r');
    expect(key, isNot(contains('secret')));
    expect(key, isNot(DraftStore.key('other', 'issue', 'o', 'r')));
    expect(key, isNot(DraftStore.key('secret', 'pr', 'o', 'r')));
    expect(key, isNot(DraftStore.key('secret', 'issue', 'o', 'r2')));
  });

  test('secure drafts round trip and empty drafts are removed', () async {
    final key = DraftStore.key('a', 'issue', 'o', 'r');
    await DraftStore.write(key, {'title': '标题', 'body': '正文'});
    expect(await DraftStore.read(key), {'title': '标题', 'body': '正文'});
    await DraftStore.write(key, {});
    expect(await DraftStore.read(key), isEmpty);
  });

  testWidgets('closing flushes unsaved text before reopening', (tester) async {
    final title = TextEditingController();
    final draft = ComposerDraft(
        token: 'a',
        kind: 'issue',
        owner: 'o',
        repo: 'r',
        fields: {'title': title});
    await draft.restore();
    title.text = 'unsaved';
    draft.dispose();
    title.dispose();
    final restoredTitle = TextEditingController();
    final reopened = ComposerDraft(
        token: 'a',
        kind: 'issue',
        owner: 'o',
        repo: 'r',
        fields: {'title': restoredTitle});
    await reopened.restore();
    expect(restoredTitle.text, 'unsaved');
    expect(reopened.restored, isTrue);
    await reopened.complete();
    reopened.dispose();
    restoredTitle.dispose();
    expect(await DraftStore.read(reopened.key), isEmpty);
  });

  testWidgets('debounced save and clear cannot resurrect an old draft',
      (tester) async {
    final title = TextEditingController();
    final draft = ComposerDraft(
        token: 'a',
        kind: 'pr',
        owner: 'o',
        repo: 'r',
        fields: {'title': title});
    await draft.restore();
    title.text = 'first';
    await tester.pump(const Duration(milliseconds: 450));
    await draft.clear();
    draft.dispose();
    title.dispose();
    expect(await DraftStore.read(draft.key), isEmpty);
  });
}
