// lib/screens/students_hub_page.dart
// Students hub: Directory, Import, Sync tabs (single control plane).

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_response_cache.dart';
import '../api/neyvo_api.dart';
import '../core/providers/students_hub_tab_provider.dart';
import '../features/managed_profiles/managed_profile_api_service.dart';
import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';
import '../ui/components/glass/neyvo_glass_panel.dart';
import '../utils/csv_import.dart';
import '../utils/phone_util.dart';
import 'student_detail_page.dart';

class StudentsHubPage extends ConsumerStatefulWidget {
  const StudentsHubPage({super.key});

  @override
  ConsumerState<StudentsHubPage> createState() => _StudentsHubPageState();
}

class _StudentsHubPageState extends ConsumerState<StudentsHubPage> {
  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(studentsHubTabProvider);
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  _hubTabPill(0, 'Directory', tab, primary),
                  const SizedBox(width: 8),
                  _hubTabPill(1, 'Import', tab, primary),
                  const SizedBox(width: 8),
                  _hubTabPill(2, 'Sync', tab, primary),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: tab,
        children: const [
          _DirectoryTab(),
          _ImportTab(key: ValueKey('import')),
          _SyncTab(key: ValueKey('sync')),
        ],
      ),
    );
  }

  Widget _hubTabPill(int index, String label, int selected, Color primary) {
    final on = selected == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => ref.read(studentsHubTabProvider.notifier).select(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? primary.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? primary.withOpacity(0.45) : NeyvoColors.borderSubtle),
          ),
          child: Text(
            label,
            style: NeyvoTextStyles.label.copyWith(
              color: on ? primary : NeyvoColors.textSecondary,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Directory tab ---

class _DirectoryTab extends StatefulWidget {
  const _DirectoryTab();

  @override
  State<_DirectoryTab> createState() => _DirectoryTabState();
}

class _DirectoryTabState extends State<_DirectoryTab> with SingleTickerProviderStateMixin {
  static const int _studentsPageSize = 50;
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _loading = true;
  String? _error;
  bool _isEducationOrg = false;
  /// True while a second request is merging last_call_* from call history (progressive load).
  bool _enrichingLastCalls = false;
  bool _enrichLastCallsInFlight = false;
  bool _loadingMoreStudents = false;
  final _searchController = TextEditingController();
  String _filterStatus = 'all';
  late AnimationController _tableAnimationController;
  late Animation<double> _tableFade;
  late Animation<Offset> _tableSlide;
  late Animation<double> _tableScale;
  bool _tableAnimationStarted = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStudents);
    _tableAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _tableFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _tableAnimationController, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );
    _tableSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(parent: _tableAnimationController, curve: const Interval(0, 1, curve: Curves.easeOutCubic)),
    );
    _tableScale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(parent: _tableAnimationController, curve: const Interval(0, 1, curve: Curves.easeOutBack)),
    );
    _load();
  }

  static String _normalizePhoneUs(String raw) => normalizePhoneInput(raw);

  Future<void> openAddStudentDialog() async {
    final firstNameC = TextEditingController();
    final lastNameC = TextEditingController();
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
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: firstNameC,
                                  decoration: const InputDecoration(
                                    labelText: 'First name *',
                                    hintText: 'First name',
                                  ),
                                ),
                              ),
                              const SizedBox(width: NeyvoSpacing.md),
                              Expanded(
                                child: TextField(
                                  controller: lastNameC,
                                  decoration: const InputDecoration(
                                    labelText: 'Last name (optional)',
                                    hintText: 'Last name',
                                  ),
                                ),
                              ),
                            ],
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
              final firstName = firstNameC.text.trim();
              final lastName = lastNameC.text.trim();
              final phoneRaw = phoneC.text.trim();
              if (firstName.isEmpty || phoneRaw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('First name and phone required')),
                );
                return;
              }
              final phone = normalizeToE164Us(phoneRaw);
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a valid US phone (e.g. 123-456-7890, (123) 456-7890)',
                    ),
                  ),
                );
                return;
              }
              try {
                await NeyvoPulseApi.createStudent(
                  // Treat first name as canonical name for compatibility.
                  name: firstName,
                  phone: phone,
                  firstName: firstName,
                  lastName: lastName.isNotEmpty ? lastName : null,
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

    firstNameC.dispose();
    lastNameC.dispose();
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
    _tableAnimationController.dispose();
    super.dispose();
  }

  void _runTableEntryAnimation() {
    if (_filteredStudents.isEmpty) {
      _tableAnimationStarted = false;
      _tableAnimationController.reset();
      return;
    }
    if (!_tableAnimationStarted) {
      _tableAnimationStarted = true;
      _tableAnimationController.forward();
    }
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

  static String _studentDisplayName(Map<String, dynamic> s) {
    final name = s['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final first = s['first_name']?.toString().trim() ?? '';
    final last = s['last_name']?.toString().trim() ?? '';
    return '$first $last'.trim().isEmpty ? '—' : '$first $last'.trim();
  }

  static String _lastCallStatusLabel(dynamic outcome) {
    if (outcome == null) return 'Pending';
    final o = outcome.toString().trim().toLowerCase();
    if (o.contains('answer')) return 'Answered';
    if (o.contains('voicemail')) return 'Voicemail';
    if (o.contains('not') || o.contains('no_connect') || o.contains('failed')) return 'Not Connected';
    if (o.isEmpty) return 'Pending';
    return outcome.toString().trim();
  }

  static Color _lastCallStatusColor(String label) {
    switch (label) {
      case 'Answered':
        return NeyvoColors.success;
      case 'Voicemail':
        return NeyvoTheme.warning;
      case 'Not Connected':
        return NeyvoColors.error;
      default:
        return NeyvoColors.textMuted;
    }
  }

  static String _lastCallTimeLabel(dynamic dateVal) {
    if (dateVal == null || dateVal.toString().trim().isEmpty) return 'Never';
    try {
      DateTime dt;
      if (dateVal is DateTime) {
        dt = dateVal;
      } else {
        final str = dateVal.toString().trim();
        dt = DateTime.parse(str);
      }
      const months = 'JanFebMarAprMayJunJulAugSepOctNovDec';
      final month = months.substring((dt.month - 1) * 3, dt.month * 3);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${month} ${dt.day}, $hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return dateVal.toString();
    }
  }

  Future<void> _launchCall(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    final uri = Uri.parse('tel:$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<Map<String, dynamic>> _outboundProfiles = [];
  bool _profilesLoaded = false;

  Future<String?> _getDefaultOutboundProfileId() async {
    if (!_profilesLoaded) {
      try {
        final res = await ManagedProfileApiService.listProfiles();
        final list = (res['profiles'] as List?)?.cast<dynamic>() ?? const [];
        final profiles = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (mounted) {
          setState(() {
            _outboundProfiles = profiles;
            _profilesLoaded = true;
          });
        }
      } catch (_) {
        return null;
      }
    }
    if (_outboundProfiles.isEmpty) return null;
    return (_outboundProfiles.first['profile_id'] ?? _outboundProfiles.first['id'])?.toString();
  }

  Future<void> _startVapiCall(Map<String, dynamic> s) async {
    final phoneRaw = s['phone']?.toString().trim() ?? '';
    final phone = normalizeToE164Us(phoneRaw);
    if (phone.isEmpty || !RegExp(r'^\+[0-9]{8,15}$').hasMatch(phone)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valid phone number required to place Vapi call.')),
        );
      }
      return;
    }
    final profileId = await _getDefaultOutboundProfileId();
    if (profileId == null || profileId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No outbound agent configured. Add an agent in Settings or Dialer.')),
        );
      }
      return;
    }
    final studentId = s['id']?.toString().trim();
    final name = _studentDisplayName(s);
    try {
      await ManagedProfileApiService.makeOutboundCall(
        profileId: profileId,
        customerPhone: phone,
        studentId: studentId?.isEmpty == true ? null : studentId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call started to $name via Vapi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call failed: ${e.toString()}')),
        );
      }
    }
  }

  void _openStudentDetails(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDetailPage(studentId: id, onUpdated: _load),
      ),
    );
  }

  Future<void> _confirmDeleteStudent(BuildContext context, String id, String name) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete student'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await NeyvoPulseApi.deleteStudent(id);
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String get _studentsSwrKey =>
      '${NeyvoPulseApi.defaultAccountId}_students_$_filterStatus';

  ({
    bool? hasBalance,
    bool? isOverdue,
    String? dueBefore,
    String? dueAfter,
  }) _studentListFilters(bool isEducation) {
    bool? hasBalance;
    bool? isOverdue;
    String? dueAfter;
    String? dueBefore;
    if (isEducation && _filterStatus != 'all') {
      if (_filterStatus == 'with_balance') {
        hasBalance = true;
      } else if (_filterStatus == 'overdue') {
        isOverdue = true;
      } else if (_filterStatus == 'due_this_week') {
        final now = DateTime.now();
        dueAfter =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final end = now.add(const Duration(days: 7));
        dueBefore =
            '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
      } else if (_filterStatus == 'no_balance') {
        hasBalance = false;
      }
    }
    return (
      hasBalance: hasBalance,
      isOverdue: isOverdue,
      dueBefore: dueBefore,
      dueAfter: dueAfter,
    );
  }

  List<Map<String, dynamic>> _mergeLastCallFields(
    List<Map<String, dynamic>> base,
    List<Map<String, dynamic>> enriched,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final e in enriched) {
      final id = (e['id'] ?? '').toString();
      if (id.isNotEmpty) {
        byId[id] = e;
      }
    }
    return base.map((s) {
      final id = (s['id'] ?? '').toString();
      final e = byId[id];
      if (e == null) return s;
      final m = Map<String, dynamic>.from(s);
      if (e.containsKey('last_call_outcome')) {
        m['last_call_outcome'] = e['last_call_outcome'];
      }
      if (e.containsKey('last_call_date')) {
        m['last_call_date'] = e['last_call_date'];
      }
      return m;
    }).toList();
  }

  bool _needsLastCallEnrichment(List<Map<String, dynamic>> students) {
    for (final s in students) {
      if (!s.containsKey('last_call_outcome') || !s.containsKey('last_call_date')) {
        return true;
      }
    }
    return false;
  }

  Future<void> _enrichLastCalls({required bool isEducation}) async {
    if (_enrichLastCallsInFlight) return;
    _enrichLastCallsInFlight = true;
    final f = _studentListFilters(isEducation);
    try {
      if (mounted) {
        setState(() => _enrichingLastCalls = true);
      }
      final res = await NeyvoPulseApi.listStudents(
        hasBalance: f.hasBalance,
        isOverdue: f.isOverdue,
        dueAfter: f.dueAfter,
        dueBefore: f.dueBefore,
        enrichCalls: true,
      );
      final enriched = (res['students'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      final merged = _mergeLastCallFields(_allStudents, enriched);
      ApiResponseCache.set(
        _studentsSwrKey,
        <String, dynamic>{
          'isEdu': isEducation,
          'students': merged,
          'callsEnriched': true,
        },
        ttl: const Duration(seconds: 60),
      );
      setState(() {
        _allStudents = merged;
        _filteredStudents = merged;
        _enrichingLastCalls = false;
      });
      _filterStudents();
    } catch (_) {
      if (mounted) {
        setState(() => _enrichingLastCalls = false);
      }
    } finally {
      _enrichLastCallsInFlight = false;
    }
  }

  Future<void> _loadRemainingStudentsPages({
    required bool isEducation,
    required ({
      bool? hasBalance,
      bool? isOverdue,
      String? dueBefore,
      String? dueAfter,
    }) filters,
    required int startOffset,
  }) async {
    if (_loadingMoreStudents) return;
    _loadingMoreStudents = true;
    var offset = startOffset;
    try {
      while (mounted) {
        final res = await NeyvoPulseApi.listStudents(
          limit: _studentsPageSize,
          offset: offset,
          hasBalance: filters.hasBalance,
          isOverdue: filters.isOverdue,
          dueAfter: filters.dueAfter,
          dueBefore: filters.dueBefore,
          enrichCalls: false,
        );
        final page = (res['students'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (page.isEmpty || !mounted) break;
        final existingIds = _allStudents
            .map((e) => (e['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();
        final newRows = page.where((s) {
          final id = (s['id'] ?? '').toString();
          return id.isEmpty || !existingIds.contains(id);
        }).toList();
        if (newRows.isNotEmpty) {
          setState(() {
            _allStudents = [..._allStudents, ...newRows];
            _filteredStudents = _allStudents;
          });
          _filterStudents();
        }
        offset += page.length;
        if (page.length < _studentsPageSize) break;
      }
      if (!mounted) return;
      final needsEnrichment = _needsLastCallEnrichment(_allStudents);
      ApiResponseCache.set(
        _studentsSwrKey,
        <String, dynamic>{
          'isEdu': isEducation,
          'students': _allStudents,
          'callsEnriched': !needsEnrichment,
        },
        ttl: const Duration(seconds: 60),
      );
      if (needsEnrichment && _allStudents.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _enrichLastCalls(isEducation: isEducation);
          }
        });
      } else if (mounted) {
        setState(() => _enrichingLastCalls = false);
      }
    } finally {
      _loadingMoreStudents = false;
    }
  }

  Future<void> _load() async {
    final cachedEntry = ApiResponseCache.get(_studentsSwrKey);
    if (cachedEntry is Map<String, dynamic>) {
      setState(() {
        _isEducationOrg = cachedEntry['isEdu'] == true;
        _allStudents = List<Map<String, dynamic>>.from(
          (cachedEntry['students'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        _filteredStudents = _allStudents;
        _loading = false;
        _error = null;
      });
      _filterStudents();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runTableEntryAnimation();
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final agentsRes = await NeyvoPulseApi.listAgents();
      final agents =
          (agentsRes['agents'] as List? ?? []).cast<Map<String, dynamic>>();
      final isEducation = agents.any((a) =>
          (a['industry']?.toString().toLowerCase() ?? '') == 'education');

      final f = _studentListFilters(isEducation);
      final res = await NeyvoPulseApi.listStudents(
        limit: _studentsPageSize,
        offset: 0,
        hasBalance: f.hasBalance,
        isOverdue: f.isOverdue,
        dueAfter: f.dueAfter,
        dueBefore: f.dueBefore,
        enrichCalls: false,
      );
      final list = (res['students'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final needsEnrichment = _needsLastCallEnrichment(list);
      final hasMorePages = list.length == _studentsPageSize;
      ApiResponseCache.set(
        _studentsSwrKey,
        <String, dynamic>{
          'isEdu': isEducation,
          'students': list,
          'callsEnriched': !needsEnrichment && !hasMorePages,
        },
        ttl: const Duration(seconds: 60),
      );
      if (mounted) {
        setState(() {
          _isEducationOrg = isEducation;
          _allStudents = list;
          _filteredStudents = list;
          _loading = false;
          _enrichingLastCalls = list.isNotEmpty && (needsEnrichment || hasMorePages);
        });
        _filterStudents();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _runTableEntryAnimation();
        });
        if (hasMorePages) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadRemainingStudentsPages(
                isEducation: isEducation,
                filters: f,
                startOffset: list.length,
              );
            }
          });
        } else if (list.isNotEmpty && needsEnrichment) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _enrichLastCalls(isEducation: isEducation);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        if (cachedEntry is Map<String, dynamic> &&
            cachedEntry['callsEnriched'] == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _enrichLastCalls(isEducation: _isEducationOrg);
            }
          });
        }
        if (cachedEntry == null) {
          setState(() {
            _error = e.toString();
            _loading = false;
          });
        }
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

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Container(
            margin: const EdgeInsets.fromLTRB(NeyvoSpacing.md, NeyvoSpacing.md, NeyvoSpacing.md, 0),
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            decoration: BoxDecoration(
              color: NeyvoTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NeyvoColors.borderSubtle, width: 1),
              boxShadow: [
                BoxShadow(
                  color: NeyvoColors.ubPurple.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name, phone, email, or ID...',
                          hintStyle: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.textMuted),
                          prefixIcon: Icon(Icons.search_rounded, color: NeyvoColors.ubPurple.withOpacity(0.7), size: 22),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear_rounded, size: 20, color: NeyvoColors.textMuted),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: NeyvoColors.bgHover.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: NeyvoColors.borderSubtle),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: NeyvoColors.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: NeyvoColors.ubPurple, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: NeyvoSpacing.md),
                    FilledButton.icon(
                      onPressed: () => openAddStudentDialog(),
                      icon: const Icon(Icons.person_add_rounded, size: 20),
                      label: const Text('Add student'),
                      style: FilledButton.styleFrom(
                        backgroundColor: true
                            ? Theme.of(context).colorScheme.primary
                            : NeyvoColors.ubPurple,
                        foregroundColor: NeyvoColors.white,
                        padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
            if (_filteredStudents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
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
                ),
              )
            else
              Builder(
                    builder: (context) {
                      // Ensure table entry animation runs when table is first shown
                      if (_filteredStudents.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => _runTableEntryAnimation());
                      }
                      return AnimatedBuilder(
                        animation: _tableAnimationController,
                        builder: (context, _) {
                            final animValue = _tableAnimationController.value;
                            return Opacity(
                              opacity: _tableFade.value,
                              child: Transform.translate(
                                offset: Offset(0, _tableSlide.value.dy * 60),
                                child: Transform.scale(
                                  scale: _tableScale.value,
                                  alignment: Alignment.topCenter,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final minTableWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 900.0;
                                      final headerStyle = NeyvoType.labelSmall.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      );
                                      final cellStyle = NeyvoType.bodySmall.copyWith(fontSize: 14);
                                      final nameCellStyle = NeyvoType.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      );
                                      return NeyvoCard(
                                        padding: EdgeInsets.zero,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(minWidth: minTableWidth),
                                            child: DataTable(
                                              showCheckboxColumn: false,
                                              headingRowColor: MaterialStateProperty.all(NeyvoColors.bgOverlay),
                                              dataRowMinHeight: 52,
                                              dataRowMaxHeight: 56,
                                              columnSpacing: NeyvoSpacing.md,
                                              columns: [
                                                DataColumn(label: Text('First name', style: headerStyle)),
                                                DataColumn(label: Text('Last name', style: headerStyle)),
                                                DataColumn(label: Text('ID', style: headerStyle)),
                                                DataColumn(label: Text('Department', style: headerStyle)),
                                                DataColumn(label: Text('Phone Number', style: headerStyle)),
                                                DataColumn(label: Text('Email', style: headerStyle)),
                                                DataColumn(label: Text('Year of student', style: headerStyle)),
                                                DataColumn(label: Text('Import List', style: headerStyle)),
                                                DataColumn(label: Text('Last Call Status', style: headerStyle)),
                                                DataColumn(label: Text('Last Call', style: headerStyle)),
                                                DataColumn(label: Text('Actions', style: headerStyle)),
                                              ],
                                              rows: _filteredStudents.asMap().entries.map((entry) {
                                                final rowIndex = entry.key;
                                                final s = entry.value;
                                                final id = s['id'] as String? ?? '';
                                                String firstName = (s['first_name']?.toString().trim() ?? '').trim();
                                                String lastName = (s['last_name']?.toString().trim() ?? '').trim();
                                                if (firstName.isEmpty && lastName.isEmpty) {
                                                  final full = _studentDisplayName(s);
                                                  if (full != '—') {
                                                    final parts = full.trim().split(RegExp(r'\s+'));
                                                    firstName = parts.isNotEmpty ? parts.first : '—';
                                                    lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '—';
                                                  } else {
                                                    firstName = '—';
                                                    lastName = '—';
                                                  }
                                                } else {
                                                  if (firstName.isEmpty) firstName = '—';
                                                  if (lastName.isEmpty) lastName = '—';
                                                }
                                                final name = _studentDisplayName(s);
                                                final studentId = s['student_id']?.toString() ?? s['external_id']?.toString() ?? '—';
                                                final department = (s['department'] as String?)?.trim();
                                                final phone = s['phone'] as String? ?? '';
                                                final email = (s['email'] as String?)?.trim();
                                                final yearOfStudy = (s['year_of_study'] as String?)?.trim();
                                                final importList = (s['import_name'] as String?)?.trim();
                                                final lastStatus = _enrichingLastCalls
                                                    ? '…'
                                                    : _lastCallStatusLabel(s['last_call_outcome']);
                                                final lastTime = _enrichingLastCalls
                                                    ? '…'
                                                    : _lastCallTimeLabel(s['last_call_date']);
                                                final statusColor = _lastCallStatusColor(lastStatus);
                                                final rowOpacity = (animValue * (_filteredStudents.length + 4) - rowIndex).clamp(0.0, 1.0);
                                                return DataRow(
                                                  onSelectChanged: (_) => _openStudentDetails(id),
                                                  cells: [
                                                    DataCell(
                                                      Opacity(
                                                        opacity: rowOpacity,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              CircleAvatar(
                                                                radius: 18,
                                                                backgroundColor: NeyvoTheme.primary.withOpacity(0.12),
                                                                child: Text(
                                                                  firstName != '—' ? firstName[0].toUpperCase() : (name.isNotEmpty && name != '—' ? name[0].toUpperCase() : '?'),
                                                                  style: NeyvoType.labelSmall.copyWith(
                                                                    color: NeyvoTheme.primary,
                                                                    fontWeight: FontWeight.w700,
                                                                    fontSize: 13,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Text(firstName, style: nameCellStyle),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Opacity(
                                                        opacity: rowOpacity,
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                                          child: Text(lastName, style: nameCellStyle),
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(Opacity(opacity: rowOpacity, child: Text(studentId, style: cellStyle))),
                                                    DataCell(Opacity(opacity: rowOpacity, child: Text(department?.isNotEmpty == true ? department! : '—', style: cellStyle))),
                                                    DataCell(Opacity(opacity: rowOpacity, child: Text(phone, style: cellStyle))),
                                                    DataCell(Opacity(opacity: rowOpacity, child: Text(email?.isNotEmpty == true ? email! : '—', style: cellStyle))),
                                                    DataCell(Opacity(opacity: rowOpacity, child: Text(yearOfStudy?.isNotEmpty == true ? yearOfStudy! : '—', style: cellStyle))),
                                                    DataCell(Opacity(opacity: rowOpacity, child: Text(importList?.isNotEmpty == true ? importList! : '—', style: cellStyle))),
                                                    DataCell(
                                                      Opacity(
                                                        opacity: rowOpacity,
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: statusColor.withOpacity(0.15),
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(color: statusColor.withOpacity(0.4), width: 1),
                                                          ),
                                                          child: Text(
                                                            lastStatus,
                                                            style: cellStyle.copyWith(
                                                              color: statusColor,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(Opacity(opacity: rowOpacity, child: Text(lastTime, style: cellStyle))),
                                                    DataCell(
                                                      PopupMenuButton<String>(
                                                        icon: const Icon(Icons.more_vert, size: 22),
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        tooltip: 'Actions',
                                                        onSelected: (value) async {
                                                          switch (value) {
                                                            case 'call_vapi':
                                                              await _startVapiCall(s);
                                                              break;
                                                            case 'view':
                                                            case 'edit':
                                                              _openStudentDetails(id);
                                                              break;
                                                            case 'delete':
                                                              _confirmDeleteStudent(context, id, name);
                                                              break;
                                                            case 'dial':
                                                              await _launchCall(phone);
                                                              break;
                                                          }
                                                        },
                                                        itemBuilder: (context) => [
                                                          const PopupMenuItem(value: 'call_vapi', child: Row(children: [Icon(Icons.phone_in_talk, size: 20), SizedBox(width: 12), Text('Call with Vapi')])),
                                                          const PopupMenuItem(value: 'dial', child: Row(children: [Icon(Icons.phone_outlined, size: 20), SizedBox(width: 12), Text('Dial number')])),
                                                          const PopupMenuDivider(),
                                                          const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.person_outline, size: 20), SizedBox(width: 12), Text('View details')])),
                                                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 12), Text('Edit')])),
                                                          const PopupMenuDivider(),
                                                          PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 20, color: NeyvoColors.error), const SizedBox(width: 12), Text('Delete', style: TextStyle(color: NeyvoColors.error))])),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                      );
                    },
                  ),
          ],
        ),
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

// --- Import tab ---

class _ImportTab extends StatefulWidget {
  const _ImportTab({super.key});

  @override
  State<_ImportTab> createState() => _ImportTabState();
}

class _ImportTabState extends State<_ImportTab> {
  int _step = 1;
  String _csvText = '';
  String _importName = '';
  bool _loading = false;
  int? _imported;
  int? _updated;
  int? _failed;
  List<String> _errors = [];
  List<Map<String, String>> _validRows = [];
  List<String> _errorLines = [];
  DropzoneViewController? _dropzoneController;
  bool _isDraggingOver = false;

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

  Widget _buildPreviewTable() {
    // Collect headers across all valid rows.
    final headerSet = <String>{};
    for (final r in _validRows) {
      headerSet.addAll(r.keys);
    }
    // Prioritize core fields, then any custom fields alphabetically.
    final coreOrder = [
      'name',
      'phone',
      'email',
      'student_id',
      'balance',
      'due_date',
      'late_fee',
      'notes',
    ];
    final headers = <String>[
      ...coreOrder.where((h) => headerSet.contains(h)),
      ...headerSet.where((h) => !coreOrder.contains(h)).toList()..sort(),
    ];

    List<DataColumn> columns = headers
        .map(
          (h) => DataColumn(
            label: Text(
              h.replaceAll('_', ' '),
              style: NeyvoType.labelSmall,
            ),
          ),
        )
        .toList();

    List<DataRow> rows = _validRows.take(5).map((row) {
      return DataRow(
        cells: headers
            .map(
              (h) => DataCell(
                Text(
                  row[h] ?? '',
                  style: NeyvoType.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
      );
    }).toList();

    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview (first 5 rows)', style: NeyvoType.labelSmall),
          const SizedBox(height: NeyvoSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: columns,
              rows: rows,
              headingRowColor: MaterialStateProperty.all(NeyvoColors.bgRaised),
              dataRowMinHeight: 32,
              dataRowMaxHeight: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportSummaryChart() {
    if (_validRows.isEmpty) {
      return const SizedBox.shrink();
    }
    int withBalance = 0;
    for (final r in _validRows) {
      final bal = (r['balance'] ?? '').toString().replaceAll(RegExp(r'[\$,]'), '').trim();
      if (bal.isNotEmpty && bal != '0') withBalance++;
    }
    final withoutBalance = _validRows.length - withBalance;
    final total = _validRows.length.toDouble();
    return PieChart(
      PieChartData(
        sectionsSpace: 0,
        centerSpaceRadius: 18,
        startDegreeOffset: -90,
        sections: [
          if (withBalance > 0)
            PieChartSectionData(
              value: withBalance.toDouble(),
              color: NeyvoTheme.warning,
              title: total > 0 ? '${((withBalance / total) * 100).round()}%' : '',
              radius: 18,
              titleStyle: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textPrimary),
            ),
          if (withoutBalance > 0)
            PieChartSectionData(
              value: withoutBalance.toDouble(),
              color: NeyvoTheme.teal,
              title: '',
              radius: 16,
            ),
        ],
      ),
    );
  }

  Future<void> _downloadTemplate() async {
    if (kIsWeb) {
      final url =
          '${NeyvoApi.baseUrl}/api/pulse/students/import/template';
      final ok = await NeyvoApi.launchExternal(url);
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
      final res = await NeyvoPulseApi.postStudentsImportCsv(
        _csvText,
        importName: _importName.trim().isEmpty ? null : _importName.trim(),
      );
      if (!mounted) return;
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
          constraints: const BoxConstraints(maxWidth: 960),
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
                      'Upload a CSV or Excel file. Required: either name OR first_name (plus phone). Optional: last_name, email, student_id, balance, due_date, late_fee, notes. '
                      'Phone accepts any format: (123) 456-7890, 123-456-7890, 1234567890, etc. Tip: the first non-comment row must be the header. Lines starting with # and blank rows are ignored.',
                      style: NeyvoType.bodyMedium.copyWith(
                          color: NeyvoColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Stack(
                      children: [
                        if (kIsWeb)
                          SizedBox(
                            height: 140,
                            child: DropzoneView(
                              operation: DragOperation.copy,
                              cursor: CursorType.grab,
                              onCreated: (c) => _dropzoneController = c,
                              onHover: () => setState(() => _isDraggingOver = true),
                              onLeave: () => setState(() => _isDraggingOver = false),
                              onDrop: (ev) async {
                                try {
                                  final mime = await _dropzoneController?.getFileMIME(ev) ?? '';
                                  if (!mime.contains('csv') && !mime.contains('excel')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please drop a CSV file')),
                                    );
                                    return;
                                  }
                                  final bytes = await _dropzoneController!.getFileData(ev);
                                  final text = String.fromCharCodes(bytes);
                                  setState(() {
                                    _csvText = text;
                                    _step = 2;
                                  });
                                  _validateCsv();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to read file: $e')),
                                  );
                                } finally {
                                  if (mounted) setState(() => _isDraggingOver = false);
                                }
                              },
                            ),
                          ),
                        InkWell(
                          onTap: _pickFile,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 140,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _isDraggingOver ? NeyvoTheme.teal : NeyvoColors.borderDefault,
                                width: _isDraggingOver ? 2 : 1,
                              ),
                              color: _isDraggingOver ? NeyvoTheme.teal.withOpacity(0.04) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.upload_file,
                                    size: 32,
                                    color: _isDraggingOver ? NeyvoTheme.teal : NeyvoColors.textMuted,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    kIsWeb
                                        ? 'Drag & drop your CSV here or click to browse'
                                        : 'Tap to choose a CSV file',
                                    style: NeyvoType.bodyMedium,
                                  ),
                                  Text(
                                    '.csv only · first row must be headers like name, phone, …',
                                    style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        NeyvoGlassPanel(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_validRows.length} students ready',
                                      style: NeyvoType.titleMedium.copyWith(color: NeyvoColors.success),
                                    ),
                                    const SizedBox(height: 4),
                                    if (_errorLines.isNotEmpty)
                                      Text(
                                        '${_errorLines.length} rows have issues. Fix them in your CSV or continue to import only the valid rows.',
                                        style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.error),
                                      )
                                    else
                                      Text(
                                        'All rows look good. Review the preview below, then click Import.',
                                        style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: NeyvoSpacing.md),
                              if (_validRows.isNotEmpty)
                                SizedBox(
                                  height: 80,
                                  width: 120,
                                  child: _buildImportSummaryChart(),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: NeyvoSpacing.lg),
                        if (_validRows.isNotEmpty) _buildPreviewTable(),
                        const SizedBox(height: NeyvoSpacing.lg),
                        Text('Import/List name (optional)', style: NeyvoType.labelSmall),
                        const SizedBox(height: 4),
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'e.g. Spring 2026 Nursing Cohort',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _importName = v),
                        ),
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
                        if (_errors.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ExpansionTile(
                            title: Text(
                              'Show ${_errors.length} import errors',
                              style: NeyvoType.labelSmall.copyWith(color: NeyvoColors.error),
                            ),
                            children: _errors
                                .take(50)
                                .map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      e,
                                      style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.error, fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
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

class _SyncTab extends ConsumerStatefulWidget {
  const _SyncTab({super.key});

  @override
  ConsumerState<_SyncTab> createState() => _SyncTabState();
}

class _SyncTabState extends ConsumerState<_SyncTab> {
  /// IndexedStack keeps this subtree mounted; we only hit the network when the user opens Sync.
  bool _syncLoadStarted = false;
  bool _loading = false;
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
    // If hub tab is already Sync (e.g. restored state), ref.listen may not fire — load once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tab = ref.read(studentsHubTabProvider);
      if (tab == 2 && !_syncLoadStarted) {
        _syncLoadStarted = true;
        _load();
      }
    });
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
    ref.listen<int>(studentsHubTabProvider, (prev, next) {
      if (next == 2 && !_syncLoadStarted) {
        _syncLoadStarted = true;
        _load();
      }
    });

    if (!_syncLoadStarted) {
      return const SizedBox.shrink();
    }
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
                          '${NeyvoApi.baseUrl}/api/pulse/integrations/school/webhook'),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text:
                                  '${NeyvoApi.baseUrl}/api/pulse/integrations/school/webhook'));
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
    final primary = Theme.of(context).colorScheme.primary;
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
      selectedColor: primary.withOpacity(0.18),
      checkmarkColor: primary,
      side: BorderSide(
          color: selected
              ? primary.withOpacity(0.5)
              : NeyvoColors.borderSubtle),
    );
  }
}
