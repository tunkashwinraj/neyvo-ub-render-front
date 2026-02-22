// lib/screens/reminders_page.dart
// Enhanced reminders page with filters, better UI, and scheduling options

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../../theme/spearia_theme.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<dynamic> _reminders = [];
  bool _loading = true;
  String? _error;
  String _filterStatus = 'all'; // all, pending, completed, cancelled

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await NeyvoPulseApi.listReminders();
      final list = res['reminders'] as List? ?? [];
      if (mounted) setState(() {
        _reminders = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<dynamic> _getFilteredReminders() {
    if (_filterStatus == 'all') return _reminders;
    return _reminders.where((r) {
      final status = (r['status']?.toString() ?? '').toLowerCase();
      return status == _filterStatus;
    }).toList();
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return SpeariaAura.success;
      case 'cancelled':
        return SpeariaAura.error;
      case 'pending':
        return SpeariaAura.warning;
      default:
        return SpeariaAura.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(SpeariaSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.error), textAlign: TextAlign.center),
                const SizedBox(height: SpeariaSpacing.lg),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    
    final filtered = _getFilteredReminders();
    
    return Scaffold(
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(SpeariaSpacing.md),
            decoration: BoxDecoration(
              color: SpeariaAura.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filterStatus == 'all',
                    onTap: () => setState(() => _filterStatus = 'all'),
                  ),
                  const SizedBox(width: SpeariaSpacing.sm),
                  _FilterChip(
                    label: 'Pending',
                    selected: _filterStatus == 'pending',
                    onTap: () => setState(() => _filterStatus = 'pending'),
                  ),
                  const SizedBox(width: SpeariaSpacing.sm),
                  _FilterChip(
                    label: 'Completed',
                    selected: _filterStatus == 'completed',
                    onTap: () => setState(() => _filterStatus = 'completed'),
                  ),
                  const SizedBox(width: SpeariaSpacing.sm),
                  _FilterChip(
                    label: 'Cancelled',
                    selected: _filterStatus == 'cancelled',
                    onTap: () => setState(() => _filterStatus = 'cancelled'),
                  ),
                ],
              ),
            ),
          ),
          
          // Reminders List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_outlined, size: 64, color: SpeariaAura.textMuted),
                          const SizedBox(height: SpeariaSpacing.md),
                          Text(
                            _reminders.isEmpty ? 'No reminders yet' : 'No reminders found',
                            style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted),
                          ),
                          if (_reminders.isEmpty) ...[
                            const SizedBox(height: SpeariaSpacing.lg),
                            FilledButton.icon(
                              onPressed: _openCreateReminder,
                              icon: const Icon(Icons.add),
                              label: const Text('Create First Reminder'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(SpeariaSpacing.lg),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Reminders (${filtered.length})', style: SpeariaType.headlineMedium),
                            if (filtered.length != _reminders.length)
                              TextButton(
                                onPressed: () => setState(() => _filterStatus = 'all'),
                                child: const Text('Clear filter'),
                              ),
                          ],
                        ),
                        const SizedBox(height: SpeariaSpacing.md),
                        ...filtered.map((r) {
                          final id = r['id'] ?? '';
                          final studentId = r['student_id'] ?? '';
                          final type = r['reminder_type'] ?? 'Reminder';
                          final status = r['status']?.toString() ?? 'pending';
                          final scheduled = r['scheduled_at']?.toString() ?? '';
                          final message = r['message']?.toString() ?? '';
                          final statusColor = _getStatusColor(status);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: SpeariaSpacing.sm),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: statusColor.withOpacity(0.1),
                                child: Icon(
                                  status == 'completed' ? Icons.check : Icons.notifications,
                                  color: statusColor,
                                ),
                              ),
                              title: Text(type, style: SpeariaType.titleMedium),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Contact: $studentId'),
                                  if (scheduled.isNotEmpty) Text('Scheduled: $scheduled'),
                                  if (message.isNotEmpty) Text(message, style: SpeariaType.bodySmall),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: SpeariaType.labelSmall.copyWith(
                                        color: statusColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    tooltip: 'Edit reminder',
                                    onPressed: () => _openEditReminder(r),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    tooltip: 'Delete reminder',
                                    onPressed: () => _confirmDeleteReminder(id, type),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateReminder,
        child: const Icon(Icons.add),
      ),
    );
  }

  static String _formatScheduled(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// Maps backend reminder_type (e.g. "balance") to a valid dropdown value.
  static String _normalizeReminderType(String? v) {
    final s = (v ?? '').trim().toLowerCase();
    if (s == 'balance_reminder' || s == 'due_date_reminder' || s == 'payment_inquiry' || s == 'general') return s;
    if (s == 'balance') return 'balance_reminder';
    return 'balance_reminder';
  }

  static String _toIsoScheduled(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
        'T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _openCreateReminder() async {
    List<dynamic> students = [];
    try {
      final res = await NeyvoPulseApi.listStudents();
      students = res['students'] as List? ?? [];
    } catch (_) {}
    final navigator = Navigator.of(context);
    String? selectedStudentId;
    String selectedType = 'balance_reminder';
    DateTime? scheduledDateTime;
    final messageC = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Create Reminder'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStudentId,
                    decoration: const InputDecoration(labelText: 'Contact *'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Select contact')),
                      ...students.map((s) {
                        final id = s['id'] as String? ?? '';
                        final name = s['name'] as String? ?? id;
                        return DropdownMenuItem(value: id, child: Text(name));
                      }),
                    ],
                    onChanged: (v) => setDialogState(() => selectedStudentId = v),
                  ),
                  const SizedBox(height: SpeariaSpacing.md),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Reminder Type'),
                    items: const [
                      DropdownMenuItem(value: 'balance_reminder', child: Text('Balance Reminder')),
                      DropdownMenuItem(value: 'due_date_reminder', child: Text('Due Date Reminder')),
                      DropdownMenuItem(value: 'payment_inquiry', child: Text('Payment Inquiry')),
                      DropdownMenuItem(value: 'general', child: Text('General')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedType = v ?? 'balance_reminder'),
                  ),
                  const SizedBox(height: SpeariaSpacing.md),
                  ListTile(
                    title: const Text('Scheduled date & time'),
                    subtitle: Text(
                      scheduledDateTime == null ? 'Tap to pick (optional)' : _formatScheduled(scheduledDateTime!),
                      style: SpeariaType.bodySmall,
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: scheduledDateTime ?? DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: scheduledDateTime != null
                            ? TimeOfDay(hour: scheduledDateTime!.hour, minute: scheduledDateTime!.minute)
                            : const TimeOfDay(hour: 10, minute: 0),
                      );
                      if (time == null || !context.mounted) return;
                      setDialogState(() => scheduledDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                    },
                  ),
                  const SizedBox(height: SpeariaSpacing.md),
                  TextField(
                    controller: messageC,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Message (optional)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => navigator.pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (selectedStudentId == null || selectedStudentId!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a contact')));
                    return;
                  }
                  try {
                    await NeyvoPulseApi.createReminder(
                      studentId: selectedStudentId!,
                      reminderType: selectedType,
                      scheduledAt: scheduledDateTime != null ? _toIsoScheduled(scheduledDateTime!) : null,
                      message: messageC.text.trim().isEmpty ? null : messageC.text.trim(),
                    );
                    if (context.mounted) {
                      navigator.pop();
                      _load();
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditReminder(Map<String, dynamic> r) async {
    final id = r['id']?.toString() ?? '';
    if (id.isEmpty) return;
    List<dynamic> students = [];
    try {
      final res = await NeyvoPulseApi.listStudents();
      students = res['students'] as List? ?? [];
    } catch (_) {}
    final navigator = Navigator.of(context);
    String? selectedStudentId = r['student_id']?.toString();
    String selectedType = _normalizeReminderType(r['reminder_type']?.toString());
    String? scheduledStr = r['scheduled_at']?.toString();
    DateTime? scheduledDateTime;
    if (scheduledStr != null && scheduledStr.isNotEmpty) {
      scheduledDateTime = DateTime.tryParse(scheduledStr);
    }
    final messageC = TextEditingController(text: r['message']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Reminder'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStudentId,
                    decoration: const InputDecoration(labelText: 'Contact *'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Select contact')),
                      ...students.map((s) {
                        final sid = s['id'] as String? ?? '';
                        final name = s['name'] as String? ?? sid;
                        return DropdownMenuItem(value: sid, child: Text(name));
                      }),
                    ],
                    onChanged: (v) => setDialogState(() => selectedStudentId = v),
                  ),
                  const SizedBox(height: SpeariaSpacing.md),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Reminder Type'),
                    items: const [
                      DropdownMenuItem(value: 'balance_reminder', child: Text('Balance Reminder')),
                      DropdownMenuItem(value: 'due_date_reminder', child: Text('Due Date Reminder')),
                      DropdownMenuItem(value: 'payment_inquiry', child: Text('Payment Inquiry')),
                      DropdownMenuItem(value: 'general', child: Text('General')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedType = v ?? 'balance_reminder'),
                  ),
                  const SizedBox(height: SpeariaSpacing.md),
                  ListTile(
                    title: const Text('Scheduled date & time'),
                    subtitle: Text(
                      scheduledDateTime == null ? 'Tap to pick (optional)' : _formatScheduled(scheduledDateTime!),
                      style: SpeariaType.bodySmall,
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: scheduledDateTime ?? DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: scheduledDateTime != null
                            ? TimeOfDay(hour: scheduledDateTime!.hour, minute: scheduledDateTime!.minute)
                            : const TimeOfDay(hour: 10, minute: 0),
                      );
                      if (time == null || !context.mounted) return;
                      setDialogState(() => scheduledDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                    },
                  ),
                  const SizedBox(height: SpeariaSpacing.md),
                  TextField(
                    controller: messageC,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Message (optional)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => navigator.pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (selectedStudentId == null || selectedStudentId!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a contact')));
                    return;
                  }
                  try {
                    await NeyvoPulseApi.updateReminder(
                      id,
                      studentId: selectedStudentId,
                      reminderType: selectedType,
                      scheduledAt: scheduledDateTime != null ? _toIsoScheduled(scheduledDateTime!) : null,
                      message: messageC.text.trim().isEmpty ? null : messageC.text.trim(),
                    );
                    if (context.mounted) {
                      navigator.pop();
                      _load();
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteReminder(String id, String type) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('This reminder ($type) will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SpeariaAura.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await NeyvoPulseApi.deleteReminder(id);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder deleted')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: SpeariaAura.primary.withOpacity(0.2),
      checkmarkColor: SpeariaAura.primary,
    );
  }
}
