import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../widgets/paged_list_view.dart';

/// SSH 公钥管理：查看 / 添加 / 删除。
class SshKeysPage extends StatefulWidget {
  const SshKeysPage({super.key});

  @override
  State<SshKeysPage> createState() => _SshKeysPageState();
}

class _SshKeysPageState extends State<SshKeysPage> {
  final GlobalKey<PagedListViewState<PublicKeyListItem>> _listKey =
      GlobalKey<PagedListViewState<PublicKeyListItem>>();

  Future<List<PublicKeyListItem>> _loadPage(int page) async {
    final keys = await GiteeApi.getPublicKeys(page: page);
    return keys
        .map((key) => PublicKeyListItem(key: key.key, title: key.title, id: key.id))
        .toList();
  }

  Future<void> _addKey() async {
    final values = await _formDialog();
    if (values == null || values['key']!.isEmpty) return;
    try {
      await GiteeApi.createPublicKey(
        key: values['key']!,
        title: values['title']!.isEmpty ? 'my-key' : values['title']!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('公钥已添加')));
        _listKey.currentState?.refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<Map<String, String>?> _formDialog() async {
    final titleCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加 SSH 公钥'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    labelText: '名称', hintText: '例如 my-laptop'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: '公钥内容', hintText: 'ssh-ed25519 AAAA...'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'title': titleCtrl.text.trim(),
              'key': keyCtrl.text.trim(),
            }),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    titleCtrl.dispose();
    keyCtrl.dispose();
    return result;
  }

  Future<void> _deleteKey(PublicKeyListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除公钥'),
        content: Text('确定删除「${item.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await GiteeApi.deletePublicKey(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('公钥已删除')));
        _listKey.currentState?.refresh();
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
      appBar: AppBar(
        title: const Text('SSH 公钥'),
        actions: [
          IconButton(tooltip: '添加公钥', icon: const Icon(Icons.add), onPressed: _addKey),
        ],
      ),
      body: PagedListView<PublicKeyListItem>(
        key: _listKey,
        loadPage: _loadPage,
        emptyIcon: Icons.vpn_key_outlined,
        emptyTitle: '还没有 SSH 公钥',
        emptySubtitle: '点右上角添加你的公钥',
        itemBuilder: (context, item) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: Text(item.title),
            subtitle: Text(
              item.key,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteKey(item),
            ),
          ),
        ),
      ),
    );
  }
}

class PublicKeyListItem {
  final int id;
  final String title;
  final String key;

  const PublicKeyListItem({
    required this.id,
    required this.title,
    required this.key,
  });
}
