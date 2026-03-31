// lib/screens/students_list_page.dart
// Enhanced students list with search, filter, and quick actions

import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/neyvo_api.dart';
import '../core/providers/students_list_provider.dart';
import '../neyvo_pulse_api.dart';
import '../utils/export_csv.dart';
import '../utils/csv_import.dart';
import '../utils/phone_util.dart';
import '../theme/neyvo_theme.dart';
import 'student_detail_page.dart';

class StudentsListPage extends ConsumerStatefulWidget {
  const StudentsListPage({super.key});

  @override
  ConsumerState<StudentsListPage> createState() => _StudentsListPageState();
}

class _StudentsListPageState extends ConsumerState<StudentsListPage> with SingleTickerProviderStateMixin {
  List<dynamic> _allStudents = [];
  List<dynamic> _filteredStudents = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _filterStatus = 'all'; // all, with_balance, overdue, due_this_week, no_balance
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  bool _isEducationOrg = false;
  List<dynamic> _reminders = [];
  bool _remindersLoading = false;
  late TabController _subTabController;

  List<Map<String, dynamic>> _agents = [];
  String? _selectedAgentId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(studentsListCtrlProvider.notifier).setSearchQuery(_searchController.text);
    });
    _subTabController = TabController(length: 2, vsync: this);
    _subTabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _subTabController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() => ref.read(studentsListCtrlProvider.notifier).loadReminders();

  Future<void> _load() => ref.read(studentsListCtrlProvider.notifier).load();

  static bool _isOverdue(Map<String, dynamic> s) {
    final dueStr = s['due_date']?.toString().trim() ?? '';
    if (dueStr.isEmpty) return false;
    final balanceStr = (s['balance']?.toString() ?? '').replaceAll(RegExp(r'[\$,]'), '').trim();
    if (balanceStr.isEmpty || balanceStr == '0') return false;
    try {
      final due = DateTime.parse(dueStr);
      return due.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  static bool _isDueThisWeek(Map<String, dynamic> s) {
    final dueStr = s['due_date']?.toString().trim() ?? '';
    if (dueStr.isEmpty) return false;
    try {
      final due = DateTime.parse(dueStr);
      final now = DateTime.now();
      final endOfWeek = now.add(const Duration(days: 7));
      return !due.isBefore(now) && !due.isAfter(endOfWeek);
    } catch (_) {
      return false;
    }
  }

  static bool _hasBalance(Map<String, dynamic> s) {
    final balance = (s['balance']?.toString() ?? '').replaceAll(RegExp(r'[\$,]'), '').trim();
    return balance.isNotEmpty && balance != '0';
  }

  void _filterStudents() =>
      ref.read(studentsListCtrlProvider.notifier).setSearchQuery(_searchController.text);

  void _toggleSelection(String id) => ref.read(studentsListCtrlProvider.notifier).toggleSelection(id);

  void _exitSelectionMode() => ref.read(studentsListCtrlProvider.notifier).clearSelection();

  List<Map<String, dynamic>> _getSelectedStudents() {
    final ui = ref.read(studentsListCtrlProvider);
    return ui.filteredStudents
        .where((s) => ui.selectedIds.contains(s['id']?.toString()))
        .map((s) => s as Map<String, dynamic>)
        .toList();
  }

  Future<void> _exportSelectedList() async {
    final list = _getSelectedStudents();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one contact')));
      return;
    }
    final sb = StringBuffer();
    sb.writeln('Id,Name,Student ID,Department,Phone,Email,Year of Study,Balance,Due Date,Late Fee,Last Call');
    for (final s in list) {
      final id = s['id']?.toString() ?? '';
      final first = (s['first_name']?.toString() ?? '').trim();
      final last = (s['last_name']?.toString() ?? '').trim();
      final legacyName = (s['name']?.toString() ?? '').trim();
      final name = ((first.isNotEmpty || last.isNotEmpty) ? '$first $last'.trim() : legacyName).replaceAll(',', ';');
      final studentId = (s['student_id']?.toString() ?? '').replaceAll(',', ';');
      final department = (s['department']?.toString() ?? '').replaceAll(',', ';');
      final phone = s['phone']?.toString() ?? '';
      final email = (s['email']?.toString() ?? '').replaceAll(',', ';');
      final yearOfStudy = (s['year_of_study']?.toString() ?? '').replaceAll(',', ';');
      final balance = s['balance']?.toString() ?? '';
      final dueDate = s['due_date']?.toString() ?? '';
      final lateFee = s['late_fee']?.toString() ?? '';
      final lastCall = s['last_call_date']?.toString() ?? '';
      sb.writeln('"$id","$name","$studentId","$department","$phone","$email","$yearOfStudy","$balance","$dueDate","$lateFee","$lastCall"');
    }
    final filename = 'students_export_${DateTime.now().toIso8601String().split('T').first}.csv';
    await downloadCsv(filename, sb.toString(), context);
  }

  Future<void> _scheduleRemindersForSelected() async {
    final list = _getSelectedStudents();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one contact')));
      return;
    }
    final messageC = TextEditingController();
    final scheduledC = TextEditingController(text: DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T').first);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Schedule reminders (${list.length} contacts)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: scheduledC,
                decoration: const InputDecoration(
                  labelText: 'Date (YYYY-MM-DD)',
                  hintText: '2026-02-25',
                ),
              ),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(
                controller: messageC,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Message (optional)',
                  hintText: 'Reminder: payment due',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => navigator.pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => navigator.pop(true), child: const Text('Schedule')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final scheduledAt = scheduledC.text.trim().isEmpty ? null : scheduledC.text.trim();
    final message = messageC.text.trim().isEmpty ? null : messageC.text.trim();
    int created = 0;
    for (final s in list) {
      final id = s['id']?.toString();
      if (id == null || id.isEmpty) continue;
      try {
        await NeyvoPulseApi.createReminder(
          studentId: id,
          scheduledAt: scheduledAt,
          message: message,
        );
        created++;
      } catch (_) {}
    }
    if (mounted) {
      _exitSelectionMode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scheduled $created reminder(s)')),
      );
    }
  }

  Future<void> _quickCall(Map<String, dynamic> student) async {
    final phone = student['phone']?.toString() ?? '';
    final first = (student['first_name']?.toString() ?? '').trim();
    final last = (student['last_name']?.toString() ?? '').trim();
    final legacyName = (student['name']?.toString() ?? '').trim();
    final name = (first.isNotEmpty || last.isNotEmpty)
        ? ('$first $last').trim()
        : legacyName;
    if (phone.isEmpty || name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone and name required')),
      );
      return;
    }
    
    try {
      final agentId = _selectedAgentId ?? (_agents.isNotEmpty ? (_agents.first['id'] ?? _agents.first['agent_id'])?.toString() : null);
      if (agentId == null || agentId.toString().trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create/select an agent before calling')),
          );
        }
        return;
      }
      await NeyvoPulseApi.startOutboundCall(
        agentId: agentId.toString().trim(),
        studentPhone: phone,
        studentName: name,
        studentId: student['id']?.toString(),
        balance: student['balance']?.toString(),
        dueDate: student['due_date']?.toString(),
        lateFee: student['late_fee']?.toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call started')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(studentsListCtrlProvider);
    final _allStudents = ui.allStudents;
    final _filteredStudents = ui.filteredStudents;
    final _loading = ui.loading;
    final _error = ui.error;
    final _selectionMode = ui.selectionMode;
    final _selectedIds = ui.selectedIds;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.error), textAlign: TextAlign.center),
                const SizedBox(height: NeyvoSpacing.lg),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode ? '${_selectedIds.length} selected' : 'Contacts'),
        bottom: !_selectionMode ? TabBar(
          controller: _subTabController,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Reminders'),
          ],
        ) : null,
        actions: _selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: _exportSelectedList,
                  tooltip: 'Export list CSV',
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_active),
                  onPressed: _scheduleRemindersForSelected,
                  tooltip: 'Schedule reminders',
                ),
                TextButton(
                  onPressed: _exitSelectionMode,
                  child: const Text('Cancel'),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.upload_file),
                  onPressed: _openImportCsvModal,
                  tooltip: 'Import contacts from CSV',
                ),
                IconButton(
                  icon: const Icon(Icons.checklist),
                  onPressed: () => ref.read(studentsListCtrlProvider.notifier).setSelectionMode(true),
                  tooltip: 'Select contacts',
                ),
              ],
      ),
      body: TabBarView(
        controller: _subTabController,
        children: [
          _buildStudentsTab(),
          _buildRemindersTab(),
        ],
      ),
      floatingActionButton: _selectionMode ? null : (_subTabController.index == 0
          ? FloatingActionButton(
              onPressed: _openAddStudent,
              backgroundColor: true ? Theme.of(context).colorScheme.primary : null,
              child: const Icon(Icons.add),
            )
          : FloatingActionButton(
              onPressed: () => _openScheduleReminderModal(),
              child: const Icon(Icons.add_alarm),
            )),
    );
  }

  Widget _buildStudentsTab() {
    final ui = ref.watch(studentsListCtrlProvider);
    final _allStudents = ui.allStudents;
    final _filteredStudents = ui.filteredStudents;
    final _filterStatus = ui.filterStatus;
    final _selectionMode = ui.selectionMode;
    final _selectedIds = ui.selectedIds;
    final _isEducationOrg = ui.isEducationOrg;
    return Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(NeyvoSpacing.md),
            decoration: BoxDecoration(
              color: NeyvoTheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: NeyvoSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filterStatus == 'all',
                        onTap: () {
                          ref.read(studentsListCtrlProvider.notifier).setFilterStatus('all');
                        },
                      ),
                      const SizedBox(width: NeyvoSpacing.sm),
                      _FilterChip(
                        label: 'With Balance',
                        selected: _filterStatus == 'with_balance',
                        onTap: () {
                          ref.read(studentsListCtrlProvider.notifier).setFilterStatus('with_balance');
                        },
                      ),
                      const SizedBox(width: NeyvoSpacing.sm),
                      _FilterChip(
                        label: 'Overdue',
                        selected: _filterStatus == 'overdue',
                        onTap: () {
                          ref.read(studentsListCtrlProvider.notifier).setFilterStatus('overdue');
                        },
                      ),
                      if (_isEducationOrg) ...[
                        const SizedBox(width: NeyvoSpacing.sm),
                        _FilterChip(
                          label: 'Due This Week',
                          selected: _filterStatus == 'due_this_week',
                          onTap: () {
                            ref.read(studentsListCtrlProvider.notifier).setFilterStatus('due_this_week');
                          },
                        ),
                        const SizedBox(width: NeyvoSpacing.sm),
                        _FilterChip(
                          label: 'No Balance',
                          selected: _filterStatus == 'no_balance',
                          onTap: () {
                            ref.read(studentsListCtrlProvider.notifier).setFilterStatus('no_balance');
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Students list: table view with columns
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _filteredStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school_outlined, size: 64, color: NeyvoColors.textMuted),
                          const SizedBox(height: NeyvoSpacing.md),
                          Text(
                            _allStudents.isEmpty ? 'No contacts yet' : 'No contacts found',
                            style: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.textMuted),
                          ),
                          if (_allStudents.isEmpty) ...[
                            const SizedBox(height: NeyvoSpacing.lg),
                            FilledButton.icon(
                              onPressed: _openAddStudent,
                              icon: const Icon(Icons.add),
                              label: const Text('Add first contact'),
                              style: FilledButton.styleFrom(
                                backgroundColor: true
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(NeyvoSpacing.md, NeyvoSpacing.sm, NeyvoSpacing.md, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Contacts (${_filteredStudents.length})',
                                style: NeyvoType.headlineMedium,
                              ),
                              if (_filteredStudents.length != _allStudents.length)
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(studentsListCtrlProvider.notifier).setFilterStatus('all');
                                  },
                                  child: const Text('Clear filters'),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(NeyvoColors.bgRaised),
                                columns: [
                                  if (_selectionMode)
                                    const DataColumn(label: SizedBox(width: 40, child: Text(''))),
                                  DataColumn(label: Text('Name', style: NeyvoType.labelSmall)),
                                  DataColumn(label: Text('Student ID', style: NeyvoType.labelSmall)),
                                  DataColumn(label: Text('Department', style: NeyvoType.labelSmall)),
                                  DataColumn(label: Text('Phone', style: NeyvoType.labelSmall)),
                                  DataColumn(label: Text('Email', style: NeyvoType.labelSmall)),
                                  DataColumn(label: Text('Year', style: NeyvoType.labelSmall)),
                                  DataColumn(label: Text('Last call', style: NeyvoType.labelSmall)),
                                  DataColumn(label: Text('Balance', style: NeyvoType.labelSmall)),
                                  DataColumn(label: Text('Due date', style: NeyvoType.labelSmall)),
                                  const DataColumn(label: SizedBox(width: 48, child: Text(''))),
                                ],
                                rows: _filteredStudents.map<DataRow>((s) {
                                  final sMap = s as Map<String, dynamic>;
                                  final id = sMap['id'] as String? ?? '';
                                  final first = (sMap['first_name'] as String? ?? '').trim();
                                  final last = (sMap['last_name'] as String? ?? '').trim();
                                  final legacyName = (sMap['name'] as String? ?? '').trim();
                                  final displayName = (first.isNotEmpty || last.isNotEmpty)
                                      ? ('$first $last').trim()
                                      : (legacyName.isNotEmpty ? legacyName : '—');
                                  final studentId = sMap['student_id']?.toString() ?? '—';
                                  final department = sMap['department']?.toString() ?? '—';
                                  final phone = sMap['phone']?.toString() ?? '—';
                                  final email = sMap['email']?.toString() ?? '—';
                                  final yearOfStudy = sMap['year_of_study']?.toString() ?? '—';
                                  final lastCallDate = sMap['last_call_date']?.toString() ?? '';
                                  final lastCallOutcome = sMap['last_call_outcome']?.toString() ?? '';
                                  final lastCall = lastCallDate.isEmpty
                                      ? '—'
                                      : (lastCallOutcome.isNotEmpty ? '$lastCallDate ($lastCallOutcome)' : lastCallDate);
                                  final balance = sMap['balance']?.toString() ?? '—';
                                  final dueDate = sMap['due_date']?.toString() ?? '—';
                                  final selected = _selectedIds.contains(id);
                                  return DataRow(
                                    selected: selected,
                                    onSelectChanged: _selectionMode
                                        ? (_) => _toggleSelection(id)
                                        : null,
                                    cells: [
                                      if (_selectionMode)
                                        DataCell(Checkbox(
                                          value: selected,
                                          onChanged: (_) => _toggleSelection(id),
                                          activeColor: NeyvoTheme.primary,
                                        )),
                                      DataCell(
                                        GestureDetector(
                                          onTap: () {
                                            if (_selectionMode) {
                                              _toggleSelection(id);
                                            } else {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => StudentDetailPage(studentId: id, onUpdated: _load),
                                                ),
                                              );
                                            }
                                          },
                                          child: Text(displayName, style: NeyvoType.bodyMedium),
                                        ),
                                      ),
                                      DataCell(Text(studentId, style: NeyvoType.bodySmall)),
                                      DataCell(Text(department, style: NeyvoType.bodySmall)),
                                      DataCell(Text(phone, style: NeyvoType.bodySmall)),
                                      DataCell(Text(email, style: NeyvoType.bodySmall)),
                                      DataCell(Text(yearOfStudy, style: NeyvoType.bodySmall)),
                                      DataCell(Text(lastCall, style: NeyvoType.bodySmall)),
                                      DataCell(Text(balance, style: NeyvoType.bodySmall)),
                                      DataCell(Text(dueDate, style: NeyvoType.bodySmall)),
                                      DataCell(IconButton(
                                        icon: const Icon(Icons.phone, size: 20),
                                        color: NeyvoTheme.primary,
                                        onPressed: () => _quickCall(sMap),
                                        tooltip: 'Call',
                                      )),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      );
  }

  Widget _buildRemindersTab() {
    final ui = ref.watch(studentsListCtrlProvider);
    final _reminders = ui.reminders;
    final _remindersLoading = ui.remindersLoading;
    if (_reminders.isEmpty && !_remindersLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadReminders());
    }
    if (_remindersLoading && _reminders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(NeyvoSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Reminders', style: NeyvoType.titleMedium),
              TextButton.icon(
                onPressed: _loadReminders,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _reminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: NeyvoColors.textMuted),
                      const SizedBox(height: NeyvoSpacing.md),
                      Text('No reminders scheduled.', style: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.textMuted)),
                      const SizedBox(height: NeyvoSpacing.sm),
                      Text('Schedule reminders to follow up with students.', style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textMuted)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(NeyvoSpacing.md),
                  itemCount: _reminders.length,
                  itemBuilder: (context, i) {
                    final r = _reminders[i] as Map<String, dynamic>;
                    final studentName = r['student_name'] ?? r['contact_name'] ?? '—';
                    final agentName = r['agent_name'] ?? '—';
                    final scheduled = r['scheduled_at']?.toString() ?? '';
                    final type = r['message_type'] ?? r['reminder_type'] ?? 'Reminder';
                    final status = r['status'] ?? 'pending';
                    return Card(
                      margin: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                      child: ListTile(
                        title: Text(studentName.toString(), style: NeyvoType.titleMedium),
                        subtitle: Text('$agentName • $scheduled • $type • $status'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            try {
                              await NeyvoPulseApi.deleteReminder(r['id']?.toString() ?? '');
                              _loadReminders();
                            } catch (_) {}
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _openScheduleReminderModal() async {
    final ui = ref.read(studentsListCtrlProvider);
    final students = ui.allStudents;
    final agentsRes = await NeyvoPulseApi.listAgents(direction: 'outbound');
    final agents = (agentsRes['agents'] as List? ?? []).where((a) => (a['industry']?.toString().toLowerCase() ?? '') == 'education').toList();
    String? selectedStudentId;
    String? selectedAgentId;
    String selectedMessageType = 'balance_reminder';
    final scheduledC = TextEditingController(text: DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 19));
    final notesC = TextEditingController();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          return AlertDialog(
            title: const Text('Schedule Reminder'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStudentId,
                    decoration: const InputDecoration(labelText: 'Student'),
                    items: students.map((s) => DropdownMenuItem(value: s['id']?.toString(), child: Text(s['name']?.toString() ?? '—'))).toList(),
                    onChanged: (v) => setDialogState(() => selectedStudentId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedAgentId,
                    decoration: const InputDecoration(labelText: 'Operator'),
                    items: agents.isEmpty ? [const DropdownMenuItem(value: null, child: Text('No education agents'))] : agents.map((a) => DropdownMenuItem(value: a['id']?.toString(), child: Text(a['name']?.toString() ?? '—'))).toList(),
                    onChanged: (v) => setDialogState(() => selectedAgentId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scheduledC,
                    decoration: const InputDecoration(labelText: 'Date & time (ISO)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedMessageType,
                    decoration: const InputDecoration(labelText: 'Message type'),
                    items: const [
                      DropdownMenuItem(value: 'balance_reminder', child: Text('Balance Reminder')),
                      DropdownMenuItem(value: 'due_date', child: Text('Due Date Reminder')),
                      DropdownMenuItem(value: 'late_fee', child: Text('Late Fee Notice')),
                      DropdownMenuItem(value: 'general', child: Text('General')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedMessageType = v ?? 'balance_reminder'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: notesC, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (selectedStudentId == null || selectedStudentId!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a student')));
                    return;
                  }
                  try {
                    await NeyvoPulseApi.createReminder(
                      studentId: selectedStudentId!,
                      agentId: selectedAgentId,
                      scheduledAt: scheduledC.text.trim(),
                      messageType: selectedMessageType,
                      notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                    );
                    if (ctx2.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      _loadReminders();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder scheduled')));
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
                child: const Text('Schedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openImportCsvModal() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ImportCsvDialog(
        onDone: () {
          Navigator.of(ctx).pop();
          _load();
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showStudentsImportProgressDialog(String jobId) async {
    Timer? timer;
    bool cancelRequested = false;
    bool closed = false;
    Map<String, dynamic> lastJob = {};

    try {
      final finalJob = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setState) {
              void setFromResponse(Map<String, dynamic> res) {
                final payload = res['job'] is Map
                    ? Map<String, dynamic>.from(res['job'] as Map)
                    : res;
                lastJob = Map<String, dynamic>.from(payload);
                setState(() {});
              }

              if (timer == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (closed) return;
                  timer = Timer.periodic(const Duration(seconds: 2), (t) async {
                    try {
                      final res = await NeyvoPulseApi.getStudentsImportJobStatus(jobId);
                      setFromResponse(res);
                      final status = (lastJob['status'] ?? '').toString();
                      if (const {'completed', 'failed', 'cancelled'}.contains(status)) {
                        t.cancel();
                        if (!closed && Navigator.of(ctx).canPop()) {
                          closed = true;
                          Navigator.of(ctx).pop(lastJob);
                        }
                      }
                    } catch (_) {
                      // Keep polling; server-side job might be momentarily unavailable.
                    }
                  });
                });
              }

              final status = (lastJob['status'] ?? 'queued').toString();
              final processedRaw = lastJob['processed_rows'];
              final totalRaw = lastJob['total_rows'];
              final processed = processedRaw is num ? processedRaw.toInt() : 0;
              final total = totalRaw is num ? totalRaw.toInt() : 0;

              final progressWidget = total > 0
                  ? LinearProgressIndicator(
                      value: (processed / total).clamp(0.0, 1.0),
                    )
                  : const LinearProgressIndicator();

              return AlertDialog(
                title: const Text('Import in progress'),
                content: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      progressWidget,
                      const SizedBox(height: NeyvoSpacing.sm),
                      Text('Status: $status', style: NeyvoType.bodyMedium),
                      const SizedBox(height: 6),
                      Text(
                        total > 0 ? 'Processed: $processed / $total' : 'Processed: $processed',
                        style: NeyvoType.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Imported: ${(lastJob['imported'] ?? 0)} · Updated: ${(lastJob['updated'] ?? 0)} · Failed: ${(lastJob['failed'] ?? 0)}',
                        style: NeyvoType.bodySmall,
                      ),
                      if (lastJob['cancel_requested'] == true) ...[
                        const SizedBox(height: 8),
                        Text('Cancel requested…', style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: cancelRequested
                        ? null
                        : () async {
                            try {
                              setState(() => cancelRequested = true);
                              await NeyvoPulseApi.cancelStudentsImportJob(jobId);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Cancel failed: $e')),
                                );
                              }
                            }
                          },
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        },
      );

      return finalJob;
    } finally {
      timer?.cancel();
    }
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.single.bytes == null) return;
    final bytes = result.files.single.bytes!;
    final text = String.fromCharCodes(bytes);
    List<Map<String, String>> rows;
    try {
      rows = parseCsvToMaps(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid CSV: $e')),
        );
      }
      return;
    }
    if (rows.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV has no data rows')));
      return;
    }
    // Map common column names to API fields
    String get(Map<String, String> row, List<String> keys) {
      for (final k in keys) {
        for (final key in row.keys) {
          if (key.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') == k.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '')) {
            final v = row[key]?.trim() ?? '';
            if (v.isNotEmpty) return v;
          }
        }
      }
      return '';
    }
    final preview = rows
        .take(5)
        .map((r) {
          final first = get(r, ['first_name', 'firstname']);
          final last = get(r, ['last_name', 'lastname']);
          final legacyName = get(r, ['name']);
          final displayName = (first.isNotEmpty || last.isNotEmpty)
              ? ('$first $last').trim()
              : legacyName;
          return displayName + ' | ' + get(r, ['phone', 'phone', 'mobile']);
        })
        .toList();
    final importNameC = TextEditingController();
    final navigator = Navigator.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import contacts from CSV'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Found ${rows.length} row(s). First 5:', style: NeyvoType.titleMedium),
              const SizedBox(height: NeyvoSpacing.sm),
              ...preview.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(p, style: NeyvoType.bodySmall),
              )),
              const SizedBox(height: NeyvoSpacing.md),
              Text('Import/List name (optional)', style: NeyvoType.labelSmall),
              const SizedBox(height: 4),
              TextField(
                controller: importNameC,
                decoration: const InputDecoration(
                  hintText: 'e.g. Spring 2026 Nursing Cohort',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: NeyvoSpacing.md),
              Text(
                'Required columns: either name OR first_name (plus phone). Optional: last_name, email, balance, due_date, late_fee, notes.',
                style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => navigator.pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => navigator.pop(true), child: const Text('Import')),
        ],
      ),
    );
    final importName = importNameC.text.trim();
    importNameC.dispose();
    if (go != true || !mounted) return;
    try {
      final res = await NeyvoPulseApi.postStudentsImportCsv(
        text,
        importName: importName.isEmpty ? null : importName,
      );
      if (!mounted) return;
      final jobIdRaw = res['job_id'];
      if (jobIdRaw != null) {
        final jobId = jobIdRaw.toString();
        final finalJob = await _showStudentsImportProgressDialog(jobId);
        await _load();

        final status = (finalJob?['status'] ?? res['status'] ?? '').toString();
        final imported = finalJob?['imported'] is num ? (finalJob!['imported'] as num).toInt() : 0;
        final updated = finalJob?['updated'] is num ? (finalJob!['updated'] as num).toInt() : 0;
        final failed = finalJob?['failed'] is num ? (finalJob!['failed'] as num).toInt() : 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'cancelled'
                  ? 'Import cancelled.'
                  : 'Import finished: $imported imported, $updated updated${failed > 0 ? ', $failed failed' : ''}.',
            ),
          ),
        );
      } else {
        await _load();
        final imported = res['imported'] as int? ?? 0;
        final updated = res['updated'] as int? ?? 0;
        final failed = res['failed'] as int? ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported $imported, updated $updated${failed > 0 ? ', $failed failed' : ''}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _openAddStudent() async {
    final firstNameC = TextEditingController();
    final lastNameC = TextEditingController();
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final emailC = TextEditingController();
    final advisorNameC = TextEditingController();
    final bookingUrlC = TextEditingController();
    final balanceC = TextEditingController();
    final dueDateC = TextEditingController();
    final lateFeeC = TextEditingController();
    final studentIdC = TextEditingController();
    final departmentC = TextEditingController();
    final yearOfStudyC = TextEditingController();
    final notesC = TextEditingController();
    final navigator = Navigator.of(context);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add student'),
        content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: firstNameC,
                      decoration: const InputDecoration(labelText: 'First name *', hintText: 'First name'),
                    ),
                  ),
                  const SizedBox(width: NeyvoSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: lastNameC,
                      decoration: const InputDecoration(labelText: 'Last name (optional)', hintText: 'Last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Display name (optional)', hintText: 'Defaults to first name'),
              ),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(
                controller: phoneC,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  hintText: '123-456-7890 or (123) 456-7890',
                ),
              ),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: emailC, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (optional)', hintText: 'Email address')),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(
                controller: advisorNameC,
                decoration: const InputDecoration(
                  labelText: 'Advisor name (optional)',
                  hintText: 'Used for {{advisor_name}}',
                ),
              ),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(
                controller: bookingUrlC,
                decoration: const InputDecoration(
                  labelText: 'Booking URL (optional)',
                  hintText: 'Used for {{booking_url}}',
                ),
              ),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: studentIdC, decoration: const InputDecoration(labelText: 'Student ID (optional)', hintText: 'Internal ID or reference')),
              const SizedBox(height: NeyvoSpacing.md),
              Row(
                children: [
                  Expanded(child: TextField(controller: departmentC, decoration: const InputDecoration(labelText: 'Department (optional)', hintText: 'e.g. Finance'))),
                  const SizedBox(width: NeyvoSpacing.md),
                  Expanded(child: TextField(controller: yearOfStudyC, decoration: const InputDecoration(labelText: 'Year of study (optional)', hintText: 'e.g. 2025'))),
                ],
              ),
              const SizedBox(height: NeyvoSpacing.md),
              TextField(controller: notesC, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Reason for call, follow-up notes...')),
              if (_isEducationOrg) ...[
                const SizedBox(height: NeyvoSpacing.md),
                TextField(controller: balanceC, decoration: const InputDecoration(labelText: 'Balance (optional)', hintText: '\$1,000')),
                const SizedBox(height: NeyvoSpacing.md),
                TextField(controller: dueDateC, decoration: const InputDecoration(labelText: 'Due Date (optional)', hintText: '2026-02-25')),
                const SizedBox(height: NeyvoSpacing.md),
                TextField(controller: lateFeeC, decoration: const InputDecoration(labelText: 'Late Fee (optional)', hintText: '\$75')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => navigator.pop(), child: const Text('Cancel')),
          FilledButton(
            style: true
                ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary)
                : null,
            onPressed: () async {
              final firstName = firstNameC.text.trim();
              final lastName = lastNameC.text.trim();
              final legacyName = nameC.text.trim();
              final name = legacyName.isNotEmpty ? legacyName : firstName;
              final phoneRaw = phoneC.text.trim();
              final phone = normalizePhoneInput(phoneRaw);
              if (firstName.isEmpty || phoneRaw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('First name and phone required')));
                return;
              }
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Enter a valid US phone (e.g. 123-456-7890, (123) 456-7890)'),
                ));
                return;
              }
              try {
                await NeyvoPulseApi.createStudent(
                  name: name,
                  phone: phone,
                  firstName: firstName,
                  lastName: lastName.isNotEmpty ? lastName : null,
                  email: emailC.text.trim().isEmpty ? null : emailC.text.trim(),
                  balance: balanceC.text.trim().isEmpty ? null : balanceC.text.trim(),
                  dueDate: dueDateC.text.trim().isEmpty ? null : dueDateC.text.trim(),
                  lateFee: lateFeeC.text.trim().isEmpty ? null : lateFeeC.text.trim(),
                  studentId: studentIdC.text.trim().isEmpty ? null : studentIdC.text.trim(),
                  notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                  department: departmentC.text.trim().isEmpty ? null : departmentC.text.trim(),
                  yearOfStudy: yearOfStudyC.text.trim().isEmpty ? null : yearOfStudyC.text.trim(),
                  advisorName: advisorNameC.text.trim().isEmpty ? null : advisorNameC.text.trim(),
                  bookingUrl: bookingUrlC.text.trim().isEmpty ? null : bookingUrlC.text.trim(),
                );
                if (context.mounted) {
                  navigator.pop();
                  _load();
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Add'),
          ),
        ],
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
      selectedColor: NeyvoTheme.primary.withOpacity(0.2),
      checkmarkColor: NeyvoTheme.primary,
    );
  }
}

class _ImportCsvDialog extends StatefulWidget {
  final VoidCallback onDone;
  final VoidCallback onCancel;

  const _ImportCsvDialog({required this.onDone, required this.onCancel});

  @override
  State<_ImportCsvDialog> createState() => _ImportCsvDialogState();
}

class _ImportCsvDialogState extends State<_ImportCsvDialog> {
  int _step = 1;
  String _csvText = '';
  bool _loading = false;
  int? _imported;
  int? _updated;
  int? _failed;
  List<String> _errors = [];
  List<Map<String, String>> _validRows = [];
  List<String> _errorLines = [];

  // Async import progress (Cloud Tasks job_id).
  String? _activeJobId;
  String _activeJobStatus = '';
  int? _jobProcessedRows;
  int? _jobTotalRows;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.single.bytes == null) return;
    final text = String.fromCharCodes(result.files.single.bytes!);
    setState(() {
      _csvText = text;
      _step = 2;
      _validateCsv();
    });
  }

  void _validateCsv() {
    List<Map<String, String>> rows;
    try {
      rows = parseCsvToMaps(_csvText);
    } catch (_) {
      _validRows = [];
      _errorLines = ['Invalid CSV format'];
      return;
    }
    final valid = <Map<String, String>>[];
    final errs = <String>[];
    String getVal(Map<String, String> r, List<String> keys) {
      for (final k in keys) {
        for (final key in r.keys) {
          if (key.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') == k.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '')) {
            final v = r[key]?.trim() ?? '';
            if (v.isNotEmpty) return v;
          }
        }
      }
      return '';
    }
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final name = getVal(r, ['name', 'student_name', 'first_name', 'firstname']);
      final phone = getVal(r, ['phone', 'mobile', 'cell']);
      if (name.isEmpty) {
        errs.add('Row ${i + 2}: Missing name (or first_name)');
        continue;
      }
      if (phone.isEmpty) {
        errs.add('Row ${i + 2}: Missing phone');
        continue;
      }
      valid.add(r);
    }
    setState(() {
      _validRows = valid;
      _errorLines = errs;
    });
  }

  Future<void> _downloadTemplate() async {
    // On web, prefer a real CSV download via the browser.
    if (kIsWeb) {
      final url = '${NeyvoApi.baseUrl}/api/pulse/students/import/template';
      final ok = await NeyvoApi.launchExternal(url);
      if (ok) return;
      // Fall through to text fallback if launch fails.
    }

    // Fallback (mobile/desktop, or if launchExternal failed): show the CSV so user can copy/save.
    try {
      final template = await NeyvoPulseApi.getStudentsImportTemplate();
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Template CSV'),
            content: SingleChildScrollView(
              child: SelectableText(template, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template: name,phone,email,student_id,balance,due_date,late_fee,notes (first_name/last_name also supported)')),
        );
      }
    }
  }

  Future<void> _doImport() async {
    setState(() => _loading = true);
    try {
      final res = await NeyvoPulseApi.postStudentsImportCsv(_csvText);
      if (mounted) {
        final jobIdRaw = res['job_id'];
        if (jobIdRaw != null) {
          final jobId = jobIdRaw.toString();
          Map<String, dynamic> lastJob = {};
          setState(() {
            _activeJobId = jobId;
            _activeJobStatus = 'queued';
            _jobProcessedRows = null;
            _jobTotalRows = null;
            _loading = false;
            _step = 3;
          });
          while (mounted) {
            final statusRes = await NeyvoPulseApi.getStudentsImportJobStatus(jobId);
            final payload = statusRes['job'] is Map
                ? Map<String, dynamic>.from(statusRes['job'] as Map)
                : statusRes;
            lastJob = Map<String, dynamic>.from(payload);
            final status = (lastJob['status'] ?? '').toString();
            final processedRaw = lastJob['processed_rows'];
            final totalRaw = lastJob['total_rows'];
            setState(() {
              _activeJobStatus = status;
              _jobProcessedRows = processedRaw is num ? processedRaw.toInt() : null;
              _jobTotalRows = totalRaw is num ? totalRaw.toInt() : null;
            });
            if (const {'completed', 'failed', 'cancelled'}.contains(status)) break;
            await Future.delayed(const Duration(seconds: 2));
          }

          final errSample = (lastJob['error_sample'] as List?) ?? const [];
          final errs = errSample.map((e) => e.toString()).toList();

          setState(() {
            _imported = lastJob['imported'] as int? ?? 0;
            _updated = lastJob['updated'] as int? ?? 0;
            _failed = lastJob['failed'] as int? ?? 0;
            _errors = errs;
            _loading = false;
            _step = 3;
          });
          return;
        }

        final rawErrs = res['errors'];
        final errs = <String>[];
        if (rawErrs is List) {
          for (final e in rawErrs) {
            if (e == null) continue;
            if (e is String) {
              if (e.trim().isNotEmpty) errs.add(e.trim());
            } else if (e is Map) {
              final msg = (e['error'] ?? e['message'] ?? e['detail'] ?? e).toString();
              if (msg.trim().isNotEmpty) errs.add(msg.trim());
            } else {
              final msg = e.toString();
              if (msg.trim().isNotEmpty) errs.add(msg.trim());
            }
          }
        }
        setState(() {
          _imported = res['imported'] as int? ?? 0;
          _updated = res['updated'] as int? ?? 0;
          _failed = res['failed'] as int? ?? 0;
          _errors = errs;
          _activeJobId = null;
          _activeJobStatus = '';
          _jobProcessedRows = null;
          _jobTotalRows = null;
          _loading = false;
          _step = 3;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _step == 1
            ? 'Import CSV'
            : _step == 2
                ? 'Preview & validate'
                : (_activeJobId != null &&
                        !const {'completed', 'failed', 'cancelled'}.contains(_activeJobStatus))
                    ? 'Import in progress'
                    : 'Import complete',
      ),
      content: SizedBox(
        width: 540,
        child: _step == 1
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _pickFile,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: NeyvoColors.borderDefault),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file, size: 24, color: NeyvoColors.textMuted),
                            const SizedBox(height: 8),
                            Text('Drop your student CSV file here', style: NeyvoType.bodyMedium),
                            Text('or click to browse (.csv only)', style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
              Text(
                'Required: name or first_name, and phone. Optional: last_name, student_id, email, department, year_of_study, balance, due_date, late_fee, notes. Duplicates are detected by student_id, then phone, then email.',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download template CSV'),
                  ),
                ],
              )
            : _step == 2
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${_validRows.length} students ready', style: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.success)),
                          if (_errorLines.isNotEmpty) Text(' | ${_errorLines.length} errors', style: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.error)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_validRows.isNotEmpty) ...[
                        Text('First 5 rows:', style: NeyvoType.labelSmall),
                        const SizedBox(height: 4),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(1.5),
                              2: FlexColumnWidth(1.5),
                              3: FlexColumnWidth(1.2),
                              4: FlexColumnWidth(1.2),
                            },
                            children: [
                              TableRow(children: [
                                Text('Name', style: NeyvoType.labelSmall),
                                Text('Phone', style: NeyvoType.labelSmall),
                                Text('Email', style: NeyvoType.labelSmall),
                                Text('Department', style: NeyvoType.labelSmall),
                                Text('Year', style: NeyvoType.labelSmall),
                              ]),
                              ..._validRows.take(5).map((r) {
                                String g(List<String> k) {
                                  for (final key in r.keys) {
                                    for (final kk in k) {
                                      if (key.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') == kk.toLowerCase()) return r[key] ?? '';
                                    }
                                  }
                                  return '';
                                }
                                return TableRow(children: [
                                  Text(g(['name', 'student_name', 'first_name']), style: NeyvoType.bodySmall),
                                  Text(g(['phone', 'mobile']), style: NeyvoType.bodySmall),
                                  Text(g(['email']), style: NeyvoType.bodySmall),
                                  Text(g(['department']), style: NeyvoType.bodySmall),
                                  Text(g(['year_of_study', 'year']), style: NeyvoType.bodySmall),
                                ]);
                              }),
                            ],
                          ),
                        ),
                      ],
                      if (_errorLines.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ExpansionTile(
                          title: Text('Show ${_errorLines.length} errors', style: NeyvoType.labelSmall.copyWith(color: NeyvoColors.error)),
                          children: _errorLines.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(e, style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.error, fontSize: 13)),
                          )).toList(),
                        ),
                      ],
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_activeJobId != null &&
                          !const {'completed', 'failed', 'cancelled'}.contains(_activeJobStatus))
                        ...[
                          Icon(Icons.cloud_upload_outlined, size: 32, color: NeyvoTheme.primary),
                          const SizedBox(height: 12),
                          Text('Import in progress', style: NeyvoType.titleMedium),
                          const SizedBox(height: 8),
                          _jobTotalRows != null && _jobTotalRows! > 0
                              ? LinearProgressIndicator(
                                  value: ((_jobProcessedRows ?? 0) / _jobTotalRows!).clamp(0.0, 1.0),
                                )
                              : const LinearProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(
                            '${_jobProcessedRows ?? 0} processed${_jobTotalRows != null ? ' / $_jobTotalRows' : ''}',
                            style: NeyvoType.bodyMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Status: $_activeJobStatus',
                            style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textSecondary),
                          ),
                        ]
                      else ...[
                        Icon(Icons.check_circle, size: 32, color: NeyvoColors.success),
                        const SizedBox(height: 12),
                        Text('Import complete', style: NeyvoType.titleMedium),
                        const SizedBox(height: 8),
                        Text('${_imported ?? 0} students imported | ${_updated ?? 0} updated', style: NeyvoType.bodyMedium),
                        if ((_failed ?? 0) > 0)
                          Text('${_failed} rows skipped', style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.error)),
                        if (_errors.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ExpansionTile(
                            title: Text('Show ${_errors.length} import errors', style: NeyvoType.labelSmall.copyWith(color: NeyvoColors.error)),
                            children: _errors
                                .take(50)
                                .map((e) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(e, style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.error, fontSize: 13)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ],
                  ),
      ),
      actions: [
        if (_step == 1)
          TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        if (_step == 2) ...[
          TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
          FilledButton(
            onPressed: _loading || _validRows.isEmpty ? null : _doImport,
            child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Import ${_validRows.length} Students'),
          ),
        ],
        if (_step == 3) ...[
          if (_activeJobId != null && !const {'completed', 'failed', 'cancelled'}.contains(_activeJobStatus))
            TextButton(
              onPressed: () async {
                try {
                  await NeyvoPulseApi.cancelStudentsImportJob(_activeJobId!);
                } catch (_) {}
              },
              child: const Text('Cancel'),
            ),
          TextButton(
            onPressed: const {'completed', 'failed', 'cancelled'}.contains(_activeJobStatus)
                ? () {
                    widget.onDone();
                  }
                : null,
            child: const Text('View Students'),
          ),
          FilledButton(
            onPressed: const {'completed', 'failed', 'cancelled'}.contains(_activeJobStatus)
                ? () {
                    setState(() {
                      _step = 1;
                      _csvText = '';
                      _imported = null;
                      _updated = null;
                      _failed = null;
                      _errors = [];
                      _validRows = [];
                      _errorLines = [];
                      _activeJobId = null;
                      _activeJobStatus = '';
                      _jobProcessedRows = null;
                      _jobTotalRows = null;
                    });
                  }
                : null,
            child: const Text('Import Another'),
          ),
        ],
      ],
    );
  }
}
