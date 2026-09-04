import 'package:flutter/material.dart';
import '../auth/auth_store.dart';
import '../auth/gitee_oauth.dart';
import '../auth/oauth_token.dart';
import '../api/gitee_api.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_surface.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.oauthCallback});

  final Uri? oauthCallback;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _tokenCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _useToken = false;

  @override
  void initState() {
    super.initState();
    final callback = widget.oauthCallback;
    if (callback != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => completeOAuthCallback(callback));
    }
  }

  Future<void> _loginWithToken() async {
    if (_loading) return;
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      _showMsg('请输入私人令牌');
      return;
    }
    setState(() => _loading = true);
    await _completeWithAccessToken(
      OAuthToken(accessToken: token, tokenType: 'token'),
      isOAuth: false,
    );
  }

  Future<void> _loginWithGitee() async {
    if (_loading) return;
    if (!giteeOAuthService.isConfigured) {
      _showOAuthSetupDialog();
      return;
    }
    setState(() => _loading = true);
    try {
      await giteeOAuthService.beginAuthorization();
      if (mounted) {
        _showMsg('已打开 Gitee 登录页面，完成登录后返回应用');
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) _showMsg(e.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> completeOAuthCallback(Uri uri) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final token = await giteeOAuthService.completeAuthorization(uri);
      await _completeWithAccessToken(token, isOAuth: true);
    } catch (e) {
      if (mounted) _showMsg(e.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeWithAccessToken(
    OAuthToken token, {
    required bool isOAuth,
  }) async {
    GiteeApi.setToken(token.accessToken);
    try {
      final user = await GiteeApi.getCurrentUser();
      if (isOAuth) {
        await AuthStore.writeOAuthToken(token);
      } else {
        await AuthStore.writeToken(token.accessToken);
        await AuthStore.clearOAuthToken();
      }
      await AuthStore.addAccount(
        username: user.login,
        token: token.accessToken,
        avatarUrl: user.avatarUrl,
        oauthToken: isOAuth ? token : null,
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

  void _showOAuthSetupDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('账号登录尚未配置'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '账号密码登录走的是 Gitee 官方授权，'
                '需要先在 Gitee 创建一个 OAuth 应用：',
              ),
              const SizedBox(height: 10),
              _tip('1. 电脑登录 gitee.com'),
              _tip('2. 头像 → 设置 → 安全设置 → OAuth 应用'),
              _tip('3. 创建应用，回调地址填 gitee://oauth/callback'),
              _tip('4. 用拿到的 Client ID / Client Secret 重新构建应用'),
              const SizedBox(height: 10),
              Text(
                '构建示例：\n'
                'flutter build apk --debug \\\n'
                '  --dart-define=GITEE_CLIENT_ID=你的ID \\\n'
                '  --dart-define=GITEE_CLIENT_SECRET=你的密钥',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              setState(() => _useToken = true);
            },
            child: const Text('改用私人令牌登录'),
          ),
        ],
      ),
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
                _useToken ? '使用 Gitee 私人令牌登录' : '使用 Gitee 账号登录',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (_useToken) ...[
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
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _loginWithGitee,
                    icon: const Icon(Icons.open_in_browser),
                    label: _loading ? _progress() : const Text('使用 Gitee 账号登录'),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _useToken = !_useToken),
                  child: Text(_useToken ? '改用 Gitee 账号登录' : '改用私人令牌登录'),
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
                      Text(
                        _useToken ? '如何获取令牌？' : '账号密码在哪里输入？',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      if (_useToken) ...[
                        _tip('1. 电脑访问 gitee.com 并登录'),
                        _tip('2. 右上角头像 → 设置'),
                        _tip('3. 安全设置 → 私人令牌'),
                        _tip('4. 生成令牌并授予所需权限'),
                        _tip('5. 复制令牌粘贴到上方输入框'),
                      ] else ...[
                        _tip('点击上方按钮，在 Gitee 官方页面输入账号和密码'),
                        _tip('密码不会经过本应用，也不会被保存'),
                        _tip('完成授权后返回应用即可登录'),
                      ],
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
