import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/gitee_api_entities.dart';
import '../theme/app_theme.dart';
import '../widgets/app_markdown.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_views.dart';
import '../widgets/time_format.dart';
import 'gist_composer_page.dart';

/// Gist 详情：描述 + 文件内容，支持收藏 / 编辑 / 删除。
class GistDetailPage extends StatefulWidget {
  final String gistId;

  const GistDetailPage({super.key, required this.gistId});

  @override
  State<GistDetailPage> createState() => _GistDetailPageState();
}

class _GistDetailPageState extends State<GistDetailPage> {
  Gist? _gist;
  bool _loading = true;
  bool _starred = false;
  bool _starInFlight = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final gist = await GiteeApi.getGistDetail(widget.gistId);
      final starred = await _checkStarred();
      if (!mounted) return;
      setState(() {
        _gist = gist;
        _starred = starred;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// 204 视为已收藏，404 视为未收藏。
  Future<bool> _checkStarred() async {
    try {
      await GiteeApi.request('GET', '/gists/${widget.gistId}/star');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggleStar() async {
    if (_starInFlight) return;
    setState(() => _starInFlight = true);
    try {
      if (_starred) {
        await GiteeApi.unstarGist(widget.gistId);
      } else {
        await GiteeApi.starGist(widget.gistId);
      }
      if (mounted) {
        setState(() {
          _starred = !_starred;
          _starInFlight = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_starred ? '已收藏' : '已取消收藏')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _starInFlight = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _edit() async {
    final gist = _gist;
    if (gist == null) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GistComposerPage(existing: gist),
      ),
    );
    if (updated == true) _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除代码片段'),
        content: const Text('删除后无法恢复，确定要删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryRed),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await GiteeApi.deleteGist(widget.gistId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已删除')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: SkeletonList());
    if (_gist == null && _error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('代码片段')),
        body: ErrorState(message: _error!, onRetry: _load),
      );
    }
    final gist = _gist!;
    return Scaffold(
      appBar: AppBar(
        title: Text(gist.files.isNotEmpty ? gist.files.first.filename : gist.id),
        actions: [
          IconButton(
            tooltip: _starred ? '取消收藏' : '收藏',
            onPressed: _starInFlight ? null : _toggleStar,
            icon: Icon(
              _starred ? Icons.star : Icons.star_border,
              color: _starred ? AppColors.starColor : null,
            ),
          ),
          IconButton(tooltip: '编辑', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
          IconButton(tooltip: '删除', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (gist.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(gist.description,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            Text(
              '${gist.isPublic ? '公开' : '私密'} · '
              '创建于 ${formatDate(gist.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            for (final file in gist.files) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
                child: Text(file.filename,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1E2E)
                      : const Color(0xFFF5F6FA),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10),
                  ),
                ),
                child: file.content.isEmpty
                    ? Text('（无内容）',
                        style: Theme.of(context).textTheme.bodySmall)
                    : AppMarkdown(data: file.content),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
