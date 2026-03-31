import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';

part 'students_list_provider.g.dart';

class StudentsListUiState {
  const StudentsListUiState({
    this.allStudents = const [],
    this.filteredStudents = const [],
    this.loading = true,
    this.error,
    this.searchQuery = '',
    this.filterStatus = 'all',
    this.selectionMode = false,
    this.selectedIds = const {},
    this.isEducationOrg = false,
    this.reminders = const [],
    this.remindersLoading = false,
    this.agents = const [],
    this.selectedAgentId,
  });

  final List<dynamic> allStudents;
  final List<dynamic> filteredStudents;
  final bool loading;
  final String? error;
  final String searchQuery;
  final String filterStatus;
  final bool selectionMode;
  final Set<String> selectedIds;
  final bool isEducationOrg;
  final List<dynamic> reminders;
  final bool remindersLoading;
  final List<Map<String, dynamic>> agents;
  final String? selectedAgentId;

  StudentsListUiState copyWith({
    List<dynamic>? allStudents,
    List<dynamic>? filteredStudents,
    bool? loading,
    String? error,
    bool clearError = false,
    String? searchQuery,
    String? filterStatus,
    bool? selectionMode,
    Set<String>? selectedIds,
    bool? isEducationOrg,
    List<dynamic>? reminders,
    bool? remindersLoading,
    List<Map<String, dynamic>>? agents,
    String? selectedAgentId,
    bool clearSelectedAgentId = false,
  }) {
    return StudentsListUiState(
      allStudents: allStudents ?? this.allStudents,
      filteredStudents: filteredStudents ?? this.filteredStudents,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      filterStatus: filterStatus ?? this.filterStatus,
      selectionMode: selectionMode ?? this.selectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
      isEducationOrg: isEducationOrg ?? this.isEducationOrg,
      reminders: reminders ?? this.reminders,
      remindersLoading: remindersLoading ?? this.remindersLoading,
      agents: agents ?? this.agents,
      selectedAgentId: clearSelectedAgentId ? null : (selectedAgentId ?? this.selectedAgentId),
    );
  }
}

@riverpod
class StudentsListCtrl extends _$StudentsListCtrl {
  @override
  StudentsListUiState build() {
    Future<void>.microtask(load);
    return const StudentsListUiState();
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

  List<dynamic> _applyFilter({
    required List<dynamic> all,
    required String query,
    required String filterStatus,
  }) {
    return all.where((s) {
      final map = s as Map;
      final name = (map['name']?.toString() ?? '').toLowerCase();
      final first = (map['first_name']?.toString() ?? '').toLowerCase();
      final last = (map['last_name']?.toString() ?? '').toLowerCase();
      final combined = ('$first $last').trim();
      final phone = (map['phone']?.toString() ?? '').toLowerCase();
      final email = (map['email']?.toString() ?? '').toLowerCase();
      final studentId = (map['student_id']?.toString() ?? '').toLowerCase();
      final dept = (map['department']?.toString() ?? '').toLowerCase();
      final year = (map['year_of_study']?.toString() ?? '').toLowerCase();
      final q = query.toLowerCase();
      final matchesSearch = q.isEmpty ||
          name.contains(q) ||
          first.contains(q) ||
          last.contains(q) ||
          combined.contains(q) ||
          phone.contains(q) ||
          email.contains(q) ||
          studentId.contains(q) ||
          dept.contains(q) ||
          year.contains(q);
      if (!matchesSearch) return false;
      if (filterStatus == 'all') return true;
      if (filterStatus == 'with_balance') return _hasBalance(Map<String, dynamic>.from(map));
      if (filterStatus == 'overdue') return _isOverdue(Map<String, dynamic>.from(map));
      if (filterStatus == 'due_this_week') return _isDueThisWeek(Map<String, dynamic>.from(map));
      if (filterStatus == 'no_balance') return !_hasBalance(Map<String, dynamic>.from(map));
      return true;
    }).toList();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final agentsRes = await NeyvoPulseApi.listAgents();
      final agents = (agentsRes['agents'] as List? ?? const []).cast<Map<String, dynamic>>();
      final isEducation = agents.any((a) => (a['industry']?.toString().toLowerCase() ?? '') == 'education');
      final firstAgentId = agents.isNotEmpty ? (agents.first['id'] ?? agents.first['agent_id'])?.toString() : null;

      bool? hasBalance;
      bool? isOverdue;
      String? dueAfter;
      String? dueBefore;
      final filter = state.filterStatus;
      if (isEducation && filter != 'all') {
        if (filter == 'with_balance') hasBalance = true;
        else if (filter == 'overdue') isOverdue = true;
        else if (filter == 'due_this_week') {
          final now = DateTime.now();
          dueAfter = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final end = now.add(const Duration(days: 7));
          dueBefore = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
        } else if (filter == 'no_balance') hasBalance = false;
      }

      final res = await NeyvoPulseApi.listStudents(
        hasBalance: hasBalance,
        isOverdue: isOverdue,
        dueAfter: dueAfter,
        dueBefore: dueBefore,
      );
      final list = res['students'] as List? ?? const [];
      final filtered = _applyFilter(
        all: list,
        query: state.searchQuery,
        filterStatus: state.filterStatus,
      );
      state = state.copyWith(
        loading: false,
        isEducationOrg: isEducation,
        agents: agents,
        selectedAgentId: (state.selectedAgentId?.trim().isNotEmpty ?? false) ? state.selectedAgentId : firstAgentId?.trim(),
        allStudents: list,
        filteredStudents: filtered,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setSearchQuery(String query) {
    final filtered = _applyFilter(all: state.allStudents, query: query, filterStatus: state.filterStatus);
    state = state.copyWith(searchQuery: query, filteredStudents: filtered);
  }

  Future<void> setFilterStatus(String filter) async {
    state = state.copyWith(filterStatus: filter);
    await load();
  }

  void toggleSelection(String id) {
    final next = Set<String>.from(state.selectedIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(selectedIds: next);
  }

  void setSelectionMode(bool enabled) {
    state = state.copyWith(selectionMode: enabled, selectedIds: enabled ? state.selectedIds : <String>{});
  }

  void clearSelection() {
    state = state.copyWith(selectionMode: false, selectedIds: <String>{});
  }

  Future<void> loadReminders() async {
    state = state.copyWith(remindersLoading: true);
    try {
      final res = await NeyvoPulseApi.listReminders();
      state = state.copyWith(
        reminders: res['reminders'] as List? ?? res['data'] as List? ?? const [],
        remindersLoading: false,
      );
    } catch (_) {
      state = state.copyWith(reminders: const [], remindersLoading: false);
    }
  }

  void setSelectedAgentId(String? id) {
    state = state.copyWith(selectedAgentId: id);
  }
}
