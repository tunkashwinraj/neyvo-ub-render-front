import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';
import 'api_provider.dart';

part 'call_history_provider.g.dart';

enum CallHistorySort { dateNewest, dateOldest, durationLongest, durationShortest }

class CallHistoryState {
  const CallHistoryState({
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.allCalls = const [],
    this.fetchSize = 50,
    this.dateRange = 'all',
    this.filterStatus = 'all',
    this.filterOutcome = 'all',
    this.filterDirection = 'outbound',
    this.sortBy = CallHistorySort.dateNewest,
    this.searchQuery = '',
    this.hasMore = true,
  });

  final bool loading;
  final bool loadingMore;
  final String? error;
  final List<Map<String, dynamic>> allCalls;
  final int fetchSize;
  final String dateRange;
  final String filterStatus;
  final String filterOutcome;
  final String filterDirection;
  final CallHistorySort sortBy;
  final String searchQuery;
  final bool hasMore;

  static const List<int> fetchSizeOptions = [20, 50, 100, 200, 500];

  CallHistoryState copyWith({
    bool? loading,
    bool? loadingMore,
    String? error,
    List<Map<String, dynamic>>? allCalls,
    int? fetchSize,
    String? dateRange,
    String? filterStatus,
    String? filterOutcome,
    String? filterDirection,
    CallHistorySort? sortBy,
    String? searchQuery,
    bool? hasMore,
    bool clearError = false,
  }) {
    return CallHistoryState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      allCalls: allCalls ?? this.allCalls,
      fetchSize: fetchSize ?? this.fetchSize,
      dateRange: dateRange ?? this.dateRange,
      filterStatus: filterStatus ?? this.filterStatus,
      filterOutcome: filterOutcome ?? this.filterOutcome,
      filterDirection: filterDirection ?? this.filterDirection,
      sortBy: sortBy ?? this.sortBy,
      searchQuery: searchQuery ?? this.searchQuery,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  (String?, String?) dateRangeParams() {
    if (dateRange == 'all') return (null, null);
    final now = DateTime.now();
    final toStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (dateRange == '7d') {
      final from = now.subtract(const Duration(days: 7));
      final fromStr =
          '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
      return (fromStr, toStr);
    }
    if (dateRange == '30d') {
      final from = now.subtract(const Duration(days: 30));
      final fromStr =
          '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
      return (fromStr, toStr);
    }
    return (null, null);
  }

  bool _isInDateRange(Map<String, dynamic> call) {
    if (dateRange == 'all') return true;
    final created =
        call['started_at'] ?? call['created_at'] ?? call['date'] ?? call['timestamp'];
    if (created == null) return true;
    DateTime? dt;
    if (created is String) dt = DateTime.tryParse(created);
    if (created is int) dt = DateTime.fromMillisecondsSinceEpoch(created);
    if (dt == null) return true;
    final now = DateTime.now();
    if (dateRange == '7d') return now.difference(dt).inDays <= 7;
    if (dateRange == '30d') return now.difference(dt).inDays <= 30;
    return true;
  }

  static int _durationSeconds(Map<String, dynamic> c) {
    final sec = c['duration_seconds'];
    if (sec is int) return sec;
    if (sec != null) return int.tryParse(sec.toString()) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  static DateTime _callDateForSort(Map<String, dynamic> c) {
    final dates = [
      _parseDate(c['ended_at']),
      _parseDate(c['updated_at']),
      _parseDate(c['started_at']),
      _parseDate(c['created_at']),
      _parseDate(c['date']),
      _parseDate(c['timestamp']),
    ].whereType<DateTime>().toList();
    if (dates.isEmpty) return DateTime(0);
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  List<Map<String, dynamic>> get filteredCalls {
    final query = searchQuery.trim().toLowerCase();
    var list = allCalls.where((c) {
      if (!_isInDateRange(c)) return false;
      if (filterDirection != 'all') {
        final dir = (c['direction'] as String?)?.toLowerCase();
        if (dir != filterDirection) return false;
      }
      final contactName = (c['student_name'] ??
              c['contact_name'] ??
              c['customer_name'] ??
              c['agent_name'] ??
              '')
          .toString()
          .toLowerCase();
      final phone =
          (c['student_phone'] ?? c['to'] ?? c['phone_number'] ?? '').toString().toLowerCase();
      if (query.isNotEmpty && !contactName.contains(query) && !phone.contains(query)) {
        return false;
      }
      if (filterStatus != 'all') {
        final status = (c['status']?.toString() ?? '').toLowerCase();
        if (status != filterStatus) return false;
      }
      if (filterOutcome != 'all') {
        final outcome = (c['outcome'] ?? c['status'] ?? '').toString().toLowerCase();
        if (outcome != filterOutcome) return false;
      }
      return true;
    }).toList();
    list.sort((a, b) {
      switch (sortBy) {
        case CallHistorySort.dateNewest:
          final da = _callDateForSort(a);
          final db = _callDateForSort(b);
          return db.compareTo(da);
        case CallHistorySort.dateOldest:
          final da = _callDateForSort(a);
          final db = _callDateForSort(b);
          return da.compareTo(db);
        case CallHistorySort.durationLongest:
          return _durationSeconds(b).compareTo(_durationSeconds(a));
        case CallHistorySort.durationShortest:
          return _durationSeconds(a).compareTo(_durationSeconds(b));
      }
    });
    return list;
  }
}

@riverpod
class CallHistoryNotifier extends _$CallHistoryNotifier {
  @override
  CallHistoryState build() {
    ref.watch(speariaApiProvider);
    return const CallHistoryState(loading: true);
  }

  void seedInitialDirection(String initialDirection) {
    var d = initialDirection.toLowerCase().trim();
    if (d != 'inbound' && d != 'outbound' && d != 'all') d = 'outbound';
    state = state.copyWith(filterDirection: d);
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final (fromStr, toStr) = state.dateRangeParams();
      final res = await NeyvoPulseApi.listCalls(
        limit: state.fetchSize,
        offset: 0,
        from: fromStr,
        to: toStr,
      );
      final list = res['calls'];
      final calls = list is List
          ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      var err = state.error;
      if (res['ok'] != true && err == null) {
        err = res['error']?.toString() ?? 'Failed to load call logs';
      }
      state = state.copyWith(
        loading: false,
        error: err,
        allCalls: calls,
        hasMore: calls.length >= state.fetchSize,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
        allCalls: const [],
        hasMore: false,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore || state.loading) return;
    state = state.copyWith(loadingMore: true);
    try {
      final (fromStr, toStr) = state.dateRangeParams();
      final res = await NeyvoPulseApi.listCalls(
        limit: state.fetchSize,
        offset: state.allCalls.length,
        from: fromStr,
        to: toStr,
      );
      final list = res['calls'];
      final newCalls = list is List
          ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      state = state.copyWith(
        loadingMore: false,
        allCalls: [...state.allCalls, ...newCalls],
        hasMore: newCalls.length >= state.fetchSize,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  void setSearchQuery(String q) => state = state.copyWith(searchQuery: q);

  void setFetchSize(int n) => state = state.copyWith(fetchSize: n);

  void setDateRange(String r) => state = state.copyWith(dateRange: r);

  void setFilterStatus(String s) => state = state.copyWith(filterStatus: s);

  void setFilterOutcome(String o) => state = state.copyWith(filterOutcome: o);

  void setFilterDirection(String d) => state = state.copyWith(filterDirection: d);

  void setSortBy(CallHistorySort s) => state = state.copyWith(sortBy: s);

  void clearSearch() => state = state.copyWith(searchQuery: '');

  Future<bool> deleteCallLog(String callId) async {
    final res = await NeyvoPulseApi.deleteCalls([callId]);
    if (res['ok'] == true) {
      state = state.copyWith(
        allCalls: state.allCalls
            .where((c) => (c['id'] ?? c['call_id'] ?? '').toString() != callId)
            .toList(),
      );
      return true;
    }
    return false;
  }
}
