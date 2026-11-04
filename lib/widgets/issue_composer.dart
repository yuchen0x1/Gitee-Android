import 'package:flutter/material.dart';
import '../utils/error_message.dart';
import '../api/gitee_api.dart';
import '../theme/app_theme.dart';

/// Bottom sheet 表单，用于在仓库中创建新 Issue。
Future<bool> showCreateIssueSheet(
  BuildContext context, {
  required String owner,
  required String repo,
}) async {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _IssueComposer(owner: owner, repo: repo),
  ).then((ok) => ok ?? false);
}

class _IssueComposer extends StatefulWidget {
  final String owner;
  final String repo;

  const _IssueComposer({required this.owner, required this.repo});

  @override
  State<_IssueComposer> createState() => _IssueComposerState();
}

class _IssueComposerState extends State<_IssueComposer> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _labelsCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _labelsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '请输入 Issue 标题');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await GiteeApi.createIssue(
        owner: widget.owner,
        repo: widget.repo,
        title: title,
        description:
            _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
        labels:
            _labelsCtrl.text.trim().isEmpty ? null : _labelsCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('创建 Issue', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: '标题 *'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              decoration: const InputDecoration(
                labelText: '描述',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              maxLength: 5000,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _labelsCtrl,
              decoration: const InputDecoration(
                labelText: '标签（逗号分隔）',
              ),
              textInputAction: TextInputAction.done,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppColors.primaryRed)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add),
                label: Text(_submitting ? '提交中…' : '创建'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
