import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// 生物识别锁：App 切回前台时要求指纹/面容解锁。
class AppLock {
  AppLock._();

  static const _key = 'app_lock_enabled';
  static final LocalAuthentication _auth = LocalAuthentication();
  static bool _enabled = false;
  static bool _unlocked = true;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? false;
    _unlocked = !_enabled;
  }

  static bool get enabled => _enabled;
  static bool get unlocked => _unlocked;

  /// 应用切入后台时重置解锁状态
  static void markLocked() {
    if (_enabled) {
      _unlocked = false;
    }
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    _unlocked = !value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  static Future<bool> get canUseBiometrics async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> unlock() async {
    try {
      _unlocked = await _auth.authenticate(
        localizedReason: '请验证身份以继续使用 Gitee Client',
      );
    } catch (_) {
      _unlocked = false;
    }
    return _unlocked;
  }
}

/// 锁屏遮罩：覆盖在 App 之上，要求生物识别解锁。
class AppLockScreen extends StatelessWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryDark,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fingerprint, size: 72, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                '已开启生物识别锁',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                '验证身份后继续使用',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryRed,
                ),
                icon: const Icon(Icons.lock_open),
                label: const Text('立即解锁'),
                onPressed: () async {
                  if (await AppLock.unlock()) onUnlocked();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
