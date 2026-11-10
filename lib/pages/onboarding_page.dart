import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/app_settings.dart';
import '../theme/app_theme.dart';
import 'login_page.dart';

/// 首启引导页：展示核心功能亮点，最后一页进入登录。
class OnboardingPage extends StatefulWidget {
  final VoidCallback? onFinish;

  const OnboardingPage({super.key, this.onFinish});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardData(
      icon: Icons.dynamic_feed,
      title: '跟进动态',
      subtitle: '通勤路上刷通知、事件流和未读消息，随时掌握仓库动向。',
    ),
    _OnboardData(
      icon: Icons.code,
      title: '读写代码',
      subtitle: '浏览 README、源码与提交记录，语法高亮、离线看图，回 Issue、审 PR。',
    ),
    _OnboardData(
      icon: Icons.shield_outlined,
      title: '安全私密',
      subtitle: '令牌存入系统安全存储，支持多账号切换与生物识别解锁。',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    final settings = AppSettingsScope.of(context);
    settings.markOnboardingSeen();
    HapticFeedback.lightImpact();
    if (widget.onFinish != null) {
      widget.onFinish!();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('跳过'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) =>
                    _OnboardView(data: _pages[index]),
              ),
            ),
            Semantics(
              liveRegion: true,
              label: '引导进度',
              value: '第 ${_page + 1} 页，共 ${_pages.length} 页',
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primaryRed
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _next,
                  icon: Icon(_page == _pages.length - 1
                      ? Icons.login
                      : Icons.arrow_forward),
                  label: Text(
                    _page == _pages.length - 1 ? '前往登录' : '继续',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardData {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _OnboardView extends StatelessWidget {
  final _OnboardData data;

  const _OnboardView({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final iconExtent =
                (constraints.maxHeight * 0.30).clamp(88.0, 124.0).toDouble();
            final gap =
                (constraints.maxHeight * 0.07).clamp(18.0, 28.0).toDouble();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconExtent,
                  height: iconExtent,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    data.icon,
                    size: iconExtent * 0.48,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                SizedBox(height: gap),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Text(
                    data.subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      height: 1.55,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
