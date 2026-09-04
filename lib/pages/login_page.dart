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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              GlassSurface(
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(16),
                tint: AppColors.primaryRed.withValues(alpha: 0.92),
                child: const Icon(Icons.cloud_outlined,
                    color: Colors.white, size: 34),
              ),
              const SizedBox(height: 20),
              Text('欢迎回来',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                '使用 Gitee 私人令牌登录',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _tokenCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _loginWithToken(),
                decoration: InputDecoration(
                  labelText: '私人令牌 (Private Token)',
                  hintText: '从 Gitee 设置-私人令牌中获取',
                  prefixIcon:
                      const Icon(Icons.vpn_key, color: AppColors.primaryRed),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _loginWithToken,
                  child: _loading ? _progress() : const Text('使用令牌登录'),
                ),
              ),
              const SizedBox(height: 18),
              GlassSurface(
                padding: const EdgeInsets.all(18),
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '如何获取令牌？',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      _tip('1. 电脑访问 gitee.com 并登录'),
                      _tip('2. 右上角头像 → 设置'),
                      _tip('3. 安全设置 → 私人令牌'),
                      _tip('4. 生成令牌并授予所需权限'),
                      _tip('5. 复制令牌粘贴到上方输入框'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress() {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }
}
