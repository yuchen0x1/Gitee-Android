import 'dart:async';

import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/file.dart';
import '../services/offline_cache.dart';
import '../utils/error_message.dart';
import '../theme/app_theme.dart';
import '../widgets/branch_selector.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_views.dart';
import 'code_view_page.dart';

/// 独立文件浏览页：支持分支切换、进入子目录、返回上级与文件预览。
class RepoFileBrowserPage extends StatefulWidget {
  final String owner;
  final String repo;
  final String initialPath;
  final String? title;
  final String? initialBranch;

  const RepoFileBrowserPage({
    super.key,
    required this.owner,
    required this.repo,
    required this.initialPath,
    this.title,
    this.initialBranch,
  });

  @override
  State<RepoFileBrowserPage> createState() => _RepoFileBrowserPageState();
}

class _RepoFileBrowserPageState extends State<RepoFileBrowserPage> {
  final List<String> _history = [];
  List<RepoFile> _files = [];
  List<String> _branches = [];
  String _path = '';
  String _branch = '';
  bool _loading = true;
  bool _offline = false;
  int _filesGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    _branch = widget.initialBranch ?? '';
    _loadBranches();
    _loadFiles();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await GiteeApi.getBranches(widget.owner, widget.repo);
      if (!mounted) return;
      final old = _branch;
      setState(() {
        _branches = branches;
        if (branches.isNotEmpty && !branches.contains(_branch)) {
          _branch = branches.first;
        }
      });
      if (old != _branch) _loadFiles();
    } catch (_) {}
  }

  Future<void> _loadFiles() async {
    final generation = ++_filesGeneration;
    setState(() {
      _loading = true;
      _offline = false;
      _error = null;
    });
    try {
      final files = await GiteeApi.getRepoContents(
        widget.owner,
        widget.repo,
        path: _path,
        branch: _branch.isEmpty ? null : _branch,
      );
      files.sort((a, b) {
        if (a.type == b.type) return a.name.compareTo(b.name);
        return a.type == 'dir' ? -1 : 1;
      });
      unawaited(OfflineCache.write(
        key: OfflineCache.key(
          token: GiteeApi.token,
          type: 'contents',
          parts: [widget.owner, widget.repo, _path, _branch],
        ),
        value: files.map((file) => file.toJson()).toList(),
      ));
      if (!mounted || generation != _filesGeneration) return;
      setState(() {
        _files = files;
        _offline = false;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      final cached = await OfflineCache.read(OfflineCache.key(
        token: GiteeApi.token,
        type: 'contents',
        parts: [widget.owner, widget.repo, _path, _branch],
      ));
      final value = cached?.value;
      if (value is List && mounted && generation == _filesGeneration) {
        final files = value
            .whereType<Map>()
            .map((item) => RepoFile.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        files.sort((a, b) {
          if (a.type == b.type) return a.name.compareTo(b.name);
          return a.type == 'dir' ? -1 : 1;
        });
        setState(() {
          _files = files;
          _offline = true;
          _loading = false;
          _error = null;
        });
      } else if (mounted && generation == _filesGeneration) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  void _openDir(RepoFile file) {
    setState(() {
      _history.add(_path);
      _path = file.path;
      _files = [];
      _error = null;
    });
    _loadFiles();
  }

  void _goUp() {
    if (_history.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _path = _history.removeLast();
      _files = [];
      _error = null;
    });
    _loadFiles();
  }

  /// 直接跳转到路径层级中的某一级目录。
  void _jumpTo(int segmentIndex) {
    if (segmentIndex < 0 || segmentIndex >= _segmentCount) return;
    final target = _segments.take(segmentIndex + 1).join('/');
    if (target == _path) return;
    setState(() {
      _path = target;
      _files = [];
      _error = null;
    });
    _loadFiles();
  }

  List<String> get _segments => _path.isEmpty ? const [] : _path.split('/');

  int get _segmentCount => _segments.length;

  void _openFile(RepoFile file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CodeViewPage(
          owner: widget.owner,
          repo: widget.repo,
          path: file.path,
          fileName: file.name,
          branch: _branch.isEmpty ? null : _branch,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentName =
        _path.isEmpty ? (widget.title ?? '/') : _path.split('/').last;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(currentName, overflow: TextOverflow.ellipsis),
            ),
            if (_offline) ...[
              const SizedBox(width: 6),
              const Icon(Icons.cloud_off_outlined, size: 18),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: _history.isEmpty ? '返回' : '上一级',
          onPressed: _goUp,
        ),
      ),
      body: Column(
        children: [
          BranchSelector(
            branches: _branches,
            branch: _branch,
            onChanged: (value) {
              setState(() {
                _branch = value;
                _files = [];
              });
              _loadFiles();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.folder_outlined,
                    size: 16, color: context.mutedForeground),
                const SizedBox(width: 6),
                Expanded(child: _buildBreadcrumb()),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_files.isEmpty && _loading) {
      return const SkeletonList(variant: SkeletonVariant.issueRow);
    }
    if (_files.isEmpty && _error != null) {
      return ErrorState(message: _error!, onRetry: _loadFiles);
    }
    if (_files.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_off_outlined,
        title: '空目录',
        subtitle: '这个目录下还没有内容',
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: _loadFiles,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Icon(
                file.type == 'dir' ? Icons.folder : Icons.insert_drive_file,
                color: file.type == 'dir'
                    ? AppColors.folderIcon
                    : context.secondaryForeground,
                size: 28,
              ),
              title:
                  Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: file.type == 'file' && file.size != null
                  ? Text(_formatSize(file.size!))
                  : null,
              trailing: Icon(Icons.chevron_right,
                  color: context.mutedForeground),
              onTap: () =>
                  file.type == 'dir' ? _openDir(file) : _openFile(file),
            ),
          );
        },
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  /// 可点击面包屑：根目录 / 一级 / 二级 … 当前目录。
  Widget _buildBreadcrumb() {
    final children = <Widget>[
      _crumbItem('/', 0),
    ];
    for (var i = 0; i < _segmentCount; i++) {
      final isLast = i == _segmentCount - 1;
      children.add(_crumbSeparator());
      children.add(_crumbItem(_segments[i], i + 1, last: isLast));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _crumbSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.chevron_right, size: 14, color: context.mutedForeground),
    );
  }

  Widget _crumbItem(String label, int segmentIndex, {bool last = false}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _jumpTo(segmentIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: last
            ? BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              )
            : null,
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: last ? FontWeight.w700 : FontWeight.w400,
            color:
                last ? AppColors.primaryRed : theme.textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}
