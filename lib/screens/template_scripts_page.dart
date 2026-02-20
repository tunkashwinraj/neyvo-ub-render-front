// lib/screens/template_scripts_page.dart
// Conversation scripts/templates for the AI assistant (choose, modify, create).

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../../theme/spearia_theme.dart';

class TemplateScriptsPage extends StatefulWidget {
  const TemplateScriptsPage({super.key});

  @override
  State<TemplateScriptsPage> createState() => _TemplateScriptsPageState();
}

class _TemplateScriptsPageState extends State<TemplateScriptsPage> {
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;
  String? _error;
  bool _showEditor = false;
  String? _editingId;
  final _nameController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await NeyvoPulseApi.listCallTemplates();
      final list = res['templates'] as List? ?? [];
      _templates = list.cast<Map<String, dynamic>>();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openEditor({Map<String, dynamic>? template}) {
    _editingId = template?['id']?.toString();
    _nameController.text = template?['name']?.toString() ?? '';
    _bodyController.text = template?['body']?.toString() ?? template?['script']?.toString() ?? '';
    setState(() => _showEditor = true);
  }

  void _closeEditor() {
    _editingId = null;
    _nameController.clear();
    _bodyController.clear();
    setState(() => _showEditor = false);
  }

  Future<void> _saveTemplate() async {
    final name = _nameController.text.trim();
    final body = _bodyController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter template name')));
      return;
    }
    try {
      if (_editingId != null) {
        await NeyvoPulseApi.updateCallTemplate(_editingId!, name: name, body: body);
      } else {
        await NeyvoPulseApi.createCallTemplate(name: name, body: body);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved'), backgroundColor: SpeariaAura.success));
        _closeEditor();
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: SpeariaAura.error));
    }
  }

  Widget _placeholderChip(String placeholder) {
    return GestureDetector(
      onTap: () {
        final t = _bodyController.text;
        final pos = _bodyController.selection.baseOffset.clamp(0, t.length);
        _bodyController.text = '${t.substring(0, pos)}$placeholder${t.substring(pos)}';
        _bodyController.selection = TextSelection.collapsed(offset: pos + placeholder.length);
      },
      child: Chip(label: Text(placeholder)),
    );
  }

  Future<void> _deleteTemplate(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete template?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await NeyvoPulseApi.deleteCallTemplate(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: SpeariaAura.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _templates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_showEditor) {
      return _buildEditor();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpeariaSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            Text(_error!, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.error)),
            const SizedBox(height: SpeariaSpacing.md),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Scripts the assistant uses during calls. Use placeholders: {{student_name}}, {{balance}}, {{due_date}}, {{school_name}}.',
                style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
              ),
              FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New template'),
              ),
            ],
          ),
          const SizedBox(height: SpeariaSpacing.xl),
          if (_templates.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SpeariaSpacing.xl),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.script_outlined, size: 48, color: SpeariaAura.textMuted),
                      const SizedBox(height: SpeariaSpacing.md),
                      Text('No templates yet', style: SpeariaType.bodyLarge.copyWith(color: SpeariaAura.textSecondary)),
                      const SizedBox(height: SpeariaSpacing.sm),
                      TextButton.icon(
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.add),
                        label: const Text('Create first template'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._templates.map((t) => Card(
                  margin: const EdgeInsets.only(bottom: SpeariaSpacing.md),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.script_outlined)),
                    title: Text(t['name']?.toString() ?? 'Unnamed'),
                    subtitle: Text(
                      (t['body'] ?? t['script'] ?? '').toString().replaceAll('\n', ' ').length > 80
                          ? '${(t['body'] ?? t['script']).toString().substring(0, 80)}...'
                          : (t['body'] ?? t['script'] ?? '').toString(),
                      style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _openEditor(template: t)),
                        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteTemplate(t['id']?.toString() ?? '')),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpeariaSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.close), onPressed: _closeEditor),
              Text(_editingId == null ? 'New template' : 'Edit template', style: SpeariaType.headlineSmall),
            ],
          ),
          const SizedBox(height: SpeariaSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SpeariaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Template name',
                      hintText: 'e.g. Balance reminder - high balance',
                    ),
                  ),
                  const SizedBox(height: SpeariaSpacing.lg),
                  TextField(
                    controller: _bodyController,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      labelText: 'Script (what the assistant says)',
                      hintText: 'Hello {{student_name}}, this is {{school_name}}. Your current balance is {{balance}}, due {{due_date}}...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: SpeariaSpacing.sm),
                  Wrap(
                    spacing: SpeariaSpacing.sm,
                    children: [
                      _placeholderChip('{{student_name}}'),
                      _placeholderChip('{{balance}}'),
                      _placeholderChip('{{due_date}}'),
                      _placeholderChip('{{school_name}}'),
                      _placeholderChip('{{late_fee}}'),
                    ],
                  ),
                  const SizedBox(height: SpeariaSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: _closeEditor, child: const Text('Cancel')),
                      const SizedBox(width: SpeariaSpacing.md),
                      FilledButton.icon(onPressed: _saveTemplate, icon: const Icon(Icons.save, size: 18), label: const Text('Save')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
