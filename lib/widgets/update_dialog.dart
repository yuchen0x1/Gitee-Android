import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/app_update.dart';
import '../theme/app_theme.dart';
import '../utils/launch_url.dart';

Future<void> showAppUpdateDialog(
  BuildContext context,
  AppUpdate update, {
  required String currentVersion,
}) async {
  final asset = update.assetForPlatform(defaultTargetPlatform);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update_alt, color: AppColors.primaryRed),
          const SizedBox(width: 8),
          Expanded(child: Text('发现新版本 ${update.version}')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前版本：$currentVersion'),
            if (update.name.isNotEmpty && update.name != update.version) ...[
              const SizedBox(height: 8),
              Text(update.name, style: Theme.of(context).textTheme.titleMedium),
            ],
            const SizedBox(height: 12),
            Text(
              update.notes.trim().isEmpty ? '此版本包含功能更新和问题修复。' : update.notes,
              maxLines: 12,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('稍后'),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await launchExternalUrl(asset?.url ?? update.htmlUrl);
          },
          icon: const Icon(Icons.download),
          label: Text(asset == null ? '查看发布页' : '下载更新'),
        ),
      ],
    ),
  );
}
