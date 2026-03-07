// lib/screens/team_page.dart
// Team management: add faculty by email, assign role (admin/staff), staff permissions.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';
import 'member_detail_page.dart';

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
  String? _myEmail;
  String? _myName;
  String? _myUserId;
  List<String>? _myPermissions;
  String? _currentAccountId;
  List<String> _orgAccountIds = [];
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
        NeyvoPulseApi.getAccountInfo(),
        NeyvoPulseApi.getAccountOrgs(),
      ]);
      final roleRes = results[0] as Map<String, dynamic>;
      final membersRes = results[1] as Map<String, dynamic>;
      final accountRes = results[2] as Map<String, dynamic>;
      final orgsRes = results[3] as Map<String, dynamic>;
      if (!mounted) return;
      final orgsList = orgsRes['orgs'] as List? ?? [];
      final orgIds = orgsList
          .map((e) => (e is Map ? e['account_id'] : e?.toString())?.toString())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
      final permsRaw = roleRes['permissions'];
      final permsList = permsRaw is List
          ? (permsRaw).map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).cast<String>().toList()
          : null;
      setState(() {
        _myRole = roleRes['role']?.toString();
        _myEmail = roleRes['email']?.toString();
        _myName = (roleRes['name'] ?? '').toString().trim().isNotEmpty
            ? roleRes['name']?.toString().trim()
            : null;
        _myUserId = roleRes['user_id']?.toString();
        _myPermissions = permsList;
        _members = List<Map<String, dynamic>>.from(
          membersRes['members'] as List? ?? [],
        );
        _currentAccountId = accountRes['account_id']?.toString();
        _orgAccountIds = orgIds;
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

  Future<void> _switchOrg(String accountId) async {
    if (accountId == _currentAccountId) return;
    try {
      await NeyvoPulseApi.linkUserToAccount(accountId);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
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
          () {
            final role = _myRole ?? '—';
            var name = (_myName ?? '').trim();
            var email = (_myEmail ?? '').trim();
            if (name.isEmpty && email.isEmpty) {
              final cu = FirebaseAuth.instance.currentUser;
              name = cu?.displayName ?? '';
              email = cu?.email ?? '';
            }
            final nameOrEmail = name.isNotEmpty ? name : (email.isNotEmpty ? email : '');
            if (nameOrEmail.isEmpty) return 'Your role: $role';
            return 'Your role: $role · $nameOrEmail';
          }(),
          style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary),
        ),
        const SizedBox(height: NeyvoSpacing.lg),
        if (_myRole == 'admin' || (_myPermissions?.contains('team') ?? false)) ...[
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
            'No team members yet. Add members above if you have permission.',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
          )
        else
          ..._members.map((m) {
            final rawName = m['name'];
            final name = rawName == null ? '' : rawName.toString().trim();
            final rawEmail = m['email'];
            final email = rawEmail == null ? '' : rawEmail.toString().trim();
            final userId = m['user_id'] ?? m['id'] ?? '?';
            final role = m['role']?.toString() ?? '—';
            final perms = m['permissions'];
            final permList = perms is List ? perms.map((e) => e.toString()).toList() : <String>[];
            String display;
            if (name.isNotEmpty) {
              display = name;
            } else if (email.isNotEmpty) {
              display = email;
            } else if (_myUserId != null && userId.toString() == _myUserId) {
              final fromApi = (_myName ?? _myEmail ?? '').toString().trim();
              if (fromApi.isNotEmpty) {
                display = fromApi;
              } else {
                final cu = FirebaseAuth.instance.currentUser;
                display = (cu?.displayName ?? cu?.email ?? '').toString().trim();
                if (display.isEmpty) display = userId.toString();
              }
            } else {
              display = userId.toString();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
              child: InkWell(
                onTap: () => _openMemberDetail(m),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NeyvoSpacing.md,
                    vertical: NeyvoSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: NeyvoTheme.surface.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeyvoTheme.borderSubtle),
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
                                color: NeyvoTheme.textMuted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: NeyvoColors.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  void _openMemberDetail(Map<String, dynamic> member) {
    final canEdit = _myRole == 'admin' &&
        _myUserId != null &&
        (member['user_id'] ?? member['id'] ?? '').toString() != _myUserId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberDetailPage(
          member: member,
          canEdit: canEdit,
          onUpdated: canEdit ? _load : null,
        ),
      ),
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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _staffIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _titleController = TextEditingController();
  final _officeController = TextEditingController();
  final _extensionController = TextEditingController();
  final _campusController = TextEditingController();
  String _role = 'staff';
  final Set<String> _selectedPermissions = {};

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _staffIdController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _titleController.dispose();
    _officeController.dispose();
    _extensionController.dispose();
    _campusController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) return false;
    if (_role == 'staff') {
      return _selectedPermissions.isNotEmpty;
    }
    return true;
  }

  /// Normalizes US phone: 10 digits -> +1XXXXXXXXXX, 11 digits starting with 1 -> +1XXXXXXXXXX
  static String _normalizePhoneUs(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return raw.trim();
    if (digits.length == 10) return '+1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
    if (raw.trim().startsWith('+')) return raw.trim();
    return '+1$digits';
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final staffId = _staffIdController.text.trim();
    final phoneRaw = _phoneController.text.trim();
    final phone = phoneRaw.isEmpty ? null : _normalizePhoneUs(phoneRaw);
    final department = _departmentController.text.trim();
    final title = _titleController.text.trim();
    final office = _officeController.text.trim();
    final extension = _extensionController.text.trim();
    final campus = _campusController.text.trim();
    final list = _selectedPermissions.toList();
    list.sort();
    final permissions = _role == 'staff' ? list : null;
    try {
      await NeyvoPulseApi.inviteMember(
        name: name,
        email: email,
        role: _role,
        permissions: permissions,
        staffId: staffId.isEmpty ? null : staffId,
        phone: phone,
        department: department.isEmpty ? null : department,
        title: title.isEmpty ? null : title,
        office: office.isEmpty ? null : office,
        extension: extension.isEmpty ? null : extension,
        campus: campus.isEmpty ? null : campus,
        sendInviteEmail: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite sent to $email. If they don\'t receive it, ask them to check spam.'),
          duration: const Duration(seconds: 5),
        ),
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
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'Full name',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
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
            TextField(
              controller: _staffIdController,
              decoration: const InputDecoration(
                labelText: 'Staff ID (optional)',
                hintText: 'Staff identifier',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                hintText: '10 digits, US (+1)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            TextField(
              controller: _departmentController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Department (optional)',
                hintText: 'e.g. Computer Science',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                hintText: 'e.g. Professor, Advisor, Lecturer',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            TextField(
              controller: _officeController,
              decoration: const InputDecoration(
                labelText: 'Office (optional)',
                hintText: 'e.g. Room 204, Building A',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            TextField(
              controller: _extensionController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Extension (optional)',
                hintText: 'Internal phone extension',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            TextField(
              controller: _campusController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Campus (optional)',
                hintText: 'e.g. Main Campus, North Campus',
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
              Wrap(
                spacing: NeyvoSpacing.md,
                runSpacing: NeyvoSpacing.sm,
                children: kTeamPermissions.map((e) {
                  final key = e.key;
                  final label = e.value;
                  final checked = _selectedPermissions.contains(key);
                  return ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 120, maxWidth: 180),
                    child: FilterChip(
                      selected: checked,
                      label: Text(
                        label,
                        style: NeyvoTextStyles.bodyPrimary,
                      ),
                      selectedColor: NeyvoColors.teal.withOpacity(0.2),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedPermissions.add(key);
                          } else {
                            _selectedPermissions.remove(key);
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
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

class _EditMemberDialog extends StatefulWidget {
  final Map<String, dynamic> member;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const _EditMemberDialog({
    required this.member,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<_EditMemberDialog> {
  late String _role;
  late Set<String> _selectedPermissions;
  late TextEditingController _nameController;
  late TextEditingController _staffIdController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;
  late TextEditingController _titleController;
  late TextEditingController _officeController;
  late TextEditingController _extensionController;
  late TextEditingController _campusController;

  @override
  void initState() {
    super.initState();
    final raw = (widget.member['role']?.toString() ?? 'staff').toLowerCase();
    _role = raw == 'viewer' ? 'staff' : raw;
    final perms = widget.member['permissions'];
    _selectedPermissions = {
      if (perms is List) ...perms.map((e) => e.toString()),
    };
    _nameController = TextEditingController(
      text: (widget.member['name'] ?? '').toString().trim(),
    );
    _staffIdController = TextEditingController(
      text: (widget.member['staff_id'] ?? '').toString().trim(),
    );
    _phoneController = TextEditingController(
      text: (widget.member['phone'] ?? '').toString().trim(),
    );
    _departmentController = TextEditingController(
      text: (widget.member['department'] ?? '').toString().trim(),
    );
    _titleController = TextEditingController(
      text: (widget.member['title'] ?? '').toString().trim(),
    );
    _officeController = TextEditingController(
      text: (widget.member['office'] ?? '').toString().trim(),
    );
    _extensionController = TextEditingController(
      text: (widget.member['extension'] ?? '').toString().trim(),
    );
    _campusController = TextEditingController(
      text: (widget.member['campus'] ?? '').toString().trim(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _staffIdController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _titleController.dispose();
    _officeController.dispose();
    _extensionController.dispose();
    _campusController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_role == 'staff') {
      return _selectedPermissions.isNotEmpty;
    }
    return true;
  }

  /// Normalizes US phone: 10 digits -> +1XXXXXXXXXX, 11 digits starting with 1 -> +1XXXXXXXXXX
  static String? _normalizePhoneUs(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return t;
    if (digits.length == 10) return '+1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
    if (t.startsWith('+')) return t;
    return '+1$digits';
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final userId = (widget.member['user_id'] ?? widget.member['id'] ?? '').toString();
    if (userId.isEmpty) return;
    final perms = _role == 'staff' ? _selectedPermissions.toList() : <String>[];
    final name = _nameController.text.trim();
    final staffId = _staffIdController.text.trim();
    final phone = _normalizePhoneUs(_phoneController.text.trim());
    final department = _departmentController.text.trim();
    final title = _titleController.text.trim();
    final office = _officeController.text.trim();
    final extension = _extensionController.text.trim();
    final campus = _campusController.text.trim();
    try {
      await NeyvoPulseApi.updateMember(
        userId,
        role: _role,
        permissions: perms,
        name: name.isEmpty ? null : name,
        staffId: staffId.isEmpty ? null : staffId,
        phone: phone,
        department: department.isEmpty ? null : department,
        title: title.isEmpty ? null : title,
        office: office.isEmpty ? null : office,
        extension: extension.isEmpty ? null : extension,
        campus: campus.isEmpty ? null : campus,
        email: (widget.member['email'] ?? '').toString().trim().isEmpty
            ? null
            : (widget.member['email'] ?? '').toString().trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team member updated')),
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
    final email = (widget.member['email'] ?? '').toString();
    return AlertDialog(
      backgroundColor: NeyvoColors.bgBase,
      title: Text(
        'Edit team member',
        style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (email.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                child: Text(
                  email,
                  style: NeyvoTextStyles.bodyPrimary,
                ),
              ),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Full name',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            TextField(
              controller: _staffIdController,
              decoration: const InputDecoration(
                labelText: 'Staff ID (optional)',
                hintText: 'Staff identifier',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                hintText: '10 digits, US (+1)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            TextField(
              controller: _departmentController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Department (optional)',
                hintText: 'e.g. Computer Science',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                hintText: 'e.g. Professor, Advisor, Lecturer',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            TextField(
              controller: _officeController,
              decoration: const InputDecoration(
                labelText: 'Office (optional)',
                hintText: 'e.g. Room 204, Building A',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            TextField(
              controller: _extensionController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Extension (optional)',
                hintText: 'Internal phone extension',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            TextField(
              controller: _campusController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Campus (optional)',
                hintText: 'e.g. Main Campus, North Campus',
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
                'Permissions',
                style: NeyvoTextStyles.label.copyWith(
                  color: NeyvoColors.textSecondary,
                ),
              ),
              const SizedBox(height: NeyvoSpacing.sm),
              Wrap(
                spacing: NeyvoSpacing.md,
                runSpacing: NeyvoSpacing.sm,
                children: kTeamPermissions.map((e) {
                  final key = e.key;
                  final label = e.value;
                  final checked = _selectedPermissions.contains(key);
                  return ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 120, maxWidth: 180),
                    child: FilterChip(
                      selected: checked,
                      label: Text(
                        label,
                        style: NeyvoTextStyles.bodyPrimary,
                      ),
                      selectedColor: NeyvoColors.teal.withOpacity(0.2),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedPermissions.add(key);
                          } else {
                            _selectedPermissions.remove(key);
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
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
          child: const Text('Save'),
        ),
      ],
    );
  }
}
