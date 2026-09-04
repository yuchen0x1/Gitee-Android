import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../theme/app_theme.dart';

/// Bottom sheet 表单，用于在仓库中创建 Pull Request。
Future<bool> showCreatePullRequestSheet(
  BuildContext context, {
  required String owner,
  required String repo,
}) async {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PullRequestComposer(owner: owner, repo: repo),
  ).then((ok) => ok ?? false);
}

class _PullRequestComposer extends StatefulWidget {
  final String owner;
  final String repo;

  const _PullRequestComposer({required this.owner, required this.repo});

  @override
  State<_PullRequestComposer> createState() => _PullRequestComposerState();
}

class _PullRequestComposerState extends State<_PullRequestComposer> {
  final _titleCtrl = TextEditingController();
  final _headCtrl = TextEditingController();
  final _baseCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _headCtrl.dispose();
    _baseCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final title = _titleCtrl.text.trim();
    final head = _headCtrl.text.trim();
    final base = _baseCtrl.text.trim();
    if (title.isEmpty || head.isEmpty || base.isEmpty) {
      setState(() => _error = '标题、源分支和目标分支均为必填');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await GiteeApi.createPullRequest(
        owner: widget.owner,
        repo: widget.repo,
        title: title,
        head: head,
        base: base,
        description:
            _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString();
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
                Text('创建 Pull Request',
                    style: Theme.of(context).textTheme.titleLarge),
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
              controller: _headCtrl,
              decoration: const InputDecoration(
                labelText: '源分支 *',
                hintText: '如 feature/xxx 或 user/repo:branch',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baseCtrl,
              decoration: const InputDecoration(
                labelText: '目标分支 *',
                hintText: '如 master',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              decoration: const InputDecoration(
                labelText: '描述',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 5000,
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
                    : const Icon(Icons.send),
                label: Text(_submitting ? '提交中…' : '创建 PR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
