// lib/screens/students_list_page.dart
// Enhanced students list with search, filter, and quick actions

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../api/spearia_api.dart';
import '../neyvo_pulse_api.dart';
import '../utils/export_csv.dart';
import '../utils/csv_import.dart';
import '../utils/phone_util.dart';
import '../theme/neyvo_theme.dart';
import 'student_detail_page.dart';

class StudentsListPage extends StatefulWidget {
  const StudentsListPage({super.key});

  @override
  State<StudentsListPage> createState() => _StudentsListPageState();
}

class _StudentsListPageState extends State<StudentsListPage> with SingleTickerProviderStateMixin {
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
    _searchController.addListener(_filterStudents);
    _subTabController = TabController(length: 2, vsync: this);
    _subTabController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _subTabController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    setState(() => _remindersLoading = true);
    try {
      final res = await NeyvoPulseApi.listReminders();
      if (mounted) setState(() {
        _reminders = res['reminders'] as List? ?? res['data'] as List? ?? [];
        _remindersLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _reminders = []; _remindersLoading = false; });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final agentsRes = await NeyvoPulseApi.listAgents();
      final agents = (agentsRes['agents'] as List? ?? []).cast<Map<String, dynamic>>();
      final isEducation = agents.any((a) =>
          (a['industry']?.toString().toLowerCase() ?? '') == 'education');
      final firstAgentId = agents.isNotEmpty ? (agents.first['id'] ?? agents.first['agent_id'])?.toString() : null;

      bool? hasBalance;
      bool? isOverdue;
      String? dueAfter;
      String? dueBefore;
      if (isEducation && _filterStatus != 'all') {
        if (_filterStatus == 'with_balance') hasBalance = true;
        else if (_filterStatus == 'overdue') isOverdue = true;
        else if (_filterStatus == 'due_this_week') {
          final now = DateTime.now();
          dueAfter = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final end = now.add(const Duration(days: 7));
          dueBefore = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
        } else if (_filterStatus == 'no_balance') hasBalance = false;
      }
      final res = await NeyvoPulseApi.listStudents(
        hasBalance: hasBalance,
        isOverdue: isOverdue,
        dueAfter: dueAfter,
        dueBefore: dueBefore,
      );
      final list = res['students'] as List? ?? [];
      if (mounted) {
        setState(() {
          _isEducationOrg = isEducation;
          _agents = agents;
          _selectedAgentId ??= (firstAgentId?.trim().isEmpty ?? true) ? null : firstAgentId?.trim();
          _allStudents = list;
          _filteredStudents = list;
          _loading = false;
        });
        _filterStudents();
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

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

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((s) {
        final name = (s['name']?.toString() ?? '').toLowerCase();
        final phone = (s['phone']?.toString() ?? '').toLowerCase();
        final email = (s['email']?.toString() ?? '').toLowerCase();
        final studentId = (s['student_id']?.toString() ?? '').toLowerCase();
        final matchesSearch = query.isEmpty ||
            name.contains(query) ||
            phone.contains(query) ||
            email.contains(query) ||
            studentId.contains(query);
        if (!matchesSearch) return false;

        if (_filterStatus == 'all') return true;
        if (_filterStatus == 'with_balance') return _hasBalance(s);
        if (_filterStatus == 'overdue') return _isOverdue(s);
        if (_filterStatus == 'due_this_week') return _isDueThisWeek(s);
        if (_filterStatus == 'no_balance') return !_hasBalance(s);
        return true;
      }).toList();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  List<Map<String, dynamic>> _getSelectedStudents() {
    return _filteredStudents
        .where((s) => _selectedIds.contains(s['id']?.toString()))
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
    sb.writeln('Id,Name,Phone,Email,Balance,Due Date,Late Fee');
    for (final s in list) {
      final id = s['id']?.toString() ?? '';
      final name = (s['name']?.toString() ?? '').replaceAll(',', ';');
      final phone = s['phone']?.toString() ?? '';
      final email = (s['email']?.toString() ?? '').replaceAll(',', ';');
      final balance = s['balance']?.toString() ?? '';
      final dueDate = s['due_date']?.toString() ?? '';
      final lateFee = s['late_fee']?.toString() ?? '';
      sb.writeln('"$id","$name","$phone","$email","$balance","$dueDate","$lateFee"');
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
    final name = student['name']?.toString() ?? '';
    if (phone.isEmpty || name.isEmpty) {
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
                  onPressed: () => setState(() => _selectionMode = true),
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
          ? FloatingActionButton(onPressed: _openAddStudent, child: const Icon(Icons.add))
          : FloatingActionButton(
              onPressed: () => _openScheduleReminderModal(),
              child: const Icon(Icons.add_alarm),
            )),
    );
  }

  Widget _buildStudentsTab() {
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
                          setState(() => _filterStatus = 'all');
                          _load();
                        },
                      ),
                      const SizedBox(width: NeyvoSpacing.sm),
                      _FilterChip(
                        label: 'With Balance',
                        selected: _filterStatus == 'with_balance',
                        onTap: () {
                          setState(() => _filterStatus = 'with_balance');
                          _load();
                        },
                      ),
                      const SizedBox(width: NeyvoSpacing.sm),
                      _FilterChip(
                        label: 'Overdue',
                        selected: _filterStatus == 'overdue',
                        onTap: () {
                          setState(() => _filterStatus = 'overdue');
                          _load();
                        },
                      ),
                      if (_isEducationOrg) ...[
                        const SizedBox(width: NeyvoSpacing.sm),
                        _FilterChip(
                          label: 'Due This Week',
                          selected: _filterStatus == 'due_this_week',
                          onTap: () {
                            setState(() => _filterStatus = 'due_this_week');
                            _load();
                          },
                        ),
                        const SizedBox(width: NeyvoSpacing.sm),
                        _FilterChip(
                          label: 'No Balance',
                          selected: _filterStatus == 'no_balance',
                          onTap: () {
                            setState(() => _filterStatus = 'no_balance');
                            _load();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Students List
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
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(NeyvoSpacing.md),
                      itemCount: _filteredStudents.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.all(NeyvoSpacing.md),
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
                                      setState(() => _filterStatus = 'all');
                                      _filterStudents();
                                    },
                                    child: const Text('Clear filters'),
                                  ),
                              ],
                            ),
                          );
                        }
                        final s = _filteredStudents[i - 1] as Map<String, dynamic>;
                        final id = s['id'] as String? ?? '';
                        final name = s['name'] as String? ?? '—';
                        final phone = s['phone'] as String? ?? '';
                        final balance = s['balance'] as String? ?? '';
                        final dueDate = s['due_date']?.toString() ?? '';
                        final isOverdue = _isOverdue(s);
                        final lastCallDate = s['last_call_date']?.toString() ?? '';
                        final lastCallOutcome = s['last_call_outcome']?.toString() ?? '';
                        
                        final selected = _selectedIds.contains(id);
                        return Card(
                          margin: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                          child: InkWell(
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
                            child: Padding(
                              padding: const EdgeInsets.all(NeyvoSpacing.md),
                              child: Row(
                                children: [
                                  if (_selectionMode)
                                    Padding(
                                      padding: const EdgeInsets.only(right: NeyvoSpacing.sm),
                                      child: Checkbox(
                                        value: selected,
                                        onChanged: (_) => _toggleSelection(id),
                                        activeColor: NeyvoTheme.primary,
                                      ),
                                    ),
                                  CircleAvatar(
                                    backgroundColor: NeyvoTheme.primary.withOpacity(0.1),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: TextStyle(color: NeyvoTheme.primary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: NeyvoSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: NeyvoType.titleMedium),
                                        const SizedBox(height: 2),
                                        Text(phone, style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textSecondary)),
                                        if (isOverdue && _isEducationOrg)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: NeyvoColors.error.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Overdue',
                                                style: NeyvoType.labelSmall.copyWith(
                                                  color: NeyvoColors.error,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (dueDate.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Row(
                                              children: [
                                                Icon(Icons.calendar_today, size: 12, color: isOverdue ? NeyvoColors.error : NeyvoColors.textMuted),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Due: $dueDate',
                                                  style: NeyvoType.bodySmall.copyWith(
                                                    color: isOverdue ? NeyvoColors.error : NeyvoColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (lastCallDate.isNotEmpty && _isEducationOrg)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Last call: $lastCallDate${lastCallOutcome.isNotEmpty ? ' ($lastCallOutcome)' : ''}',
                                              style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textMuted, fontSize: 11),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (balance.isNotEmpty)
                                        Text(
                                          balance,
                                          style: NeyvoType.titleMedium.copyWith(
                                            color: NeyvoTheme.accent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      const SizedBox(height: NeyvoSpacing.xs),
                                      IconButton(
                                        icon: const Icon(Icons.phone, size: 20),
                                        color: NeyvoTheme.primary,
                                        onPressed: () => _quickCall(s),
                                        tooltip: 'Reach out to contact',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      );
  }

  Widget _buildRemindersTab() {
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
                              setState(() {});
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
                    items: _allStudents.map((s) => DropdownMenuItem(value: s['id']?.toString(), child: Text(s['name']?.toString() ?? '—'))).toList(),
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
                      setState(() {});
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
    final preview = rows.take(5).map((r) => get(r, ['name', 'name']) + ' | ' + get(r, ['phone', 'phone', 'mobile'])).toList();
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
              Text('Required columns: name (or Name), phone (or Phone). Optional: email, balance, due_date, late_fee, notes.', style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textSecondary)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => navigator.pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => navigator.pop(true), child: const Text('Import')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    int created = 0;
    for (final r in rows) {
      final name = get(r, ['name']);
      final phone = get(r, ['phone', 'mobile', 'cell']);
      if (name.isEmpty || phone.isEmpty) continue;
      try {
        await NeyvoPulseApi.createStudent(
          name: name,
          phone: phone,
          email: get(r, ['email']).isEmpty ? null : get(r, ['email']),
          balance: get(r, ['balance']).isEmpty ? null : get(r, ['balance']),
          dueDate: get(r, ['due_date', 'duedate', 'due date']).isEmpty ? null : get(r, ['due_date', 'duedate', 'due date']),
          lateFee: get(r, ['late_fee', 'latefee']).isEmpty ? null : get(r, ['late_fee', 'latefee']),
          studentId: get(r, ['student_id', 'student id']).isEmpty ? null : get(r, ['student_id', 'student id']),
          notes: get(r, ['notes', 'note']).isEmpty ? null : get(r, ['notes', 'note']),
        );
        created++;
      } catch (_) {}
    }
    if (mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $created contact(s)')),
      );
    }
  }

  Future<void> _openAddStudent() async {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final emailC = TextEditingController();
    final balanceC = TextEditingController();
    final dueDateC = TextEditingController();
    final lateFeeC = TextEditingController();
    final studentIdC = TextEditingController();
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
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name *', hintText: 'Full name')),
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
              TextField(controller: studentIdC, decoration: const InputDecoration(labelText: 'Student / Contact ID (optional)', hintText: 'Internal ID or reference')),
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
            onPressed: () async {
              final name = nameC.text.trim();
              final phoneRaw = phoneC.text.trim();
              final phone = normalizePhoneInput(phoneRaw);
              if (name.isEmpty || phoneRaw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and phone required')));
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
                  email: emailC.text.trim().isEmpty ? null : emailC.text.trim(),
                  balance: balanceC.text.trim().isEmpty ? null : balanceC.text.trim(),
                  dueDate: dueDateC.text.trim().isEmpty ? null : dueDateC.text.trim(),
                  lateFee: lateFeeC.text.trim().isEmpty ? null : lateFeeC.text.trim(),
                  studentId: studentIdC.text.trim().isEmpty ? null : studentIdC.text.trim(),
                  notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
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
      final name = getVal(r, ['name', 'student_name']);
      final phone = getVal(r, ['phone', 'mobile', 'cell']);
      if (name.isEmpty) {
        errs.add('Row ${i + 2}: Missing name');
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
      final url = '${SpeariaApi.baseUrl}/api/pulse/students/import/template';
      final ok = await SpeariaApi.launchExternal(url);
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
          const SnackBar(content: Text('Template: name,phone,email,student_id,balance,due_date,late_fee,notes')),
        );
      }
    }
  }

  Future<void> _doImport() async {
    setState(() => _loading = true);
    try {
      final res = await NeyvoPulseApi.postStudentsImportCsv(_csvText);
      if (mounted) {
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
      title: Text(_step == 1 ? 'Import CSV' : _step == 2 ? 'Preview & validate' : 'Import complete'),
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
                    'Required columns: name, phone. The first non-comment row must be the header (name, phone, …). Lines starting with # and blank rows are ignored.',
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
                        Table(
                          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1.5)},
                          children: [
                            TableRow(children: [
                              Text('Name', style: NeyvoType.labelSmall),
                              Text('Phone', style: NeyvoType.labelSmall),
                              Text('Balance', style: NeyvoType.labelSmall),
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
                                Text(g(['name', 'student_name']), style: NeyvoType.bodySmall),
                                Text(g(['phone', 'mobile']), style: NeyvoType.bodySmall),
                                Text(g(['balance']), style: NeyvoType.bodySmall),
                              ]);
                            }),
                          ],
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
                      Icon(Icons.check_circle, size: 32, color: NeyvoColors.success),
                      const SizedBox(height: 12),
                      Text('Import complete', style: NeyvoType.titleMedium),
                      const SizedBox(height: 8),
                      Text('${_imported ?? 0} students imported | ${_updated ?? 0} updated', style: NeyvoType.bodyMedium),
                      if ((_failed ?? 0) > 0) Text('${_failed} rows skipped', style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.error)),
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
          TextButton(onPressed: () { widget.onDone(); }, child: const Text('View Students')),
          FilledButton(
            onPressed: () {
              setState(() {
                _step = 1;
                _csvText = '';
                _imported = null;
                _updated = null;
                _failed = null;
                _errors = [];
                _validRows = [];
                _errorLines = [];
              });
            },
            child: const Text('Import Another'),
          ),
        ],
      ],
    );
  }
}
