import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/error_message.dart';
import '../api/gitee_api.dart';
import '../theme/app_theme.dart';
import '../services/composer_draft.dart';
import 'composer_draft_status.dart';

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

  late final ComposerDraft _draft;
  late final String? _sessionToken;

  @override
  void initState() {
    super.initState();
    _sessionToken = GiteeApi.token;
    _draft = ComposerDraft(
        token: _sessionToken,
        kind: 'pr',
        owner: widget.owner,
        repo: widget.repo,
        fields: {
          'title': _titleCtrl,
          'body': _bodyCtrl,
          'head': _headCtrl,
          'base': _baseCtrl
        });
    _draft.addListener(_onDraftChanged);
    unawaited(_draft.restore());
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _draft.removeListener(_onDraftChanged);
    _draft.dispose();
    _titleCtrl.dispose();
    _headCtrl.dispose();
    _baseCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || _draft.loading) return;
    if (GiteeApi.token != _sessionToken) {
      setState(() => _error = '账号已切换，请关闭表单后重新打开');
      return;
    }
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
      await _draft.complete();
      if (mounted) {
        if (_draft.error != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_draft.error!)));
        }
        Navigator.of(context).pop(true);
      }
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
    if (_draft.loading) {
      return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(heightFactor: 1, child: CircularProgressIndicator()));
    }
    return PopScope(
        canPop: !_submitting,
        child: Padding(
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
                    Expanded(
                        child: Text('创建 Pull Request',
                            style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                      onPressed:
                          _submitting ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                ComposerDraftStatus(draft: _draft, enabled: !_submitting),
                TextField(
                  controller: _titleCtrl,
                  enabled: !_submitting,
                  decoration: const InputDecoration(labelText: '标题 *'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _headCtrl,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: '源分支 *',
                    hintText: '如 feature/xxx 或 user/repo:branch',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseCtrl,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: '目标分支 *',
                    hintText: '如 master',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyCtrl,
                  enabled: !_submitting,
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
        ));
  }
}
