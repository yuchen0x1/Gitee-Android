import 'package:flutter/material.dart';
import '../utils/error_message.dart';
import '../api/gitee_api.dart';
import '../models/gitee_api_entities.dart';
import '../models/repo.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_views.dart';
import 'repo_detail_page.dart';

/// 当前用户所属组织及组织管理入口。
class OrganizationsPage extends StatefulWidget {
  const OrganizationsPage({super.key});

  @override
  State<OrganizationsPage> createState() => _OrganizationsPageState();
}

class _OrganizationsPageState extends State<OrganizationsPage> {
  List<Organization> _items = [];
  bool _loading = true;
  String? _error;

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
      final items = await GiteeApi.getCurrentUserOrgs(perPage: 100);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的组织'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), tooltip: '刷新', onPressed: _load),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) return const SkeletonList(variant: SkeletonVariant.userTile);
    if (_error != null && _items.isEmpty) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.business_outlined,
        title: '暂无组织',
        subtitle: '加入或创建组织后，会在这里显示组织仓库和成员。',
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, index) {
          final org = _items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: AppAvatar(url: org.avatarUrl, size: 48, radius: 12),
              title:
                  Text(org.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '@${org.login}\n${org.description.isEmpty ? '暂无描述' : org.description}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              trailing: Icon(Icons.chevron_right,
                  color: context.mutedForeground),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => OrganizationDetailPage(org: org)),
                );
                if (mounted) _load();
              },
            ),
          );
        },
      ),
    );
  }
}

class OrganizationDetailPage extends StatefulWidget {
  final Organization org;

  const OrganizationDetailPage({super.key, required this.org});

  @override
  State<OrganizationDetailPage> createState() => _OrganizationDetailPageState();
}

class _OrganizationDetailPageState extends State<OrganizationDetailPage> {
  late Future<Organization> _detail;
  late Future<List<dynamic>> _content;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _detail = GiteeApi.getOrgDetail(widget.org.login);
    _content = Future.wait([
      GiteeApi.getOrgRepos(widget.org.login, perPage: 100),
      GiteeApi.getOrgMembers(widget.org.login, perPage: 100),
    ]);
  }

  Future<void> _createRepo() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _OrgRepoDialog(),
    );
    if (result == null) return;
    try {
      await GiteeApi.createOrgRepo(
        org: widget.org.login,
        name: result['name']!,
        description: result['description'],
        autoInit: true,
      );
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('组织仓库已创建')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('@${widget.org.login}')),
      body: FutureBuilder<Organization>(
        future: _detail,
        builder: (context, detailSnapshot) {
          if (detailSnapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonList(itemCount: 5);
          }
          final org = detailSnapshot.data ?? widget.org;
          return FutureBuilder<List<dynamic>>(
            future: _content,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SkeletonList(itemCount: 5);
              }
              if (snapshot.hasError) {
                return ErrorState(
                    message: snapshot.error.toString(),
                    onRetry: () => setState(_reload));
              }
              final repos = (snapshot.data?[0] as List?)?.cast<dynamic>() ?? [];
              final members =
                  (snapshot.data?[1] as List?)?.cast<dynamic>() ?? [];
              return RefreshIndicator(
                onRefresh: () async => setState(_reload),
                color: AppColors.primaryRed,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _OrgHeader(org: org),
                    const SizedBox(height: 16),
                    Text('组织仓库 (${repos.length})',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (repos.isEmpty) const Text('暂无组织仓库'),
                    ...repos
                        .cast<Repo>()
                        .map((repo) => _OrgRepoTile(repo: repo)),
                    const SizedBox(height: 20),
                    Text('组织成员 (${members.length})',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (members.isEmpty) const Text('暂无成员信息'),
                    ...members.map((member) => _OrgMemberTile(user: member)),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '创建组织仓库',
        onPressed: _createRepo,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _OrgHeader extends StatelessWidget {
  final Organization org;
  const _OrgHeader({required this.org});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(url: org.avatarUrl, size: 56, radius: 14),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(org.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('@${org.login}',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (org.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(org.description),
                  ],
                ])),
          ],
        ),
      ),
    );
  }
}

class _OrgRepoTile extends StatelessWidget {
  final Repo repo;
  const _OrgRepoTile({required this.repo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.folder_outlined, color: AppColors.primaryRed),
        title: Text(repo.fullName),
        subtitle: Text(repo.description,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RepoDetailPage(
              owner: repo.ownerLogin,
              repo: repo.name,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrgMemberTile extends StatelessWidget {
  final dynamic user;
  const _OrgMemberTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: AppAvatar(
            url: user.avatarUrl?.toString() ?? '', size: 40, radius: 10),
        title: Text(user.name?.toString() ?? user.login?.toString() ?? ''),
        subtitle: Text('@${user.login?.toString() ?? ''}'),
      ),
    );
  }
}

class _OrgRepoDialog extends StatefulWidget {
  const _OrgRepoDialog();

  @override
  State<_OrgRepoDialog> createState() => _OrgRepoDialogState();
}

class _OrgRepoDialogState extends State<_OrgRepoDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建组织仓库'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '仓库名称')),
        TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: '描述')),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'name': _name.text.trim(),
              'description': _description.text.trim()
            });
          },
          child: const Text('创建'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }
}
