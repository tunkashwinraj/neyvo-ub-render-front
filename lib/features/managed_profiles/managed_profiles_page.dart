// lib/features/managed_profiles/managed_profiles_page.dart
// Managed Voice Profiles — operator list in tabular form with Update / Delete / Duplicate.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/neyvo_theme.dart';
import '../../core/providers/agents_provider.dart';
import '../agents/create_agent_wizard.dart';
import '../agents/create_first_operator_panel.dart';
import '../operators/universal_operator_wizard/universal_operator_wizard_screen.dart';
import '../../pulse_route_names.dart';
import 'profile_detail_page.dart';
import 'raw_assistant_detail_page.dart';

class ManagedProfilesPage extends ConsumerStatefulWidget {
  const ManagedProfilesPage({super.key, this.onOpenProfileDetail});

  /// When set (e.g. by Pulse shell), opening a profile navigates to the detail page inside the shell instead of pushing a full-screen page.
  final void Function(String profileId)? onOpenProfileDetail;

  @override
  ConsumerState<ManagedProfilesPage> createState() => ManagedProfilesPageState();
}

class ManagedProfilesPageState extends ConsumerState<ManagedProfilesPage> {
  void refresh() => ref.invalidate(agentsNotifierProvider);

  /// Format created_at for table (e.g. "Mar 15, 2026" or "2026-03-15").
  String _formatCreatedAt(String? created) {
    if (created == null || created.isEmpty) return '—';
    final dt = DateTime.tryParse(created);
    if (dt == null) return created;
    return '${_month(dt.month)} ${dt.day}, ${dt.year}';
  }

  String _month(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }

  Future<void> _openCreateAgent() async {
    // No business wizard gate — allow creating operators directly.
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => const CreateAgentWizard(),
    );
    if (created == true && mounted) {
      ref.invalidate(agentsNotifierProvider);
    }
  }

  Future<void> _openCreateRawAssistant() async {
    final nameCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    final voicemailCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New raw Vapi assistant'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: promptCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'System prompt',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: voicemailCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Voicemail message (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true && mounted) {
      try {
        final profileId = await ref.read(agentsNotifierProvider.notifier).createRawProfile(
          profileName: nameCtrl.text.trim().isEmpty ? 'Raw assistant' : nameCtrl.text.trim(),
          systemPrompt: promptCtrl.text.trim(),
          voicemailMessage: voicemailCtrl.text.trim(),
        );
        if (profileId.isNotEmpty && mounted) {
          _openProfileDetail(profileId);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _openUniversalWizard() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const UniversalOperatorWizardScreen(),
      ),
    );
    if (created == true && mounted) {
      ref.invalidate(agentsNotifierProvider);
    }
  }

  void _openProfileDetail(String profileId) {
    final onOpen = widget.onOpenProfileDetail;
    final asyncProfiles = ref.read(agentsNotifierProvider);
    final profiles = asyncProfiles.valueOrNull ?? const <AgentProfile>[];
    final profile = profiles.firstWhere(
      (p) => p.profileId == profileId,
      orElse: () => const AgentProfile(
        profileId: '',
        profileName: '',
        createdAt: null,
        rawVapi: false,
        schemaVersion: null,
        raw: <String, dynamic>{},
      ),
    );
    final isRaw = profile.rawVapi || profile.schemaVersion == 3;

    if (onOpen != null) {
      onOpen(profileId);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isRaw
            ? RawAssistantDetailPage(profileId: profileId)
            : ManagedProfileDetailPage(profileId: profileId),
      ),
    );
  }

  /// Update = open detail page.
  void _onUpdate(AgentProfile p) {
    final id = p.profileId;
    if (id.isEmpty) return;
    _openProfileDetail(id);
  }

  /// Delete with confirmation.
  Future<void> _onDelete(AgentProfile p) async {
    final id = p.profileId;
    final name = p.profileName;
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete operator'),
        content: Text(
          'Permanently delete "$name"? The assistant will be removed from VAPI and any attached number will be detached. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleting…')));
      await ref.read(agentsNotifierProvider.notifier).archiveProfile(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Operator deleted.')));
      ref.invalidate(agentsNotifierProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: ${e.toString()}')));
    }
  }

  /// Duplicate: backend clones the operator (VAPI assistant + new profile).
  Future<void> _onDuplicate(AgentProfile p) async {
    final id = p.profileId;
    if (id.isEmpty) return;
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duplicating…')));
    try {
      final newId = await ref.read(agentsNotifierProvider.notifier).duplicateProfile(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Operator duplicated.')));
      // Duplicate is always a raw profile; open raw detail page so editing works correctly.
      if (newId.isNotEmpty && mounted) {
        final onOpen = widget.onOpenProfileDetail;
        if (onOpen != null) {
          onOpen(newId);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RawAssistantDetailPage(profileId: newId),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Duplicate failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Operators',
                  style: NeyvoTextStyles.title.copyWith(
                    fontWeight: FontWeight.w700,
                    color: NeyvoColors.textPrimary,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openUniversalWizard,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Operator'),
                  style: OutlinedButton.styleFrom(foregroundColor: primary),
                ),
              ],
            ),
          ),
          Expanded(
            child: ref.watch(agentsNotifierProvider).when(
                  data: (data) => _body(data),
                  loading: () => Center(
                    child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                  ),
                  error: (e, st) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$e', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => ref.invalidate(agentsNotifierProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _body(List<AgentProfile> profiles) {
    if (profiles.isEmpty) {
      return const CreateFirstOperatorPanel();
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(agentsNotifierProvider.notifier).refresh(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: NeyvoCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(NeyvoColors.bgOverlay),
                    columns: const [
                      DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Operator ID', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Operator name', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Created date', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: SizedBox(width: 56, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600)))),
                    ],
                    rows: List<DataRow>.generate(profiles.length, (i) {
                final p = profiles[i];
                final profileId = p.profileId;
                final name = p.profileName;
                final created = _formatCreatedAt(p.createdAt);
                return DataRow(
                  cells: [
                    DataCell(
                      InkWell(
                        onTap: () => _openProfileDetail(profileId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('${i + 1}', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted)),
                        ),
                      ),
                    ),
                    DataCell(
                      InkWell(
                        onTap: () => _openProfileDetail(profileId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: SelectableText(profileId, style: NeyvoTextStyles.micro.copyWith(fontFamily: 'monospace')),
                        ),
                      ),
                    ),
                    DataCell(
                      InkWell(
                        onTap: () => _openProfileDetail(profileId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(name, style: NeyvoTextStyles.body.copyWith(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline)),
                        ),
                      ),
                    ),
                    DataCell(
                      InkWell(
                        onTap: () => _openProfileDetail(profileId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(created, style: NeyvoTextStyles.micro),
                        ),
                      ),
                    ),
                    DataCell(
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          switch (value) {
                            case 'update':
                              _onUpdate(p);
                              break;
                            case 'delete':
                              _onDelete(p);
                              break;
                            case 'duplicate':
                              _onDuplicate(p);
                              break;
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'update', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Update')])),
                          const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_outlined, size: 18), SizedBox(width: 8), Text('Duplicate')])),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: NeyvoColors.error),
                                const SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: NeyvoColors.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                    }),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
