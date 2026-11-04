import 'package:flutter/material.dart';
import '../utils/error_message.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:highlight/highlight.dart';
import '../api/gitee_api.dart';
import '../api/api_client.dart';
import '../theme/app_theme.dart';
import '../theme/code_theme.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_views.dart';

/// 代码/图片查看页：等宽字体代码视图，图片支持缩放预览。
class CodeViewPage extends StatefulWidget {
  final String owner;
  final String repo;
  final String path;
  final String fileName;
  final String? branch;

  const CodeViewPage({
    super.key,
    required this.owner,
    required this.repo,
    required this.path,
    required this.fileName,
    this.branch,
  });

  @override
  State<CodeViewPage> createState() => _CodeViewPageState();
}

class _CodeViewPageState extends State<CodeViewPage> {
  static final _imageExts = [
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.bmp',
    '.webp',
    '.svg',
    '.ico',
  ];

  String? _content;
  bool _loading = true;
  String? _error;
  late bool _isImage;
  bool _wrapEnabled = false;
  String _sha = '';

  String get _branch {
    final value = widget.branch;
    if (value == null || value.isEmpty) return 'master';
    return value;
  }

  String get _language {
    final ext = widget.fileName.contains('.')
        ? widget.fileName.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'dart':
        return 'dart';
      case 'js':
      case 'mjs':
      case 'cjs':
        return 'javascript';
      case 'ts':
        return 'typescript';
      case 'json':
        return 'json';
      case 'py':
        return 'python';
      case 'java':
        return 'java';
      case 'go':
        return 'go';
      case 'c':
      case 'h':
        return 'c';
      case 'cpp':
      case 'cc':
      case 'hpp':
        return 'cpp';
      case 'cs':
        return 'cs';
      case 'swift':
        return 'swift';
      case 'kt':
        return 'kotlin';
      case 'rb':
        return 'ruby';
      case 'php':
        return 'php';
      case 'rs':
        return 'rust';
      case 'sh':
      case 'bash':
        return 'shell';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'html':
      case 'htm':
      case 'xml':
        return 'xml';
      case 'css':
        return 'css';
      case 'sql':
        return 'sql';
      case 'md':
        return 'markdown';
      default:
        return '';
    }
  }

  TextSpan _highlightCode(TextStyle base) {
    final content = _content ?? '';
    if (content.trim().isEmpty) {
      return TextSpan(
          text: content.isEmpty ? '// 无法加载文件内容' : content, style: base);
    }
    final colors = CodeTheme.colorsOf(Theme.of(context).brightness);
    final result = highlight.parse(content, language: _language);
    return TextSpan(
      style: base,
      children: (result.nodes ?? const []).map((node) {
        final cls = node.className;
        if (cls == null || cls.isEmpty) return TextSpan(text: node.value);
        final color = colors[cls];
        return TextSpan(
          text: node.value,
          style: color == null ? null : TextStyle(color: color),
        );
      }).toList(),
    );
  }

  @override
  void initState() {
    super.initState();
    _isImage = _imageExts.any((e) => widget.fileName.toLowerCase().endsWith(e));
    if (!_isImage) _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() => _loading = true);
    try {
      final result = await GiteeApi.getFileWithSha(
        widget.owner,
        widget.repo,
        widget.path,
        branch: _branch == 'master' ? null : _branch,
      );
      if (!mounted) return;
      setState(() {
        _content = result.content;
        _sha = result.sha;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  void _copyCode() {
    if (_content == null) return;
    Clipboard.setData(ClipboardData(text: _content!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }

  Future<void> _editFile() async {
    if (_content == null || _sha.isEmpty) return;
    final controller = TextEditingController(text: _content);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑文件'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存')),
        ],
      ),
    );
    controller.dispose();
    if (saved != true || !mounted) return;
    final newContent = controller.text;
    if (newContent == _content) return;
    try {
      await GiteeApi.updateRepoFile(
        owner: widget.owner,
        repo: widget.repo,
        path: widget.path,
        content: base64Encode(utf8.encode(newContent)),
        sha: _sha,
        message: '通过 Gitee Client 编辑 ${widget.fileName}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件已保存')),
        );
        _loadContent();
      }
    } on GiteeApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deleteFile() async {
    if (_sha.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定要删除 ${widget.fileName} 吗？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await GiteeApi.deleteRepoFile(
        owner: widget.owner,
        repo: widget.repo,
        path: widget.path,
        sha: _sha,
        message: '通过 Gitee Client 删除 ${widget.fileName}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件已删除')),
        );
        Navigator.pop(context, true);
      }
    } on GiteeApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_isImage && _content != null) ...[
            IconButton(
              icon: Icon(
                  _wrapEnabled ? Icons.wrap_text : Icons.wrap_text_outlined),
              tooltip: _wrapEnabled ? '关闭自动换行' : '自动换行',
              onPressed: () => setState(() => _wrapEnabled = !_wrapEnabled),
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: '复制代码',
              onPressed: _copyCode,
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _editFile();
                if (v == 'delete') _deleteFile();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑文件')),
                const PopupMenuItem(value: 'delete', child: Text('删除文件')),
              ],
            ),
          ],
        ],
      ),
      body: _isImage ? _buildImageView() : _buildCodeView(),
    );
  }

  Widget _buildImageView() {
    final pathSegments = widget.path
        .split('/')
        .where((e) => e.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    final url =
        'https://gitee.com/${Uri.encodeComponent(widget.owner)}/${Uri.encodeComponent(widget.repo)}/raw/${Uri.encodeComponent(_branch)}/$pathSegments';
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Image.network(
          url,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              width: 120,
              height: 120,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined,
                    size: 56, color: AppColors.textTertiary),
                SizedBox(height: 12),
                Text('图片无法加载'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCodeView() {
    if (_loading) return const SkeletonList(itemCount: 4);
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _loadContent);
    }
    final theme = Theme.of(context);
    final textStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.6,
      color: CodeTheme.textOf(theme.brightness),
    );
    final code = SelectableText.rich(_highlightCode(textStyle));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CodeTheme.backgroundOf(theme.brightness),
          borderRadius: BorderRadius.circular(12),
        ),
        child: _wrapEnabled
            ? code
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: code,
              ),
      ),
    );
  }
}
