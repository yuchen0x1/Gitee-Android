import 'package:flutter/material.dart';
import '../utils/error_message.dart';
import '../api/gitee_api.dart';
import '../models/namespace.dart';
import '../theme/app_theme.dart';

/// 创建个人仓库，直接调用 Gitee POST /user/repos。
/// 归属空间 / License / .gitignore 模板来自官方模板接口，加载失败时不阻塞表单。
class CreateRepoPage extends StatefulWidget {
  const CreateRepoPage({super.key});

  @override
  State<CreateRepoPage> createState() => _CreateRepoPageState();
}

class _CreateRepoPageState extends State<CreateRepoPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _private = false;
  bool _autoInit = true;
  bool _hasIssues = true;
  bool _hasWiki = true;
  bool _loading = false;
  String? _error;

  List<Namespace> _namespaces = [];
  List<String> _licenses = [];
  List<String> _gitignores = [];
  Namespace? _selectedNamespace;
  String? _selectedLicense;
  String? _selectedGitignore;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    // 模板数据属于增强信息，任一失败不影响创建流程。
    try {
      final namespaces = await GiteeApi.getUserNamespaces();
      if (!mounted) return;
      setState(() {
        _namespaces = namespaces;
        if (namespaces.isNotEmpty) _selectedNamespace = namespaces.first;
      });
    } catch (_) {}
    try {
      final licenses = await GiteeApi.getLicenseTemplates();
      if (!mounted) return;
      setState(() => _licenses = licenses);
    } catch (_) {}
    try {
      final gitignores = await GiteeApi.getGitignoreTemplates();
      if (!mounted) return;
      setState(() => _gitignores = gitignores);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建仓库')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '仓库名称',
                hintText: '例如：mobile-client',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入仓库名称' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '仓库描述',
                hintText: '可选',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            if (_namespaces.isNotEmpty) ...[
              const SizedBox(height: 14),
              DropdownMenu<Namespace>(
                initialSelection: _selectedNamespace,
                expandedInsets: EdgeInsets.zero,
                leadingIcon: const Icon(Icons.account_balance_outlined),
                label: const Text('归属空间'),
                dropdownMenuEntries: _namespaces
                    .map(
                      (ns) => DropdownMenuEntry<Namespace>(
                        value: ns,
                        label: ns.isOrganization ? '${ns.name}（组织）' : ns.name,
                      ),
                    )
                    .toList(),
                onSelected: (value) => setState(() => _selectedNamespace = value),
              ),
            ],
            if (_licenses.isNotEmpty) ...[
              const SizedBox(height: 14),
              DropdownMenu<String>(
                enableFilter: true,
                expandedInsets: EdgeInsets.zero,
                leadingIcon: const Icon(Icons.gavel_outlined),
                label: const Text('License 协议（可选）'),
                dropdownMenuEntries: _licenses
                    .map(
                      (license) => DropdownMenuEntry<String>(
                        value: license,
                        label: license,
                      ),
                    )
                    .toList(),
                onSelected: (value) => setState(() => _selectedLicense = value),
              ),
            ],
            if (_gitignores.isNotEmpty) ...[
              const SizedBox(height: 14),
              DropdownMenu<String>(
                enableFilter: true,
                expandedInsets: EdgeInsets.zero,
                leadingIcon: const Icon(Icons.filter_none_outlined),
                label: const Text('.gitignore 模板（可选）'),
                dropdownMenuEntries: _gitignores
                    .map(
                      (template) => DropdownMenuEntry<String>(
                        value: template,
                        label: template,
                      ),
                    )
                    .toList(),
                onSelected: (value) =>
                    setState(() => _selectedGitignore = value),
              ),
            ],
            const SizedBox(height: 18),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.lock_outline),
                    title: const Text('私有仓库'),
                    subtitle: const Text('仅授权用户可见'),
                    value: _private,
                    onChanged: (value) => setState(() => _private = value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.auto_awesome_outlined),
                    title: const Text('初始化 README'),
                    value: _autoInit,
                    onChanged: (value) => setState(() => _autoInit = value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.bug_report_outlined),
                    title: const Text('启用 Issue'),
                    value: _hasIssues,
                    onChanged: (value) => setState(() => _hasIssues = value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.menu_book_outlined),
                    title: const Text('启用 Wiki'),
                    value: _hasWiki,
                    onChanged: (value) => setState(() => _hasWiki = value),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.closed)),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_loading ? '正在创建...' : '创建仓库'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await GiteeApi.createUserRepo(
        name: _name.text.trim(),
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        private: _private,
        autoInit: _autoInit,
        hasIssues: _hasIssues,
        hasWiki: _hasWiki,
        namespace: _selectedNamespace?.path,
        licenseTemplate: _selectedLicense,
        gitignoreTemplate: _selectedGitignore,
      );
      if (mounted) Navigator.of(context).pop(true);
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
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }
}
