// lib/screens/member_detail_page.dart
// Full-page member detail view (like StudentDetailPage).

import 'package:flutter/material.dart';

import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';

const List<MapEntry<String, String>> _kEditPermissions = [
  MapEntry('students', 'Students'),
  MapEntry('call_logs', 'Call Logs'),
  MapEntry('campaigns', 'Campaigns'),
  MapEntry('operators', 'Operators'),
  MapEntry('insights', 'Insights'),
  MapEntry('billing', 'Billing'),
];

class MemberDetailPage extends StatefulWidget {
  final Map<String, dynamic> member;
  final bool canEdit;
  final VoidCallback? onUpdated;

  const MemberDetailPage({
    super.key,
    required this.member,
    this.canEdit = false,
    this.onUpdated,
  });

  @override
  State<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  late Map<String, dynamic> _member;

  @override
  void initState() {
    super.initState();
    _member = Map<String, dynamic>.from(widget.member);
  }

  void _openEdit() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _EditMemberDialog(
        member: _member,
        onSaved: () {
          Navigator.of(ctx).pop();
          widget.onUpdated?.call();
          if (mounted) Navigator.of(context).pop(); // Return to team list with fresh data
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Future<void> _confirmRemove() async {
    final userId = (_member['user_id'] ?? _member['id'] ?? '').toString();
    if (userId.isEmpty) return;
    final name = (_member['name'] ?? '').toString().trim();
    final email = (_member['email'] ?? '').toString().trim();
    final displayLabel = name.isNotEmpty ? name : (email.isNotEmpty ? email : userId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeyvoColors.bgBase,
        title: const Text('Remove team member'),
        content: Text(
          'Remove $displayLabel from this team?',
          style: NeyvoTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await NeyvoPulseApi.deleteMember(userId);
      if (!mounted) return;
      widget.onUpdated?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team member removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_member['name'] ?? '').toString().trim();
    final email = (_member['email'] ?? '').toString().trim();
    final staffId = (_member['staff_id'] ?? '').toString().trim();
    final phone = (_member['phone'] ?? '').toString().trim();
    final department = (_member['department'] ?? '').toString().trim();
    final title = (_member['title'] ?? '').toString().trim();
    final office = (_member['office'] ?? '').toString().trim();
    final extension = (_member['extension'] ?? '').toString().trim();
    final campus = (_member['campus'] ?? '').toString().trim();
    final accountNumber = (_member['account_number'] ?? '').toString().trim();
    final role = (_member['role'] ?? '—').toString();
    final perms = _member['permissions'];
    final permList = perms is List ? perms.map((e) => e.toString()).toList() : <String>[];
    final displayName = name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Member');

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          if (widget.canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _openEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmRemove,
              tooltip: 'Remove',
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        children: [
          _detailCard(
            'Contact',
            [
              _detailRow('Email', email.isNotEmpty ? email : '—'),
              _detailRow('Phone', phone.isNotEmpty ? phone : '—'),
              if (extension.isNotEmpty) _detailRow('Extension', extension),
            ],
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          _detailCard(
            'Role & Position',
            [
              if (accountNumber.isNotEmpty) _detailRow('Account number', accountNumber),
              _detailRow('Role', role),
              if (title.isNotEmpty) _detailRow('Title', title),
              if (department.isNotEmpty) _detailRow('Department', department),
              if (staffId.isNotEmpty) _detailRow('Staff ID', staffId),
              if (office.isNotEmpty) _detailRow('Office', office),
              if (campus.isNotEmpty) _detailRow('Campus', campus),
              if (permList.isNotEmpty)
                _detailRow('Permissions', permList.join(', ')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
          ),
          const SizedBox(height: NeyvoSpacing.md),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: NeyvoTextStyles.bodyPrimary,
          ),
        ],
      ),
    );
  }
}

/// Inline edit dialog for member detail page – reuses same structure as team_page EditMemberDialog.
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
  late TextEditingController _accountNumberController;

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
    _accountNumberController = TextEditingController(
      text: (widget.member['account_number'] ?? '').toString().trim(),
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
    _accountNumberController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_role == 'staff') {
      return _selectedPermissions.isNotEmpty;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final userId = (widget.member['user_id'] ?? widget.member['id'] ?? '').toString();
    if (userId.isEmpty) return;
    final perms = _role == 'staff' ? _selectedPermissions.toList() : <String>[];
    final name = _nameController.text.trim();
    final staffId = _staffIdController.text.trim();
    final phone = _phoneController.text.trim();
    final department = _departmentController.text.trim();
    final title = _titleController.text.trim();
    final office = _officeController.text.trim();
    final extension = _extensionController.text.trim();
    final campus = _campusController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    try {
      await NeyvoPulseApi.updateMember(
        userId,
        role: _role,
        permissions: perms,
        name: name.isEmpty ? null : name,
        staffId: staffId.isEmpty ? null : staffId,
        phone: phone.isEmpty ? null : phone,
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
    return AlertDialog(
      backgroundColor: NeyvoColors.bgBase,
      title: Text(
        'Edit team member',
        style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 480),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              controller: _accountNumberController,
              decoration: const InputDecoration(
                labelText: 'Account number (optional)',
                hintText: 'e.g. 281720-0001',
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
                hintText: 'Phone number',
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
                children: _kEditPermissions.map((e) {
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
