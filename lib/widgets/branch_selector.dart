import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 分支选择器，用于文件浏览与 README 切换。
class BranchSelector extends StatelessWidget {
  final List<String> branches;
  final String branch;
  final ValueChanged<String> onChanged;

  const BranchSelector({
    super.key,
    required this.branches,
    required this.branch,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (branches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.alt_route, size: 18, color: AppColors.primaryRed),
            const SizedBox(width: 8),
            Text(branch.isEmpty ? 'master' : branch,
                style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.alt_route, size: 18, color: AppColors.primaryRed),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: branches.contains(branch) ? branch : branches.first,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down,
                      color: AppColors.textTertiary),
                  items: branches
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null && value != branch) onChanged(value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
