import 'package:flutter/material.dart';
import '../services/composer_draft.dart';

class ComposerDraftStatus extends StatelessWidget {
  const ComposerDraftStatus(
      {super.key, required this.draft, this.enabled = true});
  final ComposerDraft draft;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final message = draft.error ??
        (draft.saving
            ? '正在保存草稿…'
            : draft.restored && draft.saved
                ? '已恢复本地草稿'
                : draft.saved && draft.hasContent
                    ? '草稿已保存到本机'
                    : '输入自动保存为本地草稿');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(draft.error == null ? Icons.edit_note : Icons.error_outline,
            size: 20),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
        if (draft.error != null)
          TextButton(
              onPressed: enabled ? draft.retry : null, child: const Text('重试')),
        if (draft.hasContent)
          TextButton(
              onPressed: enabled ? draft.clear : null,
              child: const Text('清空草稿')),
      ]),
    );
  }
}
