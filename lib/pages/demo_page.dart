import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 关于 / 使用指南页。
class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('使用指南')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gitee Client', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('A Flutter client for Gitee.',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Text('版本 1.0.0+1', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _Section(
            title: '快速开始',
            children: [
              _Step(
                  number: '1',
                  text:
                      '在 Gitee 设置中生成私人令牌，勾选 projects、pull_requests、issues、user_info 权限。'),
              _Step(number: '2', text: '打开应用，在登录页粘贴令牌。'),
              _Step(number: '3', text: '浏览仓库、搜索、查看 Issue 和 PR。'),
            ],
          ),
          const SizedBox(height: 16),
          const _Section(
            title: '核心功能',
            children: [
              _Feature(
                  icon: Icons.dynamic_feed,
                  title: '动态中心',
                  desc: '查看通知、仓库动态，支持按仓库分组和全部已读。'),
              _Feature(
                  icon: Icons.folder,
                  title: '仓库管理',
                  desc: '浏览仓库、Star、订阅，查看 README 和文件。'),
              _Feature(
                  icon: Icons.search,
                  title: '全局搜索',
                  desc: '搜索仓库、用户、Issue，支持多维度筛选。'),
              _Feature(
                  icon: Icons.bug_report,
                  title: 'Issue 管理',
                  desc: '查看和创建 Issue，支持按状态筛选。'),
              _Feature(
                  icon: Icons.merge_type,
                  title: 'Pull Request',
                  desc: '查看和创建 PR，支持源分支和目标分支。'),
              _Feature(
                  icon: Icons.notifications_active,
                  title: '订阅仓库',
                  desc: '订阅仓库后可在动态中查看更新。'),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '注意事项',
            children: [
              Text('• 图片文件直接通过 raw URL 渲染，Gitee 可能有防盗链，部分图片可能无法显示。',
                  style: theme.textTheme.bodySmall),
              Text('• API 有访问频率限制，建议不要频繁刷新。', style: theme.textTheme.bodySmall),
              Text('• 代码高亮使用简单文本渲染，未接入语法高亮库。',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ...children,
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;
  const _Step({required this.number, required this.text});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _Feature({required this.icon, required this.title, required this.desc});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryRed),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium),
                Text(desc, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
