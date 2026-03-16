// lib/features/managed_profiles/managed_profiles_page.dart
// Managed Voice Profiles — operator list in tabular form with Update / Delete / Duplicate.

import 'package:flutter/material.dart';
import '../../theme/neyvo_theme.dart';
import '../../tenant/tenant_brand.dart';
import '../agents/create_agent_wizard.dart';
import '../agents/create_first_operator_panel.dart';
import '../operators/universal_operator_wizard/universal_operator_wizard_screen.dart';
import '../../pulse_route_names.dart';
import 'managed_profile_api_service.dart';
import 'profile_detail_page.dart';
import 'raw_assistant_detail_page.dart';

class ManagedProfilesPage extends StatefulWidget {
  const ManagedProfilesPage({super.key, this.onOpenProfileDetail});

  /// When set (e.g. by Pulse shell), opening a profile navigates to the detail page inside the shell instead of pushing a full-screen page.
  final void Function(String profileId)? onOpenProfileDetail;

  @override
  State<ManagedProfilesPage> createState() => ManagedProfilesPageState();
}

class ManagedProfilesPageState extends State<ManagedProfilesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _profiles = [];

  void refresh() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ManagedProfileApiService.listProfiles();
      final list = (res['profiles'] as List?)?.cast<dynamic>() ?? [];
      if (!mounted) return;
      setState(() {
        _profiles = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

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
      _load();
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
        final res = await ManagedProfileApiService.createRawProfile(
          profileName: nameCtrl.text.trim().isEmpty ? 'Raw assistant' : nameCtrl.text.trim(),
          systemPrompt: promptCtrl.text.trim(),
          voicemailMessage: voicemailCtrl.text.trim(),
        );
        final profileId = (res['profile_id'] ?? '').toString();
        await _load();
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
      _load();
    }
  }

  void _openProfileDetail(String profileId) {
    final onOpen = widget.onOpenProfileDetail;
    final profile = _profiles.firstWhere(
      (p) => (p['profile_id'] ?? p['id'] ?? '').toString() == profileId,
      orElse: () => const <String, dynamic>{},
    );
    final isRaw = profile['raw_vapi'] == true || profile['schema_version'] == 3;

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
  void _onUpdate(Map<String, dynamic> p) {
    final id = (p['profile_id'] ?? p['id'] ?? '').toString();
    if (id.isEmpty) return;
    _openProfileDetail(id);
  }

  /// Delete with confirmation.
  Future<void> _onDelete(Map<String, dynamic> p) async {
    final id = (p['profile_id'] ?? p['id'] ?? '').toString();
    final name = (p['profile_name'] ?? 'Unnamed').toString();
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
      await ManagedProfileApiService.archiveProfile(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Operator deleted.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: ${e.toString()}')));
    }
  }

  /// Duplicate: backend clones the operator (VAPI assistant + new profile).
  Future<void> _onDuplicate(Map<String, dynamic> p) async {
    final id = (p['profile_id'] ?? p['id'] ?? '').toString();
    if (id.isEmpty) return;
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duplicating…')));
    try {
      final res = await ManagedProfileApiService.duplicateProfile(id);
      final newId = (res['profile_id'] ?? '').toString();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Operator duplicated.')));
      await _load();
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
    final primary = TenantBrand.primary(context);
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
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: TenantBrand.primary(context)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_profiles.isEmpty) {
      return const CreateFirstOperatorPanel();
    }
    return RefreshIndicator(
      onRefresh: _load,
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
                    rows: List<DataRow>.generate(_profiles.length, (i) {
                final p = _profiles[i];
                final profileId = (p['profile_id'] ?? p['id'] ?? '').toString();
                final name = (p['profile_name'] ?? 'Unnamed').toString();
                final created = _formatCreatedAt(p['created_at'] as String?);
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
                          child: Text(name, style: NeyvoTextStyles.body.copyWith(color: TenantBrand.primary(context), decoration: TextDecoration.underline)),
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
