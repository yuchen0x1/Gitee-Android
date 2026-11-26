import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_update.dart';
import '../services/update_installer.dart';
import '../services/update_service.dart';
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
    builder: (_) => _UpdateDialog(
      update: update,
      asset: asset,
      currentVersion: currentVersion,
    ),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.update,
    required this.asset,
    required this.currentVersion,
  });

  final AppUpdate update;
  final AppUpdateAsset? asset;
  final String currentVersion;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  String? _error;
  int _received = 0;
  int _total = 0;
  double? _speed;

  Future<void> _downloadAndInstall() async {
    final asset = widget.asset;
    if (asset == null) {
      await launchExternalUrl(widget.update.htmlUrl);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      final file = await UpdateService.shared.downloadApk(
        widget.update,
        asset: asset,
        onProgress: (received, total, speed) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
            _speed = speed;
          });
        },
      );
      if (!mounted) return;
      final installResult = await UpdateInstaller.installApk(file);
      if (installResult == UpdateInstallResult.permissionRequired) {
        if (!mounted) return;
        setState(() {
          _downloading = false;
          _error = 'Android 未允许此应用安装未知来源应用，请打开系统设置后重试。';
        });
        return;
      }
      if (installResult != UpdateInstallResult.started) {
        throw const UpdateDownloadException('系统未能打开 APK 安装器');
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = error.toString();
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final total = _total > 0 ? _total : widget.asset?.size ?? 0;
    final progress = total > 0 ? (_received / total).clamp(0.0, 1.0) : null;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update_alt, color: AppColors.primaryRed),
          const SizedBox(width: 8),
          Expanded(child: Text('发现新版本 ${widget.update.version}')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前版本：${widget.currentVersion}'),
            if (widget.update.publishedAt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('发布时间：${widget.update.publishedAt}'),
            ],
            if (widget.update.name.isNotEmpty &&
                widget.update.name != widget.update.version) ...[
              const SizedBox(height: 8),
              Text(
                widget.update.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              widget.update.notes.trim().isEmpty
                  ? '此版本包含功能更新和问题修复。'
                  : widget.update.notes,
              maxLines: 12,
              overflow: TextOverflow.ellipsis,
            ),
            if (_downloading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text(
                total > 0
                    ? '已下载 ${_formatBytes(_received)} / ${_formatBytes(total)}'
                    : '正在下载…',
              ),
              if (_speed != null) Text('速度 ${_formatBytes(_speed!.round())}/s'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (_error!.contains('未知来源')) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      await UpdateInstaller.openInstallSettings();
                    },
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('打开安装权限设置'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('稍后'),
        ),
        FilledButton.icon(
          onPressed: _downloading ? null : _downloadAndInstall,
          icon: Icon(widget.asset == null ? Icons.open_in_new : Icons.download),
          label: Text(widget.asset == null ? '查看发布页' : '下载并安装'),
        ),
      ],
    );
  }
}
