import 'package:flutter/material.dart';
import '../auth/auth_store.dart';
import '../api/gitee_api.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_surface.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _tokenCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _loginWithToken() async {
    if (_loading) return;
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      _showMsg('请输入私人令牌');
      return;
    }
    setState(() => _loading = true);
    GiteeApi.setToken(token);
    try {
      final user = await GiteeApi.getCurrentUser();
      await AuthStore.writeToken(token);
      await AuthStore.addAccount(
        username: user.login,
        token: token,
        avatarUrl: user.avatarUrl,
      );
      if (!mounted) return;
      _showMsg('登录成功：${user.name}');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      GiteeApi.clearToken();
      if (mounted) _showMsg(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primaryRed;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryLight, AppColors.primaryRed],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withValues(alpha: 0.35),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.cloud_outlined, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                '欢迎回来',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '使用 Gitee 私人令牌登录',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 30),
              GlassSurface(
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _tokenCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _loginWithToken(),
                      decoration: InputDecoration(
                        labelText: '私人令牌 (Private Token)',
                        hintText: '从 Gitee 设置-私人令牌中获取',
                        prefixIcon: const Icon(Icons.vpn_key_rounded,
                            color: AppColors.primaryRed),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _loginWithToken,
                        icon: _loading
                            ? _progress()
                            : const Icon(Icons.login_rounded, size: 20),
                        label: const Text('使用令牌登录',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassSurface(
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.key_rounded, size: 18, color: accent),
                        const SizedBox(width: 8),
                        Text('如何获取令牌？',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _step(1, '电脑访问 gitee.com 并登录', theme),
                    _step(2, '右上角头像 → 设置', theme),
                    _step(3, '安全设置 → 私人令牌', theme),
                    _step(4, '生成令牌并授予所需权限', theme),
                    _step(5, '复制令牌粘贴到上方输入框', theme),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Gitee Client · 非官方开源客户端',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(int index, String text, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primaryRed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: accent),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _progress() {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
    );
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }
}
