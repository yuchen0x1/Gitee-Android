import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '../utils/launch_url.dart';

/// 适配深浅色模式的 Markdown 渲染组件。
class AppMarkdown extends StatelessWidget {
  final String data;
  final String? owner;
  final String? repo;
  final String? branch;

  const AppMarkdown({
    super.key,
    required this.data,
    this.owner,
    this.repo,
    this.branch,
  });

  /// Gitee README 和正文可能包含 HTML，先转成 Markdown 友好的形式再交给渲染器。
  static String normalize(
    String source, {
    String? owner,
    String? repo,
    String? branch,
  }) {
    var value = source.replaceAll('\r\n', '\n');
    final codeBlocks = <String>[];
    final inlineCodes = <String>[];
    value = value.replaceAllMapped(
      RegExp(r'\x60{3}[\s\S]*?\x60{3}'),
      (match) {
        codeBlocks.add(match.group(0)!);
        return '\u0000CODE${codeBlocks.length - 1}\u0000';
      },
    );
    value = value.replaceAllMapped(
      RegExp(r'`[^`\n]+`'),
      (match) {
        inlineCodes.add(match.group(0)!);
        return '\u0000INLINE${inlineCodes.length - 1}\u0000';
      },
    );
    value = value.replaceAllMapped(
      RegExp(r'<img\b[^>]*>', caseSensitive: false),
      (match) {
        final tag = match.group(0)!;
        final src =
            RegExp(r'''src\s*=\s*["']([^"']+)["']''', caseSensitive: false)
                .firstMatch(tag)
                ?.group(1);
        if (src == null || src.isEmpty) return '';
        final resolved = _resolveRepoUrl(src, owner, repo, branch);
        final alt =
            RegExp(r'''alt\s*=\s*["']([^"']*)["']''', caseSensitive: false)
                .firstMatch(tag)
                ?.group(1)
                ?.trim();
        return '![${alt?.isNotEmpty == true ? alt! : '图片'}]($resolved)';
      },
    );
    value = value.replaceAllMapped(
      RegExp(
        r'''<a\b[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)</a>''',
        caseSensitive: false,
      ),
      (match) =>
          '[${_stripTags(match.group(2)!)}](${_resolveRepoUrl(match.group(1)!, owner, repo, branch)})',
    );
    value = value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<p\b[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<div\b[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<hr\s*/?>', caseSensitive: false), '\n---\n')
        .replaceAll(RegExp(r'<li\b[^>]*>', caseSensitive: false), '- ')
        .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n');
    value = value.replaceAllMapped(
      RegExp(r'''\[([^\]]+)\]\(([^\s)]+)(?:\s+["'][^"']*["'])?\)'''),
      (match) {
        final label = match.group(1) ?? '';
        final url = _resolveRepoUrl(match.group(2) ?? '', owner, repo, branch);
        return '[$label]($url)';
      },
    );
    value = value.replaceAllMapped(
      RegExp(r'''!\[([^\]]*)\]\(([^\s)]+)(?:\s+["'][^"']*["'])?\)'''),
      (match) {
        final alt = match.group(1) ?? '';
        final url = _resolveRepoUrl(match.group(2) ?? '', owner, repo, branch);
        return '![$alt]($url)';
      },
    );
    value = _stripTags(value)
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    for (var i = 0; i < codeBlocks.length; i++) {
      value = value.replaceAll(
        '\u0000CODE$i\u0000',
        codeBlocks[i],
      );
    }
    for (var i = 0; i < inlineCodes.length; i++) {
      value = value.replaceAll(
        '\u0000INLINE$i\u0000',
        inlineCodes[i],
      );
    }
    return value;
  }

  static String _stripTags(String value) =>
      value.replaceAll(RegExp(r'<[^>]+>'), '');

  /// 将 README 中的相对链接/图片解析为基于仓库的完整 URL。
  static String _resolveRepoUrl(
    String raw,
    String? owner,
    String? repo,
    String? branch,
  ) {
    if (owner == null || owner.isEmpty || repo == null || repo.isEmpty) {
      return raw;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.hasScheme || raw.startsWith('//')) return raw;
    final ref = raw.split('#');
    final target = ref.first;
    final fragment = ref.length > 1 ? '#${ref.sublist(1).join('#')}' : '';
    final clean = target.replaceFirst(RegExp(r'^/+'), '');
    if (clean.isEmpty) return raw;
    final baseParts = [
      'https://gitee.com',
      owner,
      repo,
      if (branch != null && branch.isNotEmpty) 'raw',
      branch ?? 'master',
    ];
    final stack = List<String>.from(baseParts);
    for (final part in clean.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (stack.length > 4) stack.removeLast();
        continue;
      }
      stack.add(Uri.encodeComponent(part));
    }
    return stack.join('/') + fragment;
  }

  Future<void> _openLink(BuildContext context, String? href) async {
    if (href == null || href.isEmpty) return;
    await launchExternalUrl(href);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // markdown_widget 默认适配深浅色，这里仅叠加链接点击行为。
    final config = (dark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig)
        .copy(configs: [
      LinkConfig(
        onTap: (url) => _openLink(context, url),
      ),
    ]);
    final source = data.trim().isEmpty
        ? '暂无内容'
        : normalize(data, owner: owner, repo: repo, branch: branch);
    // MarkdownWidget 自带滚动视图，嵌入详情页 ListView 时收缩并禁用自身滚动。
    return MarkdownWidget(
      data: source,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      config: config,
    );
  }
}
