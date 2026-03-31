// lib/screens/template_scripts_page.dart
// Conversation scripts/templates for the AI assistant (choose, modify, create).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/template_scripts_provider.dart';
import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';

class TemplateScriptsPage extends ConsumerStatefulWidget {
  const TemplateScriptsPage({super.key});

  @override
  ConsumerState<TemplateScriptsPage> createState() => _TemplateScriptsPageState();
}

class _TemplateScriptsPageState extends ConsumerState<TemplateScriptsPage> {
  final _nameController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _editorSyncSig;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(templateScriptsCtrlProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _syncEditorIfNeeded(TemplateScriptsUiState ui) {
    if (!ui.showEditor) {
      _editorSyncSig = null;
      return;
    }
    final sig = ui.editingId ?? 'new';
    if (_editorSyncSig == sig) return;
    _editorSyncSig = sig;
    if (ui.editingId == null) {
      _nameController.clear();
      _bodyController.clear();
      return;
    }
    Map<String, dynamic>? found;
    for (final t in ui.templates) {
      if (t['id']?.toString() == ui.editingId) {
        found = t;
        break;
      }
    }
    if (found != null) {
      _nameController.text = found['name']?.toString() ?? '';
      _bodyController.text = found['body']?.toString() ?? found['script']?.toString() ?? '';
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

  Future<void> _saveTemplate() async {
    final ui = ref.read(templateScriptsCtrlProvider);
    final name = _nameController.text.trim();
    final body = _bodyController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter template name')));
      return;
    }
    try {
      if (ui.editingId != null) {
        await NeyvoPulseApi.updateCallTemplate(ui.editingId!, name: name, body: body);
      } else {
        await NeyvoPulseApi.createCallTemplate(name: name, body: body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved'), backgroundColor: NeyvoTheme.success),
      );
      ref.read(templateScriptsCtrlProvider.notifier).closeEditor();
      await ref.read(templateScriptsCtrlProvider.notifier).load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error),
        );
      }
    }
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
      await ref.read(templateScriptsCtrlProvider.notifier).deleteTemplate(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(templateScriptsCtrlProvider);
    _syncEditorIfNeeded(ui);

    if (ui.loading && ui.templates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ui.showEditor) {
      return _buildEditor(ui);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(NeyvoSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ui.error != null) ...[
            Text(ui.error!, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.error)),
            const SizedBox(height: NeyvoSpacing.md),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: NeyvoSpacing.lg),
                  child: Text(
                    'Scripts the assistant uses during calls. Prebuilt templates are provided by default; you can edit them or create your own. Use placeholders: {{student_name}}, {{balance}}, {{due_date}}, {{school_name}}, {{late_fee}}.',
                    style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => ref.read(templateScriptsCtrlProvider.notifier).openEditor(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New template'),
              ),
            ],
          ),
          const SizedBox(height: NeyvoSpacing.xl),
          if (ui.templates.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(NeyvoSpacing.xl),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.description_outlined, size: 48, color: NeyvoTheme.textMuted),
                      const SizedBox(height: NeyvoSpacing.md),
                      Text('No templates yet', style: NeyvoType.bodyLarge.copyWith(color: NeyvoTheme.textSecondary)),
                      const SizedBox(height: NeyvoSpacing.sm),
                      TextButton.icon(
                        onPressed: () => ref.read(templateScriptsCtrlProvider.notifier).openEditor(),
                        icon: const Icon(Icons.add),
                        label: const Text('Create first template'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...ui.templates.map((t) => Card(
                  margin: const EdgeInsets.only(bottom: NeyvoSpacing.md),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
                    title: Row(
                      children: [
                        Expanded(child: Text(t['name']?.toString() ?? 'Unnamed')),
                        if (t['is_default'] == true)
                          Padding(
                            padding: const EdgeInsets.only(left: NeyvoSpacing.sm),
                            child: Chip(
                              label: Text('Prebuilt', style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.primary)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      (t['body'] ?? t['script'] ?? '').toString().replaceAll('\n', ' ').length > 80
                          ? '${(t['body'] ?? t['script']).toString().substring(0, 80)}...'
                          : (t['body'] ?? t['script'] ?? '').toString(),
                      style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => ref.read(templateScriptsCtrlProvider.notifier).openEditor(template: t),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteTemplate(t['id']?.toString() ?? ''),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildEditor(TemplateScriptsUiState ui) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(NeyvoSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => ref.read(templateScriptsCtrlProvider.notifier).closeEditor(),
              ),
              Text(ui.editingId == null ? 'New template' : 'Edit template', style: NeyvoType.headlineMedium),
            ],
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(NeyvoSpacing.lg),
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
                  const SizedBox(height: NeyvoSpacing.lg),
                  TextField(
                    controller: _bodyController,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      labelText: 'Script (what the assistant says)',
                      hintText: 'Hello {{student_name}}, this is {{school_name}}. Your current balance is {{balance}}, due {{due_date}}...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: NeyvoSpacing.sm),
                  Wrap(
                    spacing: NeyvoSpacing.sm,
                    children: [
                      _placeholderChip('{{student_name}}'),
                      _placeholderChip('{{balance}}'),
                      _placeholderChip('{{due_date}}'),
                      _placeholderChip('{{school_name}}'),
                      _placeholderChip('{{late_fee}}'),
                    ],
                  ),
                  const SizedBox(height: NeyvoSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => ref.read(templateScriptsCtrlProvider.notifier).closeEditor(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: NeyvoSpacing.md),
                      FilledButton.icon(
                        onPressed: _saveTemplate,
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Save'),
                      ),
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
