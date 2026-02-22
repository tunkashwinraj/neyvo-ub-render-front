// lib/screens/students_list_page.dart
// Enhanced students list with search, filter, and quick actions

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../utils/export_csv.dart';
import '../utils/csv_import.dart';
import '../../theme/spearia_theme.dart';
import 'student_detail_page.dart';

class StudentsListPage extends StatefulWidget {
  const StudentsListPage({super.key});

  @override
  State<StudentsListPage> createState() => _StudentsListPageState();
}

class _StudentsListPageState extends State<StudentsListPage> {
  List<dynamic> _allStudents = [];
  List<dynamic> _filteredStudents = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _filterStatus = 'all'; // all, overdue, with_balance
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStudents);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await NeyvoPulseApi.listStudents();
      final list = res['students'] as List? ?? [];
      if (mounted) {
        setState(() {
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

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((s) {
        final name = (s['name']?.toString() ?? '').toLowerCase();
        final phone = (s['phone']?.toString() ?? '').toLowerCase();
        final email = (s['email']?.toString() ?? '').toLowerCase();
        final matchesSearch = query.isEmpty || 
            name.contains(query) || 
            phone.contains(query) || 
            email.contains(query);
        
        if (!matchesSearch) return false;
        
        if (_filterStatus == 'all') return true;
        if (_filterStatus == 'overdue') {
          final dueDate = s['due_date']?.toString() ?? '';
          return dueDate.isNotEmpty;
        }
        if (_filterStatus == 'with_balance') {
          final balance = s['balance']?.toString() ?? '';
          return balance.isNotEmpty && balance != '\$0' && balance != '0';
        }
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
              const SizedBox(height: SpeariaSpacing.md),
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
      await NeyvoPulseApi.startOutboundCall(
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
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode ? '${_selectedIds.length} selected' : 'Contacts'),
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
                  onPressed: _importCsv,
                  tooltip: 'Import contacts from CSV',
                ),
                IconButton(
                  icon: const Icon(Icons.checklist),
                  onPressed: () => setState(() => _selectionMode = true),
                  tooltip: 'Select contacts',
                ),
              ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
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
                const SizedBox(height: SpeariaSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filterStatus == 'all',
                        onTap: () {
                          setState(() => _filterStatus = 'all');
                          _filterStudents();
                        },
                      ),
                      const SizedBox(width: SpeariaSpacing.sm),
                      _FilterChip(
                        label: 'With Balance',
                        selected: _filterStatus == 'with_balance',
                        onTap: () {
                          setState(() => _filterStatus = 'with_balance');
                          _filterStudents();
                        },
                      ),
                      const SizedBox(width: SpeariaSpacing.sm),
                      _FilterChip(
                        label: 'Overdue',
                        selected: _filterStatus == 'overdue',
                        onTap: () {
                          setState(() => _filterStatus = 'overdue');
                          _filterStudents();
                        },
                      ),
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
                          Icon(Icons.school_outlined, size: 64, color: SpeariaAura.textMuted),
                          const SizedBox(height: SpeariaSpacing.md),
                          Text(
                            _allStudents.isEmpty ? 'No contacts yet' : 'No contacts found',
                            style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted),
                          ),
                          if (_allStudents.isEmpty) ...[
                            const SizedBox(height: SpeariaSpacing.lg),
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
                      padding: const EdgeInsets.all(SpeariaSpacing.md),
                      itemCount: _filteredStudents.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.all(SpeariaSpacing.md),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Contacts (${_filteredStudents.length})',
                                  style: SpeariaType.headlineMedium,
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
                        final isOverdue = dueDate.isNotEmpty;
                        
                        final selected = _selectedIds.contains(id);
                        return Card(
                          margin: const EdgeInsets.only(bottom: SpeariaSpacing.sm),
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
                              padding: const EdgeInsets.all(SpeariaSpacing.md),
                              child: Row(
                                children: [
                                  if (_selectionMode)
                                    Padding(
                                      padding: const EdgeInsets.only(right: SpeariaSpacing.sm),
                                      child: Checkbox(
                                        value: selected,
                                        onChanged: (_) => _toggleSelection(id),
                                        activeColor: SpeariaAura.primary,
                                      ),
                                    ),
                                  CircleAvatar(
                                    backgroundColor: SpeariaAura.primary.withOpacity(0.1),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: TextStyle(color: SpeariaAura.primary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: SpeariaSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: SpeariaType.titleMedium),
                                        const SizedBox(height: 2),
                                        Text(phone, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary)),
                                        if (dueDate.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Row(
                                              children: [
                                                Icon(Icons.calendar_today, size: 12, color: isOverdue ? SpeariaAura.warning : SpeariaAura.textMuted),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Due: $dueDate',
                                                  style: SpeariaType.bodySmall.copyWith(
                                                    color: isOverdue ? SpeariaAura.warning : SpeariaAura.textSecondary,
                                                  ),
                                                ),
                                              ],
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
                                          style: SpeariaType.titleMedium.copyWith(
                                            color: SpeariaAura.accent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      const SizedBox(height: SpeariaSpacing.xs),
                                      IconButton(
                                        icon: const Icon(Icons.phone, size: 20),
                                        color: SpeariaAura.primary,
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddStudent,
        child: const Icon(Icons.add),
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
              Text('Found ${rows.length} row(s). First 5:', style: SpeariaType.titleMedium),
              const SizedBox(height: SpeariaSpacing.sm),
              ...preview.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(p, style: SpeariaType.bodySmall),
              )),
              const SizedBox(height: SpeariaSpacing.md),
              Text('Required columns: name (or Name), phone (or Phone). Optional: email, balance, due_date, late_fee, notes.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary)),
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
    final navigator = Navigator.of(context);
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: phoneC, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone *')),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: emailC, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (optional)')),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: balanceC, decoration: const InputDecoration(labelText: 'Balance (optional)', hintText: '\$1,000')),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: dueDateC, decoration: const InputDecoration(labelText: 'Due Date (optional)', hintText: '2026-02-25')),
              const SizedBox(height: SpeariaSpacing.md),
              TextField(controller: lateFeeC, decoration: const InputDecoration(labelText: 'Late Fee (optional)', hintText: '\$75')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => navigator.pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameC.text.trim();
              final phone = phoneC.text.trim();
              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and phone required')));
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
      selectedColor: SpeariaAura.primary.withOpacity(0.2),
      checkmarkColor: SpeariaAura.primary,
    );
  }
}
