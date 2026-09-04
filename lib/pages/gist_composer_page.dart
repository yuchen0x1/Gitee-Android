import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/gitee_api_entities.dart';

/// 新建 / 编辑代码片段。[existing] 不为空时进入编辑模式。
class GistComposerPage extends StatefulWidget {
  final Gist? existing;

  const GistComposerPage({super.key, this.existing});

  @override
  State<GistComposerPage> createState() => _GistComposerPageState();
}

class _GistComposerPageState extends State<GistComposerPage> {
  final _descriptionCtrl = TextEditingController();
  final _filenameCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPublic = true;
  bool _submitting = false;
  String? _editingFile; // 编辑模式下正在修改的文件名，null 表示新增文件

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _descriptionCtrl.text = existing.description;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await GiteeApi.createGist(
          files: {_filenameCtrl.text.trim(): _contentCtrl.text},
          description: _descriptionCtrl.text.trim(),
          isPublic: _isPublic,
        );
      } else {
        await GiteeApi.updateGist(
          existing.id,
          description: _descriptionCtrl.text.trim(),
          files: {
            if (_editingFile != null && _editingFile != _filenameCtrl.text.trim())
              // 改名 = 删除旧文件 + 写入新文件
              _editingFile!: null,
            _filenameCtrl.text.trim(): _contentCtrl.text,
          },
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑代码片段' : '新建代码片段'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '简单描述这段代码的用途',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _filenameCtrl,
              decoration: const InputDecoration(
                labelText: '文件名（含扩展名）',
                hintText: '例如 main.py',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请填写文件名' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _contentCtrl,
              maxLines: 14,
              decoration: const InputDecoration(
                labelText: '代码内容',
                alignLabelWithHint: true,
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              validator: (value) =>
                  value == null || value.isEmpty ? '请填写代码内容' : null,
            ),
            if (!isEditing) ...[
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('公开片段'),
                subtitle: const Text('关闭后仅自己可见'),
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
              ),
            ],
            if (isEditing && widget.existing!.files.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('已有文件（点击载入内容，改名即新建）',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.existing!.files
                    .map(
                      (file) => ActionChip(
                        label: Text(file.filename),
                        onPressed: () {
                          setState(() {
                            _editingFile = file.filename;
                            _filenameCtrl.text = file.filename;
                            _contentCtrl.text = file.content;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
