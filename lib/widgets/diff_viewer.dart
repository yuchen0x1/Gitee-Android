import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/code_theme.dart';

/// 单行差异数据模型
class _DiffLine {
  final String text;
  final String type; // 'add', 'delete', 'header', 'normal'
  final int? oldLine;
  final int? newLine;

  _DiffLine({
    required this.text,
    required this.type,
    this.oldLine,
    this.newLine,
  });
}

/// 专业 Git 差异对比组件：支持增减整行背景色渲染、旧/新行号对照以及高阶视觉排版。
class DiffViewer extends StatelessWidget {
  final String patch;
  final String filename;
  final String status;
  final int additions;
  final int deletions;

  const DiffViewer({
    super.key,
    required this.patch,
    required this.filename,
    required this.status,
    required this.additions,
    required this.deletions,
  });

  /// 解析 unified diff 格式
  List<_DiffLine> _parsePatch(String rawPatch) {
    if (rawPatch.trim().isEmpty) return [];
    final lines = rawPatch.split('\n');
    final result = <_DiffLine>[];

    int oldNum = 0;
    int newNum = 0;
    final hunkHeaderRegExp = RegExp(r'^@@\s+-(\d+)(?:,\d+)?\s+\+(\d+)(?:,\d+)?\s+@@');

    for (final line in lines) {
      if (line.startsWith('@@')) {
        final match = hunkHeaderRegExp.firstMatch(line);
        if (match != null) {
          oldNum = int.tryParse(match.group(1) ?? '1') ?? 1;
          newNum = int.tryParse(match.group(2) ?? '1') ?? 1;
        }
        result.add(_DiffLine(text: line, type: 'header'));
      } else if (line.startsWith('+') && !line.startsWith('+++')) {
        result.add(_DiffLine(
          text: line,
          type: 'add',
          oldLine: null,
          newLine: newNum++,
        ));
      } else if (line.startsWith('-') && !line.startsWith('---')) {
        result.add(_DiffLine(
          text: line,
          type: 'delete',
          oldLine: oldNum++,
          newLine: null,
        ));
      } else {
        result.add(_DiffLine(
          text: line,
          type: 'normal',
          oldLine: oldNum++,
          newLine: newNum++,
        ));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final diffLines = _parsePatch(patch);

    final addBg = isDark
        ? const Color(0xFF1B4428).withValues(alpha: 0.6)
        : const Color(0xFFE6FFED);
    final addText = isDark ? const Color(0xFF7EE787) : const Color(0xFF1A7F37);

    final delBg = isDark
        ? const Color(0xFF5A1E24).withValues(alpha: 0.6)
        : const Color(0xFFFFEBE9);
    final delText = isDark ? const Color(0xFFFFA198) : const Color(0xFFCF222E);

    final headerBg = isDark
        ? const Color(0xFF1E2838)
        : const Color(0xFFF1F8FF);
    final headerText = isDark ? const Color(0xFF79C0FF) : const Color(0xFF0969DA);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  filename,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                _DiffTag(
                  label: status,
                  color: isDark ? const Color(0xFF8B949E) : AppColors.closed,
                ),
                _DiffTag(
                  label: '+$additions',
                  color: isDark ? const Color(0xFF3FB950) : AppColors.success,
                  glow: true,
                ),
                _DiffTag(
                  label: '-$deletions',
                  color: isDark ? const Color(0xFFF85149) : AppColors.primaryRed,
                  glow: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: diffLines.isEmpty
              ? Center(
                  child: Text(
                    patch.trim().isEmpty ? '暂无差异数据' : patch,
                    style: TextStyle(color: CodeTheme.textOf(theme.brightness)),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      decoration: BoxDecoration(
                        color: CodeTheme.backgroundOf(theme.brightness),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: diffLines.map((line) {
                          Color? rowBg;
                          Color textCol = CodeTheme.textOf(theme.brightness);

                          if (line.type == 'add') {
                            rowBg = addBg;
                            textCol = addText;
                          } else if (line.type == 'delete') {
                            rowBg = delBg;
                            textCol = delText;
                          } else if (line.type == 'header') {
                            rowBg = headerBg;
                            textCol = headerText;
                          }

                          return Container(
                            color: rowBg,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (line.type == 'header')
                                  Container(
                                    width: 72,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '...',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: headerText,
                                      ),
                                    ),
                                  )
                                else ...[
                                  Container(
                                    width: 36,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Text(
                                      line.oldLine != null ? '${line.oldLine}' : '',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: isDark ? Colors.white30 : Colors.black26,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 36,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Text(
                                      line.newLine != null ? '${line.newLine}' : '',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: isDark ? Colors.white30 : Colors.black26,
                                      ),
                                    ),
                                  ),
                                ],
                                Container(
                                  width: 1,
                                  height: 18,
                                  color: isDark ? Colors.white10 : Colors.black12,
                                ),
                                const SizedBox(width: 8),
                                SelectableText(
                                  line.text,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: textCol,
                                    fontWeight: line.type == 'header'
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(width: 24),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _DiffTag extends StatelessWidget {
  final String label;
  final Color color;
  final bool glow;

  const _DiffTag({required this.label, required this.color, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: glow ? 0.4 : 0.2),
          width: 0.8,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 6,
                )
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
