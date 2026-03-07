// lib/screens/students_hub_page.dart
// Students hub: Directory, Import, Sync tabs (single control plane).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/spearia_api.dart';
import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';
import '../utils/csv_import.dart';
import 'student_detail_page.dart';

class StudentsHubPage extends StatefulWidget {
  const StudentsHubPage({super.key});

  @override
  State<StudentsHubPage> createState() => _StudentsHubPageState();
}

class _StudentsHubPageState extends State<StudentsHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<_DirectoryTabState> _directoryKey = GlobalKey<_DirectoryTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Directory'),
            Tab(text: 'Import'),
            Tab(text: 'Sync'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DirectoryTab(key: _directoryKey),
          _ImportTab(key: const ValueKey('import')),
          _SyncTab(key: const ValueKey('sync')),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => _directoryKey.currentState?.openAddStudentDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// --- Directory tab ---

class _DirectoryTab extends StatefulWidget {
  const _DirectoryTab({super.key});

  @override
  State<_DirectoryTab> createState() => _DirectoryTabState();
}

class _DirectoryTabState extends State<_DirectoryTab> {
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _loading = true;
  String? _error;
  bool _isEducationOrg = false;
  final _searchController = TextEditingController();
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStudents);
    _load();
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

  Future<void> openAddStudentDialog() async {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final emailC = TextEditingController();
    final balanceC = TextEditingController();
    final dueDateC = TextEditingController();
    final lateFeeC = TextEditingController();
    final studentIdC = TextEditingController();
    final notesC = TextEditingController();

    final navigator = Navigator.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add student'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 560, maxWidth: 720),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: nameC,
                            decoration: const InputDecoration(
                              labelText: 'Name *',
                              hintText: 'Full name',
                            ),
                          ),
                          const SizedBox(height: NeyvoSpacing.md),
                          TextField(
                            controller: phoneC,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone *',
                              hintText: '10 digits, US (+1)',
                            ),
                          ),
                          const SizedBox(height: NeyvoSpacing.md),
                          TextField(
                            controller: emailC,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email (optional)',
                              hintText: 'Email address',
                            ),
                          ),
                          const SizedBox(height: NeyvoSpacing.md),
                          TextField(
                            controller: studentIdC,
                            decoration: const InputDecoration(
                              labelText: 'Student / Contact ID (optional)',
                              hintText: 'Internal ID or reference',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: NeyvoSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: balanceC,
                            decoration: const InputDecoration(
                              labelText: 'Balance (optional)',
                              hintText: '\$1,000',
                            ),
                          ),
                          const SizedBox(height: NeyvoSpacing.md),
                          TextField(
                            controller: dueDateC,
                            decoration: const InputDecoration(
                              labelText: 'Due Date (optional)',
                              hintText: '2026-02-25',
                            ),
                          ),
                          const SizedBox(height: NeyvoSpacing.md),
                          TextField(
                            controller: lateFeeC,
                            decoration: const InputDecoration(
                              labelText: 'Late Fee (optional)',
                              hintText: '\$75',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: NeyvoSpacing.lg),
                TextField(
                  controller: notesC,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Reason for call, follow-up notes...',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameC.text.trim();
              final phoneRaw = phoneC.text.trim();
              if (name.isEmpty || phoneRaw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and phone required')),
                );
                return;
              }
              final phone = _normalizePhoneUs(phoneRaw);
              try {
                await NeyvoPulseApi.createStudent(
                  name: name,
                  phone: phone,
                  email: emailC.text.trim().isEmpty ? null : emailC.text.trim(),
                  balance:
                      balanceC.text.trim().isEmpty ? null : balanceC.text.trim(),
                  dueDate: dueDateC.text.trim().isEmpty ? null : dueDateC.text.trim(),
                  lateFee:
                      lateFeeC.text.trim().isEmpty ? null : lateFeeC.text.trim(),
                  studentId: studentIdC.text.trim().isEmpty
                      ? null
                      : studentIdC.text.trim(),
                  notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                );
                if (!context.mounted) return;
                navigator.pop();
                await _load();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    nameC.dispose();
    phoneC.dispose();
    emailC.dispose();
    balanceC.dispose();
    dueDateC.dispose();
    lateFeeC.dispose();
    studentIdC.dispose();
    notesC.dispose();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static bool _isOverdue(Map<String, dynamic> s) {
    final dueStr = s['due_date']?.toString().trim() ?? '';
    if (dueStr.isEmpty) return false;
    final balanceStr =
        (s['balance']?.toString() ?? '').replaceAll(RegExp(r'[\$,]'), '').trim();
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
    final balance =
        (s['balance']?.toString() ?? '').replaceAll(RegExp(r'[\$,]'), '').trim();
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
        final extId = (s['external_id']?.toString() ?? '').toLowerCase();
        final matchesSearch = query.isEmpty ||
            name.contains(query) ||
            phone.contains(query) ||
            email.contains(query) ||
            studentId.contains(query) ||
            extId.contains(query);
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final agentsRes = await NeyvoPulseApi.listAgents();
      final agents =
          (agentsRes['agents'] as List? ?? []).cast<Map<String, dynamic>>();
      final isEducation = agents.any((a) =>
          (a['industry']?.toString().toLowerCase() ?? '') == 'education');

      bool? hasBalance;
      bool? isOverdue;
      String? dueAfter;
      String? dueBefore;
      if (isEducation && _filterStatus != 'all') {
        if (_filterStatus == 'with_balance') hasBalance = true;
        else if (_filterStatus == 'overdue') isOverdue = true;
        else if (_filterStatus == 'due_this_week') {
          final now = DateTime.now();
          dueAfter =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final end = now.add(const Duration(days: 7));
          dueBefore =
              '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
        } else if (_filterStatus == 'no_balance') hasBalance = false;
      }
      final res = await NeyvoPulseApi.listStudents(
        hasBalance: hasBalance,
        isOverdue: isOverdue,
        dueAfter: dueAfter,
        dueBefore: dueBefore,
      );
      final list = (res['students'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) {
        setState(() {
          _isEducationOrg = isEducation;
          _allStudents = list;
          _filteredStudents = list;
          _loading = false;
        });
        _filterStudents();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(NeyvoSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: NeyvoType.bodySmall
                    .copyWith(color: NeyvoColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: NeyvoSpacing.lg),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
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
                  hintText: 'Search by name, phone, or student ID...',
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
                      label: 'Balance > 0',
                      selected: _filterStatus == 'with_balance',
                      onTap: () {
                        setState(() => _filterStatus = 'with_balance');
                        _load();
                      },
                    ),
                    const SizedBox(width: NeyvoSpacing.sm),
                    _FilterChip(
                      label: 'Overdue only',
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
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _filteredStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.school_outlined,
                            size: 64, color: NeyvoColors.textMuted),
                        const SizedBox(height: NeyvoSpacing.md),
                        Text(
                          _allStudents.isEmpty
                              ? 'No students yet'
                              : 'No students found',
                          style: NeyvoType.bodyMedium
                              .copyWith(color: NeyvoColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(NeyvoSpacing.md),
                    itemCount: _filteredStudents.length,
                    itemBuilder: (context, i) {
                      final s = _filteredStudents[i];
                      final id = s['id'] as String? ?? '';
                      final name = s['name'] as String? ?? '—';
                      final phone = s['phone'] as String? ?? '';
                      final balance = s['balance'] as String? ?? '';
                      final dueDate = s['due_date']?.toString() ?? '';
                      final studentId =
                          s['student_id']?.toString() ?? s['external_id']?.toString() ?? '—';
                      final isOverdue = _isOverdue(s);
                      final program = s['program']?.toString() ?? s['major']?.toString() ?? '—';
                      final lastContact =
                          s['last_call_date']?.toString() ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentDetailPage(
                                  studentId: id,
                                  onUpdated: _load,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(NeyvoSpacing.md),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      NeyvoTheme.primary.withOpacity(0.1),
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                        color: NeyvoTheme.primary,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: NeyvoSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: NeyvoType.titleMedium),
                                      const SizedBox(height: 2),
                                      Text(
                                        'ID: $studentId · $phone',
                                        style: NeyvoType.bodySmall.copyWith(
                                            color:
                                                NeyvoColors.textSecondary),
                                      ),
                                      if (program != '—')
                                        Text(
                                          'Program: $program',
                                          style: NeyvoType.bodySmall
                                              .copyWith(
                                                  color:
                                                      NeyvoColors.textMuted),
                                        ),
                                      if (isOverdue && _isEducationOrg)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 4),
                                          child: Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 8,
                                                vertical: 2),
                                            decoration: BoxDecoration(
                                              color: NeyvoColors.error
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Overdue',
                                              style: NeyvoType.labelSmall
                                                  .copyWith(
                                                      color: NeyvoColors
                                                          .error,
                                                      fontSize: 11),
                                            ),
                                          ),
                                        ),
                                      if (dueDate.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 4),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 12,
                                                color: isOverdue
                                                    ? NeyvoColors.error
                                                    : NeyvoColors.textMuted,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Due: $dueDate',
                                                style: NeyvoType.bodySmall
                                                    .copyWith(
                                                      color: isOverdue
                                                          ? NeyvoColors.error
                                                          : NeyvoColors
                                                              .textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (lastContact.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 2),
                                          child: Text(
                                            'Last contact: $lastContact',
                                            style: NeyvoType.bodySmall
                                                .copyWith(
                                                    color:
                                                        NeyvoColors.textMuted,
                                                    fontSize: 11),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (balance.isNotEmpty)
                                  Text(
                                    balance,
                                    style: NeyvoType.titleMedium.copyWith(
                                        color: NeyvoTheme.accent,
                                        fontWeight: FontWeight.w600),
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

// --- Import tab ---

class _ImportTab extends StatefulWidget {
  const _ImportTab({super.key});

  @override
  State<_ImportTab> createState() => _ImportTabState();
}

class _ImportTabState extends State<_ImportTab> {
  int _step = 1;
  String _csvText = '';
  bool _loading = false;
  int? _imported;
  int? _updated;
  int? _failed;
  List<Map<String, dynamic>> _errors = [];
  List<Map<String, String>> _validRows = [];
  List<String> _errorLines = [];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.single.bytes == null) return;
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
      setState(() {});
      return;
    }
    final valid = <Map<String, String>>[];
    final errs = <String>[];
    String getVal(Map<String, String> r, List<String> keys) {
      for (final k in keys) {
        for (final key in r.keys) {
          if (key
                  .toLowerCase()
                  .replaceAll(RegExp(r'[\s_\-]'), '') ==
              k.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '')) {
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
    if (kIsWeb) {
      final url =
          '${SpeariaApi.baseUrl}/api/pulse/students/import/template';
      final ok = await SpeariaApi.launchExternal(url);
      if (ok) return;
    }
    try {
      final template =
          await NeyvoPulseApi.getStudentsImportTemplate();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Template CSV'),
          content: SingleChildScrollView(
            child: SelectableText(template,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12)),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Template: name,phone,email,student_id,balance,due_date,late_fee,notes')),
        );
      }
    }
  }

  Future<void> _doImport() async {
    setState(() => _loading = true);
    try {
      final res = await NeyvoPulseApi.postStudentsImportCsv(_csvText);
      if (!mounted) return;
      setState(() {
        _imported = res['imported'] as int? ?? 0;
        _updated = res['updated'] as int? ?? 0;
        _failed = res['failed'] as int? ?? 0;
        _errors = List<Map<String, dynamic>>.from(
            (res['errors'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map)));
        _loading = false;
        _step = 3;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _step == 1
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Import students from CSV',
                      style: NeyvoType.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload a CSV file with columns: name, phone, and optionally email, student_id, balance, due_date, late_fee, notes.',
                      style: NeyvoType.bodyMedium.copyWith(
                          color: NeyvoColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: _pickFile,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: NeyvoColors.borderDefault),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file,
                                  size: 32,
                                  color: NeyvoColors.textMuted),
                              const SizedBox(height: 8),
                              Text('Drop your CSV here or tap to browse',
                                  style: NeyvoType.bodyMedium),
                              Text('.csv only',
                                  style: NeyvoType.bodySmall.copyWith(
                                      color: NeyvoColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
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
                            Text(
                              '${_validRows.length} students ready',
                              style: NeyvoType.bodyMedium
                                  .copyWith(color: NeyvoColors.success),
                            ),
                            if (_errorLines.isNotEmpty)
                              Text(
                                ' · ${_errorLines.length} errors',
                                style: NeyvoType.bodyMedium
                                    .copyWith(color: NeyvoColors.error),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_validRows.isNotEmpty) ...[
                          Text('First 5 rows:',
                              style: NeyvoType.labelSmall),
                          const SizedBox(height: 4),
                          Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(2),
                              2: FlexColumnWidth(1.5),
                            },
                            children: [
                              TableRow(
                                children: [
                                  Text('Name',
                                      style: NeyvoType.labelSmall),
                                  Text('Phone',
                                      style: NeyvoType.labelSmall),
                                  Text('Balance',
                                      style: NeyvoType.labelSmall),
                                ],
                              ),
                              ..._validRows.take(5).map((r) {
                                String g(List<String> k) {
                                  for (final key in r.keys) {
                                    for (final kk in k) {
                                      if (key
                                              .toLowerCase()
                                              .replaceAll(
                                                  RegExp(r'[\s_\-]'),
                                                  '') ==
                                          kk.toLowerCase()) {
                                        return r[key] ?? '';
                                      }
                                    }
                                  }
                                  return '';
                                }
                                return TableRow(
                                  children: [
                                    Text(
                                        g(['name', 'student_name']),
                                        style: NeyvoType.bodySmall),
                                    Text(
                                        g(['phone', 'mobile']),
                                        style: NeyvoType.bodySmall),
                                    Text(g(['balance']),
                                        style: NeyvoType.bodySmall),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ],
                        if (_errorLines.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ExpansionTile(
                            title: Text(
                              'Show ${_errorLines.length} errors',
                              style: NeyvoType.labelSmall
                                  .copyWith(color: NeyvoColors.error),
                            ),
                            children: _errorLines
                                .map((e) => Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 4),
                                      child: Text(
                                        e,
                                        style: NeyvoType.bodySmall.copyWith(
                                            color: NeyvoColors.error,
                                            fontSize: 13),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => setState(() {
                                _step = 1;
                                _csvText = '';
                                _validRows = [];
                                _errorLines = [];
                              }),
                              child: const Text('Back'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _loading || _validRows.isEmpty
                                  ? null
                                  : _doImport,
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text(
                                      'Import ${_validRows.length} students'),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 24),
                        Icon(Icons.check_circle,
                            size: 48, color: NeyvoColors.success),
                        const SizedBox(height: 12),
                        Text('Import complete',
                            style: NeyvoType.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          '${_imported ?? 0} imported · ${_updated ?? 0} updated',
                          style: NeyvoType.bodyMedium,
                        ),
                        if ((_failed ?? 0) > 0)
                          Text('${_failed} rows skipped',
                              style: NeyvoType.bodySmall
                                  .copyWith(color: NeyvoColors.error)),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => setState(() {
                            _step = 1;
                            _csvText = '';
                            _imported = null;
                            _updated = null;
                            _failed = null;
                            _errors = [];
                            _validRows = [];
                            _errorLines = [];
                          }),
                          child: const Text('Import another file'),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

// --- Sync tab ---

class _SyncTab extends StatefulWidget {
  const _SyncTab({super.key});

  @override
  State<_SyncTab> createState() => _SyncTabState();
}

class _SyncTabState extends State<_SyncTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _schoolIntegration;
  bool _schoolTokenVisible = false;
  bool _isEducationOrg = false;

  Map<String, dynamic> _config = {};
  bool _enabled = false;
  List<String> _modes = [];
  final _apiPullUrl = TextEditingController();
  final _webhookSecret = TextEditingController();
  bool _saving = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiPullUrl.dispose();
    _webhookSecret.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final agentsRes = await NeyvoPulseApi.listAgents();
      final agents =
          (agentsRes['agents'] as List? ?? []).cast<Map<String, dynamic>>();
      final isEdu = agents.any((a) =>
          (a['industry']?.toString().toLowerCase() ?? '') == 'education');
      Map<String, dynamic>? schoolInt;
      if (isEdu) {
        try {
          schoolInt = await NeyvoPulseApi.getSchoolIntegration();
        } catch (_) {}
      }
      Map<String, dynamic> config = {};
      try {
        final res = await NeyvoPulseApi.getIntegrationConfig();
        final c = res['config'] as Map<String, dynamic>? ?? res;
        config = Map<String, dynamic>.from(c);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isEducationOrg = isEdu;
        _schoolIntegration = schoolInt;
        _config = config;
        _enabled = config['enabled'] == true;
        _modes = List<String>.from(config['modes'] as List? ?? const []);
        _apiPullUrl.text = config['api_pull_url']?.toString() ?? '';
        _webhookSecret.text =
            config['webhook_secret']?.toString() ?? '';
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

  Future<void> _saveGeneric() async {
    setState(() => _saving = true);
    try {
      await NeyvoPulseApi.setIntegrationConfig(
        enabled: _enabled,
        modes: _modes.isEmpty ? null : _modes,
        webhookSecret: _webhookSecret.text.trim().isEmpty
            ? null
            : _webhookSecret.text.trim(),
        apiPullUrl: _apiPullUrl.text.trim().isEmpty
            ? null
            : _apiPullUrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Integration saved')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _syncNow() async {
    if (_apiPullUrl.text.trim().isEmpty) return;
    setState(() => _syncing = true);
    try {
      final res = await NeyvoPulseApi.triggerIntegrationSync();
      if (!mounted) return;
      final ok = res['ok'] == true;
      final summary = res['summary'] as Map<String, dynamic>?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Sync done. Students: ${summary?['students_upserted'] ?? '?'}, Payments: ${summary?['payments_created'] ?? '?'}'
                : (res['error']?.toString() ?? 'Sync failed'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(NeyvoSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!,
                  style: NeyvoType.bodyMedium
                      .copyWith(color: NeyvoColors.error)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final lastSync = _config['last_sync_at']?.toString();
    final lastStatus =
        _config['last_sync_status']?.toString() ?? '—';

    return ListView(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      children: [
        if (_isEducationOrg && _schoolIntegration != null) ...[
          Text('School webhook (UB SIS)',
              style: NeyvoType.titleMedium),
          const SizedBox(height: 8),
          Card(
            color: NeyvoTheme.bgCard,
            child: Padding(
              padding: const EdgeInsets.all(NeyvoSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: _schoolIntegration!['enabled'] == true,
                    onChanged: (v) async {
                      try {
                        await NeyvoPulseApi.patchSchoolIntegration(
                            enabled: v);
                        _load();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())));
                        }
                      }
                    },
                    title: const Text('Enable integration'),
                  ),
                  if (_schoolIntegration!['enabled'] == true) ...[
                    const Divider(),
                    ListTile(
                      title: Text('Webhook URL',
                          style: NeyvoType.labelLarge),
                      subtitle: SelectableText(
                          '${SpeariaApi.baseUrl}/api/pulse/integrations/school/webhook'),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text:
                                  '${SpeariaApi.baseUrl}/api/pulse/integrations/school/webhook'));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('URL copied')));
                        },
                      ),
                    ),
                    ListTile(
                      title: Text('Webhook Token',
                          style: NeyvoType.labelLarge),
                      subtitle: Text(_schoolTokenVisible
                          ? (_schoolIntegration!['token'] ?? '••••••••')
                          : '••••••••••••••••'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => setState(() =>
                                _schoolTokenVisible = !_schoolTokenVisible),
                            child: Text(
                                _schoolTokenVisible ? 'Hide' : 'Reveal'),
                          ),
                          TextButton(
                            onPressed: () async {
                              try {
                                final res = await NeyvoPulseApi
                                    .regenerateSchoolIntegrationToken();
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                          content: Text(
                                              'New token: ${res['token'] ?? 'saved'} (copy it now; it won\'t be shown again)')));
                                  _load();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(e.toString())));
                                }
                              }
                            },
                            child: const Text('Regenerate'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Regenerating will break existing integrations until you update the token.',
                      style: NeyvoType.bodySmall
                          .copyWith(color: NeyvoTheme.warning),
                    ),
                    const SizedBox(height: NeyvoSpacing.md),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Send test event'),
                      onPressed: () async {
                        try {
                          await NeyvoPulseApi.sendSchoolWebhookTest();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Test received — integration is working')));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Test failed: $e')));
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: NeyvoSpacing.xl),
        ],
        Text('Generic integration',
            style: NeyvoType.titleMedium),
        const SizedBox(height: 8),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  title: const Text('Enable integration'),
                  subtitle: Text(
                    'Webhook, CSV ingest, or API pull',
                    style: NeyvoType.bodySmall
                        .copyWith(color: NeyvoColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _modeChip('webhook', 'Webhook'),
                    _modeChip('api_pull', 'API pull'),
                    _modeChip('file_ingest', 'File ingest'),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiPullUrl,
                  decoration: const InputDecoration(
                    labelText: 'API pull URL',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _webhookSecret,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Webhook secret (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                      onPressed: _saving ? null : _saveGeneric,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _syncing ? null : _syncNow,
                      child: _syncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sync now'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Last sync: ${lastSync ?? '—'} · Status: $lastStatus',
                  style: NeyvoType.bodySmall
                      .copyWith(color: NeyvoColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeChip(String key, String label) {
    final selected = _modes.contains(key);
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (v) {
        setState(() {
          if (v) {
            if (!_modes.contains(key)) _modes.add(key);
          } else {
            _modes.remove(key);
          }
        });
      },
      selectedColor: NeyvoColors.teal.withOpacity(0.18),
      checkmarkColor: NeyvoColors.teal,
      side: BorderSide(
          color: selected
              ? NeyvoColors.teal.withOpacity(0.5)
              : NeyvoColors.borderSubtle),
    );
  }
}
