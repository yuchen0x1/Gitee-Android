import 'dart:io';

import 'package:flutter/services.dart';

/// Starts Android's system package installer for a verified local APK.
/// Android does not allow silent installation for a regular consumer app.
class UpdateInstaller {
  UpdateInstaller._();

  static const _channel = MethodChannel('com.yuchen0x1.giteeclient/update');

  static Future<UpdateInstallResult> installApk(File apk) async {
    if (!Platform.isAndroid) return UpdateInstallResult.failed;
    final result = await _channel.invokeMethod<String>('installApk', apk.path);
    return switch (result) {
      'started' => UpdateInstallResult.started,
      'permission_required' => UpdateInstallResult.permissionRequired,
      _ => UpdateInstallResult.failed,
    };
  }

  static Future<bool> openInstallSettings() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('openInstallSettings') ?? false;
  }
}

enum UpdateInstallResult { started, permissionRequired, failed }
