import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/gitee_api_entities.dart';
import '../models/issue.dart' show Label;
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
  List<Label> _labels = [];
  String? _labelsError;
  List<Milestone> _milestones = [];
  String? _milestonesError;
  List<DeployKey> _deployKeys = [];
  String? _deployKeysError;

  @override
  void initState() {
    super.initState();
    _load();
    _loadExtras();
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
      _loadExtras();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// 标签 / 里程碑 / 部署公钥各自独立加载，
  /// 某一项失败（如无权限）不影响其它区块。
  Future<void> _loadExtras() async {
    Future<void> safe(Future<void> Function() job,
        void Function(Object) onError) async {
      try {
        await job();
      } catch (e) {
        onError(e);
      }
    }

    await safe(() async {
      final labels = await GiteeApi.getRepoLabels(widget.owner, widget.repo);
      if (mounted) setState(() => _labels = labels);
    }, (e) {
      if (mounted) setState(() => _labelsError = e.toString());
    });
    await safe(() async {
      final milestones = await GiteeApi.getMilestones(
        widget.owner,
        widget.repo,
        state: 'all',
      );
      if (mounted) setState(() => _milestones = milestones);
    }, (e) {
      if (mounted) setState(() => _milestonesError = e.toString());
    });
    await safe(() async {
      final keys = await GiteeApi.getDeployKeys(widget.owner, widget.repo);
      if (mounted) setState(() => _deployKeys = keys);
    }, (e) {
      if (mounted) setState(() => _deployKeysError = e.toString());
    });
  }

  /// 语言统计行；v5 现返回 {languages: [{language, percent, bytes}]} 包装结构，
  /// 兼容旧的 {语言: 字节数} 平铺结构。
  List<(String, String)> get _languageRows {
    final rows = <(String, String)>[];
    final raw = _languages['languages'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final name = item['language']?.toString() ?? '';
          if (name.isEmpty) continue;
          final percent = item['percent']?.toString() ?? '';
          rows.add((name, percent.isEmpty ? '' : '$percent%'));
        }
      }
      return rows;
    }
    for (final entry in _languages.entries) {
      rows.add((entry.key, entry.value.toString()));
    }
    return rows;
  }

  Future<void> _createLabel() async {
    final values = await _formDialog(
      title: '创建标签',
      fields: const [
        ('name', '标签名称', '例如 bug'),
        ('color', '颜色（十六进制）', '例如 FBCA04'),
      ],
    );
    if (values == null || values['name']!.isEmpty) return;
    try {
      await GiteeApi.createRepoLabel(
        owner: widget.owner,
        repo: widget.repo,
        name: values['name']!,
        color: values['color']!.isEmpty ? 'C71D23' : values['color']!,
      );
      await _loadExtras();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteLabel(Label label) async {
    try {
      await GiteeApi.deleteRepoLabel(widget.owner, widget.repo, label.id);
      await _loadExtras();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _createMilestone() async {
    final values = await _formDialog(
      title: '创建里程碑',
      fields: const [
        ('title', '里程碑标题', '例如 v2.1 发布'),
        ('description', '描述', '可选'),
        ('due_on', '截止日期', 'YYYY-MM-DD，可选'),
      ],
    );
    if (values == null || values['title']!.isEmpty) return;
    try {
      await GiteeApi.createMilestone(
        owner: widget.owner,
        repo: widget.repo,
        title: values['title']!,
        description: values['description'],
        dueOn: values['due_on'],
      );
      await _loadExtras();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _toggleMilestone(Milestone milestone) async {
    try {
      await GiteeApi.updateMilestone(
        owner: widget.owner,
        repo: widget.repo,
        id: milestone.id,
        state: milestone.state == 'open' ? 'closed' : 'open',
      );
      await _loadExtras();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteMilestone(Milestone milestone) async {
    try {
      await GiteeApi.deleteMilestone(widget.owner, widget.repo, milestone.id);
      await _loadExtras();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _addDeployKey() async {
    final values = await _formDialog(
      title: '添加部署公钥',
      fields: const [
        ('title', '公钥名称', '例如 deploy-server'),
        ('key', '公钥内容', 'ssh-rsa AAAA...'),
      ],
    );
    if (values == null || values['key']!.isEmpty) return;
    try {
      await GiteeApi.createDeployKey(
        owner: widget.owner,
        repo: widget.repo,
        key: values['key']!,
        title: values['title']!.isEmpty ? 'deploy-key' : values['title']!,
      );
      await _loadExtras();
      _showMessage('部署公钥已添加');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteDeployKey(DeployKey key) async {
    try {
      await GiteeApi.deleteDeployKey(widget.owner, widget.repo, key.id);
      await _loadExtras();
    } catch (e) {
      _showError(e);
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
                  ..._languageRows.map(
                    (row) => _MetricRow(label: row.$1, value: row.$2),
                  ),
                  if (_contributors.isNotEmpty) const Divider(),
                  ..._contributors.take(10).map(
                        (item) => _MetricRow(
                          label: item.name.isEmpty ? item.email : item.name,
                          value: '${item.contributions} 次提交',
                        ),
                      ),
                  if (_languageRows.isEmpty && _contributors.isEmpty)
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
              title: '标签 (${_labels.length})',
              icon: Icons.sell_outlined,
              actions: [
                IconButton(
                  tooltip: '创建标签',
                  onPressed: _createLabel,
                  icon: const Icon(Icons.add),
                ),
              ],
              child: _labelsError != null
                  ? const _InlineEmpty(text: '加载失败：需要仓库管理权限')
                  : _labels.isEmpty
                      ? const _InlineEmpty(text: '暂无标签')
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _labels
                              .map(
                                (label) => InputChip(
                                  label: Text(label.name),
                                  backgroundColor: label.color.isEmpty
                                      ? null
                                      : Color(int.parse('FF${label.color}',
                                              radix: 16)),
                                  labelStyle: TextStyle(
                                    color: label.color.isEmpty
                                        ? null
                                        : Colors.white,
                                  ),
                                  onDeleted: () => _deleteLabel(label),
                                  deleteIconColor: Colors.white70,
                                ),
                              )
                              .toList(),
                        ),
            ),
            _section(
              title: '里程碑 (${_milestones.length})',
              icon: Icons.flag_outlined,
              actions: [
                IconButton(
                  tooltip: '创建里程碑',
                  onPressed: _createMilestone,
                  icon: const Icon(Icons.add),
                ),
              ],
              child: _milestonesError != null
                  ? _InlineEmpty(text: '加载失败：$_milestonesError')
                  : _milestones.isEmpty
                      ? const _InlineEmpty(text: '暂无里程碑')
                      : Column(
                          children: _milestones
                              .map(
                                (milestone) => ListTile(
                                  dense: true,
                                  leading: Icon(
                                    milestone.state == 'open'
                                        ? Icons.flag_outlined
                                        : Icons.flag,
                                    color: milestone.state == 'open'
                                        ? AppColors.success
                                        : AppColors.textTertiary,
                                  ),
                                  title: Text(milestone.title),
                                  subtitle: Text(
                                    milestone.state == 'open'
                                        ? '进行中 · ${milestone.openIssues} 开 / ${milestone.closedIssues} 闭'
                                        : '已关闭',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: milestone.state == 'open'
                                            ? '关闭里程碑'
                                            : '重新开启',
                                        onPressed: () =>
                                            _toggleMilestone(milestone),
                                        icon: Icon(
                                          milestone.state == 'open'
                                              ? Icons.close
                                              : Icons.replay,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: '删除',
                                        onPressed: () =>
                                            _deleteMilestone(milestone),
                                        icon: const Icon(
                                            Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
            ),
            _section(
              title: '部署公钥 (${_deployKeys.length})',
              icon: Icons.vpn_key_outlined,
              actions: [
                IconButton(
                  tooltip: '添加部署公钥',
                  onPressed: _addDeployKey,
                  icon: const Icon(Icons.add),
                ),
              ],
              child: _deployKeysError != null
                  ? const _InlineEmpty(text: '加载失败：需要仓库管理权限')
                  : _deployKeys.isEmpty
                      ? const _InlineEmpty(text: '暂无部署公钥')
                      : Column(
                          children: _deployKeys
                              .map(
                                (key) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.vpn_key_outlined),
                                  title: Text(key.title),
                                  subtitle: Text(
                                    key.key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    tooltip: '删除',
                                    onPressed: () => _deleteDeployKey(key),
                                    icon:
                                        const Icon(Icons.delete_outline),
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
