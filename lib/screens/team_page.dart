// lib/screens/team_page.dart
// Team management: add faculty by email, assign role (admin/staff), staff permissions.

import 'package:flutter/material.dart';

import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';

/// Permission keys and display labels for staff role.
const List<MapEntry<String, String>> kTeamPermissions = [
  MapEntry('students', 'Students'),
  MapEntry('call_logs', 'Call Logs'),
  MapEntry('campaigns', 'Campaigns'),
  MapEntry('operators', 'Operators'),
  MapEntry('insights', 'Insights'),
  MapEntry('billing', 'Billing'),
];

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  String? _myRole;
  List<Map<String, dynamic>> _members = [];
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
      final results = await Future.wait([
        NeyvoPulseApi.getMyRole(),
        NeyvoPulseApi.listMembers(),
      ]);
      final roleRes = results[0] as Map<String, dynamic>;
      final membersRes = results[1] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _myRole = roleRes['role']?.toString();
        _members = List<Map<String, dynamic>>.from(
          membersRes['members'] as List? ?? [],
        );
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

  void _openAddMember() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AddMemberDialog(
        onSaved: () {
          Navigator.of(ctx).pop();
          _load();
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: NeyvoColors.teal),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      children: [
        Text(
          'Team',
          style: NeyvoTextStyles.title.copyWith(
            fontWeight: FontWeight.w700,
            color: NeyvoColors.textPrimary,
          ),
        ),
        const SizedBox(height: NeyvoSpacing.sm),
        Text(
          'Manage team members and roles',
          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        Text(
          'Your role: ${_myRole ?? "—"}',
          style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary),
        ),
        const SizedBox(height: NeyvoSpacing.lg),
        if (_myRole == 'admin') ...[
          OutlinedButton.icon(
            onPressed: _openAddMember,
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Add team member'),
            style: OutlinedButton.styleFrom(
              foregroundColor: NeyvoColors.teal,
              side: const BorderSide(color: NeyvoColors.teal),
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),
        ],
        Text(
          'Members',
          style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: NeyvoSpacing.sm),
        if (_members.isEmpty)
          Text(
            'No team members yet. Add members above (admin only).',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
          )
        else
          ..._members.map((m) {
            final email = m['email']?.toString();
            final userId = m['user_id'] ?? m['id'] ?? '?';
            final role = m['role']?.toString() ?? '—';
            final perms = m['permissions'];
            final permList = perms is List ? perms.map((e) => e.toString()).toList() : <String>[];
            final display = email?.isNotEmpty == true ? email! : userId.toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NeyvoSpacing.md,
                  vertical: NeyvoSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: NeyvoColors.bgRaised.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NeyvoColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            display,
                            style: NeyvoTextStyles.bodyPrimary,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Role: $role'
                                + (permList.isNotEmpty ? ' · ${permList.join(", ")}' : ''),
                            style: NeyvoTextStyles.micro.copyWith(
                              color: NeyvoColors.textMuted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const _AddMemberDialog({
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _emailController = TextEditingController();
  String _role = 'staff';
  final Set<String> _selectedPermissions = {};

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final email = _emailController.text.trim();
    if (email.isEmpty) return false;
    if (_role == 'staff') {
      return _selectedPermissions.isNotEmpty;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final email = _emailController.text.trim();
    final list = _selectedPermissions.toList();
    list.sort();
    final permissions = _role == 'staff' ? list : null;
    try {
      await NeyvoPulseApi.inviteMember(
        email: email,
        role: _role,
        permissions: permissions,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team member invited')),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NeyvoColors.bgBase,
      title: Text(
        'Add team member',
        style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email *',
                hintText: 'colleague@example.com',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'staff', child: Text('Staff')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'staff'),
            ),
            if (_role == 'staff') ...[
              const SizedBox(height: NeyvoSpacing.md),
              Text(
                'Permissions (select at least one)',
                style: NeyvoTextStyles.label.copyWith(
                  color: NeyvoColors.textSecondary,
                ),
              ),
              const SizedBox(height: NeyvoSpacing.sm),
              ...kTeamPermissions.map((e) {
                final key = e.key;
                final label = e.value;
                final checked = _selectedPermissions.contains(key);
                return CheckboxListTile(
                  value: checked,
                  title: Text(
                    label,
                    style: NeyvoTextStyles.bodyPrimary,
                  ),
                  activeColor: NeyvoColors.teal,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedPermissions.add(key);
                      } else {
                        _selectedPermissions.remove(key);
                      }
                    });
                  },
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
