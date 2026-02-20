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
                                  Text('Student: $studentId'),
                                  if (scheduled.isNotEmpty) Text('Scheduled: $scheduled'),
                                  if (message.isNotEmpty) Text(message, style: SpeariaType.bodySmall),
                                ],
                              ),
                              trailing: Container(
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

  Future<void> _openCreateReminder() async {
    List<dynamic> students = [];
    try {
      final res = await NeyvoPulseApi.listStudents();
      students = res['students'] as List? ?? [];
    } catch (_) {}
    final navigator = Navigator.of(context);
    String? selectedStudentId;
    final typeC = TextEditingController(text: 'balance_reminder');
    final messageC = TextEditingController();
    final scheduledC = TextEditingController();

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
                    decoration: const InputDecoration(labelText: 'Student *'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Select student')),
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
                    value: typeC.text,
                    decoration: const InputDecoration(labelText: 'Reminder Type'),
                    items: const [
                      DropdownMenuItem(value: 'balance_reminder', child: Text('Balance Reminder')),
                      DropdownMenuItem(value: 'due_date_reminder', child: Text('Due Date Reminder')),
                      DropdownMenuItem(value: 'payment_inquiry', child: Text('Payment Inquiry')),
                      DropdownMenuItem(value: 'general', child: Text('General')),
                    ],
                    onChanged: (v) => setDialogState(() => typeC.text = v ?? 'balance_reminder'),
                  ),
                  const SizedBox(height: SpeariaSpacing.md),
                  TextField(
                    controller: scheduledC,
                    decoration: const InputDecoration(
                      labelText: 'Scheduled At (optional)',
                      hintText: '2026-02-25 10:00 AM',
                    ),
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a student')));
                    return;
                  }
                  try {
                    await NeyvoPulseApi.createReminder(
                      studentId: selectedStudentId!,
                      reminderType: typeC.text.trim().isEmpty ? null : typeC.text.trim(),
                      scheduledAt: scheduledC.text.trim().isEmpty ? null : scheduledC.text.trim(),
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
