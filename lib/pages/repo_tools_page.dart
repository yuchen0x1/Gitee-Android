import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/gitee_api_entities.dart';
import '../models/repo.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import '../widgets/state_views.dart';

/// 仓库能力中心：把已封装的管理类官方 API 暴露为可操作页面。
class RepoToolsPage extends StatefulWidget {
  final String owner;
  final String repo;
  final String defaultBranch;

  const RepoToolsPage({
    super.key,
    required this.owner,
    required this.repo,
    this.defaultBranch = 'master',
  });

  @override
  State<RepoToolsPage> createState() => _RepoToolsPageState();
}

class _RepoToolsPageState extends State<RepoToolsPage> {
  bool _loading = true;
  String? _error;
  List<RepositoryBranch> _branches = [];
  List<RepositoryTag> _tags = [];
  List<Repo> _forks = [];
  List<Contributor> _contributors = [];
  List<Webhook> _webhooks = [];
  List<User> _collaborators = [];
  Map<String, dynamic> _languages = {};
  Map<String, dynamic> _license = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        GiteeApi.getBranchDetails(widget.owner, widget.repo, perPage: 100),
        GiteeApi.getTags(widget.owner, widget.repo, perPage: 100),
        GiteeApi.getForks(widget.owner, widget.repo, perPage: 20),
        GiteeApi.getContributors(widget.owner, widget.repo),
        GiteeApi.getWebhooks(widget.owner, widget.repo),
        GiteeApi.getCollaborators(widget.owner, widget.repo),
        GiteeApi.getLanguages(widget.owner, widget.repo),
        GiteeApi.getRepoLicense(widget.owner, widget.repo),
      ]);
      if (!mounted) return;
      setState(() {
        _branches = results[0] as List<RepositoryBranch>;
        _tags = results[1] as List<RepositoryTag>;
        _forks = results[2] as List<Repo>;
        _contributors = results[3] as List<Contributor>;
        _webhooks = results[4] as List<Webhook>;
        _collaborators = results[5] as List<User>;
        _languages = results[6] as Map<String, dynamic>;
        _license = results[7] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _createTag() async {
    final values = await _formDialog(
      title: '创建标签',
      fields: const [
        ('tag', '标签名称', '例如 v1.0.0'),
        ('ref', '目标分支或提交', '默认分支'),
        ('message', '标签说明', '可选'),
      ],
    );
    if (values == null || values['tag']!.isEmpty) return;
    try {
      await GiteeApi.createTag(
        owner: widget.owner,
        repo: widget.repo,
        tagName: values['tag']!,
        refs: values['ref']!.isEmpty ? widget.defaultBranch : values['ref']!,
        tagMessage: values['message'],
      );
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _forkRepo() async {
    final values = await _formDialog(
      title: 'Fork 仓库',
      fields: const [('name', '新仓库名称', '可选'), ('organization', '组织名', '可选')],
    );
    if (values == null) return;
    try {
      await GiteeApi.forkRepo(
        owner: widget.owner,
        repo: widget.repo,
        name: values['name'],
        organization: values['organization'],
      );
      if (mounted) _showMessage('Fork 请求已提交');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _addCollaborator() async {
    final values = await _formDialog(
      title: '添加协作者',
      fields: const [
        ('username', '用户账号', '例如 octocat'),
        ('permission', '权限', 'pull / push / admin'),
      ],
    );
    if (values == null || values['username']!.isEmpty) return;
    try {
      await GiteeApi.addCollaborator(
        owner: widget.owner,
        repo: widget.repo,
        username: values['username']!,
        permission:
            values['permission']!.isEmpty ? 'push' : values['permission']!,
      );
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _createWebhook() async {
    final values = await _formDialog(
      title: '创建 Webhook',
      fields: const [
        ('url', '回调地址', 'https://example.com/webhook'),
        ('title', '名称', '可选'),
      ],
    );
    if (values == null || values['url']!.isEmpty) return;
    try {
      await GiteeApi.createWebhook(
        owner: widget.owner,
        repo: widget.repo,
        url: values['url']!,
        title: values['title'],
        issuesEvents: true,
        mergeRequestsEvents: true,
        tagPushEvents: true,
      );
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _toggleProtection(RepositoryBranch branch) async {
    try {
      if (branch.protected) {
        await GiteeApi.removeBranchProtection(
          widget.owner,
          widget.repo,
          branch.name,
        );
      } else {
        await GiteeApi.setBranchProtection(
          owner: widget.owner,
          repo: widget.repo,
          branch: branch.name,
        );
      }
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteWebhook(Webhook hook) async {
    try {
      await GiteeApi.deleteWebhook(widget.owner, widget.repo, hook.id);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _testWebhook(Webhook hook) async {
    try {
      await GiteeApi.testWebhook(widget.owner, widget.repo, hook.id);
      if (mounted) _showMessage('Webhook 测试请求已发送');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _removeCollaborator(User user) async {
    try {
      await GiteeApi.removeCollaborator(widget.owner, widget.repo, user.login);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<Map<String, String>?> _formDialog({
    required String title,
    required List<(String, String, String)> fields,
  }) async {
    final controllers = {
      for (final field in fields) field.$1: TextEditingController(),
    };
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[field.$1],
                    decoration: InputDecoration(
                      labelText: field.$2,
                      hintText: field.$3,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              for (final field in fields)
                field.$1: controllers[field.$1]!.text.trim(),
            }),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) {
    if (mounted) _showMessage(error.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('仓库能力中心')),
        body: ErrorState(message: _error!, onRetry: _load),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('仓库能力中心'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              title: '分支与标签',
              icon: Icons.alt_route,
              actions: [
                IconButton(
                  tooltip: '创建标签',
                  onPressed: _createTag,
                  icon: const Icon(Icons.add),
                ),
              ],
              child: Column(
                children: [
                  ..._branches.map(
                    (branch) => ListTile(
                      dense: true,
                      leading: Icon(
                        branch.protected
                            ? Icons.lock_outline
                            : Icons.account_tree_outlined,
                        color: branch.protected
                            ? AppColors.success
                            : AppColors.textTertiary,
                      ),
                      title: Text(branch.name),
                      subtitle: Text(
                        branch.sha.isEmpty
                            ? '无提交信息'
                            : branch.sha.substring(
                                0,
                                branch.sha.length.clamp(0, 10),
                              ),
                      ),
                      trailing: IconButton(
                        tooltip: branch.protected ? '取消保护' : '设置保护',
                        onPressed: () => _toggleProtection(branch),
                        icon: Icon(
                          branch.protected
                              ? Icons.lock_open_outlined
                              : Icons.lock_outline,
                        ),
                      ),
                    ),
                  ),
                  if (_tags.isNotEmpty) const Divider(),
                  ..._tags.map(
                    (tag) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.sell_outlined),
                      title: Text(tag.name),
                      subtitle: Text(tag.sha.isEmpty ? '标签' : tag.sha),
                    ),
                  ),
                  if (_branches.isEmpty && _tags.isEmpty)
                    const _InlineEmpty(text: '暂无分支或标签'),
                ],
              ),
            ),
            _section(
              title: '代码统计',
              icon: Icons.insights_outlined,
              child: Column(
                children: [
                  if (_languages.isNotEmpty)
                    ..._languages.entries.map(
                      (entry) => _MetricRow(
                        label: entry.key,
                        value: entry.value.toString(),
                      ),
                    ),
                  if (_contributors.isNotEmpty) const Divider(),
                  ..._contributors.take(10).map(
                        (item) => _MetricRow(
                          label: item.name.isEmpty ? item.email : item.name,
                          value: '${item.contributions} 次提交',
                        ),
                      ),
                  if (_languages.isEmpty && _contributors.isEmpty)
                    const _InlineEmpty(text: '暂无统计数据'),
                ],
              ),
            ),
            _section(
              title: '许可证',
              icon: Icons.gavel_outlined,
              child: _license.isEmpty
                  ? const _InlineEmpty(text: '暂无许可证信息')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_license['license'] ??
                                  _license['name'] ??
                                  _license['spdx_id'] ??
                                  '已配置许可证')
                              .toString(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_license['html_url'] != null)
                          Text(_license['html_url'].toString()),
                      ],
                    ),
            ),
            _section(
              title: 'Fork (${_forks.length})',
              icon: Icons.call_split,
              actions: [
                IconButton(
                  tooltip: 'Fork',
                  onPressed: _forkRepo,
                  icon: const Icon(Icons.add),
                ),
              ],
              child: _forks.isEmpty
                  ? const _InlineEmpty(text: '暂无 Fork')
                  : Column(
                      children: _forks
                          .take(10)
                          .map(
                            (repo) => ListTile(
                              dense: true,
                              leading: AppAvatar(
                                url: repo.ownerAvatar,
                                size: 32,
                                radius: 8,
                              ),
                              title: Text(repo.fullName),
                              subtitle: Text(
                                repo.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            _section(
              title: '协作者 (${_collaborators.length})',
              icon: Icons.group_outlined,
              actions: [
                IconButton(
                  tooltip: '添加协作者',
                  onPressed: _addCollaborator,
                  icon: const Icon(Icons.person_add_alt_1),
                ),
              ],
              child: _collaborators.isEmpty
                  ? const _InlineEmpty(text: '暂无协作者')
                  : Column(
                      children: _collaborators
                          .map(
                            (user) => ListTile(
                              dense: true,
                              leading: AppAvatar(
                                url: user.avatarUrl,
                                size: 32,
                                radius: 8,
                              ),
                              title: Text(user.login),
                              trailing: IconButton(
                                tooltip: '移除',
                                onPressed: () => _removeCollaborator(user),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            _section(
              title: 'Webhook (${_webhooks.length})',
              icon: Icons.webhook_outlined,
              actions: [
                IconButton(
                  tooltip: '创建 Webhook',
                  onPressed: _createWebhook,
                  icon: const Icon(Icons.add),
                ),
              ],
              child: _webhooks.isEmpty
                  ? const _InlineEmpty(text: '暂无 Webhook')
                  : Column(
                      children: _webhooks
                          .map(
                            (hook) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.webhook),
                              title: Text(
                                hook.title.isEmpty ? hook.url : hook.title,
                              ),
                              subtitle: Text(
                                hook.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'test') _testWebhook(hook);
                                  if (value == 'delete') {
                                    _deleteWebhook(hook);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'test',
                                    child: Text('测试'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('删除'),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
    List<Widget> actions = const [],
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: AppColors.primaryRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...actions,
              ],
            ),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final String text;

  const _InlineEmpty({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}
