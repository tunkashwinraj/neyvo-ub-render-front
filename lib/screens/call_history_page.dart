// lib/screens/call_history_page.dart
// Call logs – history with filters, date range, transcripts, export, recording link

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../neyvo_pulse_api.dart';
import '../services/user_timezone_service.dart';
import '../utils/export_csv.dart';
import '../theme/neyvo_theme.dart';
import 'call_detail_page.dart';

/// Sort options: date desc/asc, duration desc/asc (when backend provides duration)
enum _CallSort { dateNewest, dateOldest, durationLongest, durationShortest }

class CallHistoryPage extends StatefulWidget {
  const CallHistoryPage({
    super.key,
    this.initialDirection = 'outbound', // all | inbound | outbound
  });

  final String initialDirection;

  @override
  State<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends State<CallHistoryPage> {
  List<dynamic> _allCalls = [];
  List<dynamic> _filteredCalls = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _filterStatus = 'all'; // all, completed, failed, pending
  String _filterOutcome = 'all'; // all, callback, booked, handoff, missed, completed
  String _filterDirection = 'outbound'; // all, inbound, outbound (default to outbound)
  String _dateRange = 'all'; // all, 7d, 30d
  _CallSort _sortBy = _CallSort.dateNewest;
  final Set<String> _selectedCallIds = <String>{};
  bool _selectionMode = false;
  /// User-selectable number of call logs to fetch per page (20, 50, 100, 200, 500).
  int _fetchSize = 20;
  bool _hasMore = true;
  bool _loadingMore = false;
  static const List<int> _fetchSizeOptions = [20, 50, 100, 200, 500];
  Timer? _autoRefreshTimer;

  static const int _rowsPerPage = 20;
  int _currentPage = 0;

  List<dynamic> get _paginatedCalls {
    final start = _currentPage * _rowsPerPage;
    if (start >= _filteredCalls.length) return [];
    return _filteredCalls.sublist(start, (start + _rowsPerPage).clamp(0, _filteredCalls.length));
  }

  int get _totalPages => (_filteredCalls.length / _rowsPerPage).ceil().clamp(1, 999);
  int get _effectivePage => _currentPage.clamp(0, _totalPages - 1);

  @override
  void initState() {
    super.initState();
    _filterDirection = (widget.initialDirection).toLowerCase().trim();
    if (_filterDirection != 'inbound' && _filterDirection != 'outbound' && _filterDirection != 'all') {
      _filterDirection = 'outbound';
    }
    _searchController.addListener(_filterCalls);
    _load();
    // Auto-refresh so recent and campaign calls appear without manual refresh
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!mounted || _loading) return;
      _load(showLoading: false);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
        _selectionMode = false;
        _selectedCallIds.clear();
      });
    }
    try {
      // Ensure account is set so backend returns calls for the correct org
      if (NeyvoPulseApi.defaultAccountId.isEmpty) {
        final accountRes = await NeyvoPulseApi.getAccountInfo();
        final accountId = (accountRes['account_id'] ?? accountRes['id'] ?? '').toString().trim();
        if (accountId.isNotEmpty) NeyvoPulseApi.setDefaultAccountId(accountId);
      }
      final now = DateTime.now();
      String? fromDate;
      String? toDate;
      if (_dateRange == '7d') {
        fromDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)).toIso8601String().split('T').first;
        toDate = now.toIso8601String().split('T').first;
      } else if (_dateRange == '30d') {
        fromDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)).toIso8601String().split('T').first;
        toDate = now.toIso8601String().split('T').first;
      }
      final list = (await NeyvoPulseApi.listCalls(limit: _fetchSize, offset: 0, from: fromDate, to: toDate))['calls'] as List? ?? [];
      if (mounted) {
        setState(() {
          _allCalls = list;
          _filteredCalls = list;
          _hasMore = list.length >= _fetchSize;
          _loading = false;
        });
        _filterCalls();
      }
    } catch (e) {
      if (mounted) setState(() {
        if (showLoading) {
          _error = e.toString();
          _loading = false;
        }
        // background refresh: leave list and error as-is
      });
    }
  }

  bool _isInDateRange(dynamic call) {
    if (_dateRange == 'all') return true;
    final created = call['created_at'] ?? call['date'] ?? call['timestamp'];
    if (created == null) return true;
    DateTime? dt;
    if (created is String) dt = DateTime.tryParse(created);
    if (created is int) dt = DateTime.fromMillisecondsSinceEpoch(created);
    if (dt == null) return true;
    final now = DateTime.now();
    if (_dateRange == '7d') return now.difference(dt).inDays <= 7;
    if (_dateRange == '30d') return now.difference(dt).inDays <= 30;
    return true;
  }

  /// Duration in seconds (int) or duration string from backend
  static String formatDuration(dynamic call) {
    final sec = call['duration_seconds'] ?? call['duration_sec'];
    if (sec != null) {
      final s = sec is int ? sec : int.tryParse(sec.toString()) ?? 0;
      if (s < 60) return '${s}s';
      final m = s ~/ 60;
      final r = s % 60;
      return r > 0 ? '${m}m ${r}s' : '${m}m';
    }
    final d = call['duration']?.toString();
    return d?.isNotEmpty == true ? d! : '—';
  }

  static int _durationSeconds(dynamic c) {
    final sec = c['duration_seconds'];
    if (sec is int) return sec;
    if (sec != null) return int.tryParse(sec.toString()) ?? 0;
    return 0;
  }

  static DateTime? _callDate(dynamic c) {
    final created = c['created_at'] ?? c['date'] ?? c['timestamp'];
    if (created == null) return null;
    if (created is String) return DateTime.tryParse(created);
    if (created is int) return DateTime.fromMillisecondsSinceEpoch(created);
    return null;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
    _filterCalls();
  }

  void _filterCalls() {
    // Search only in current page: filter by name/phone + date, direction, status, outcome.
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _currentPage = 0;
      var list = _allCalls.where((c) {
        if (!_isInDateRange(c)) return false;
        if (_filterDirection != 'all') {
          final dir = (c['direction'] as String?)?.toLowerCase();
          if (dir != _filterDirection) return false;
        }
        final contactName = (c['student_name'] ?? c['contact_name'] ?? c['customer_name'] ?? c['agent_name'] ?? '').toString().toLowerCase();
        final phone = (c['student_phone'] ?? c['to'] ?? c['phone_number'] ?? '').toString().toLowerCase();
        if (query.isNotEmpty && !contactName.contains(query) && !phone.contains(query)) return false;
        if (_filterStatus != 'all') {
          final status = (c['status']?.toString() ?? '').toLowerCase();
          if (status != _filterStatus) return false;
        }
        if (_filterOutcome != 'all') {
          final outcome = (c['outcome'] ?? c['status'] ?? '').toString().toLowerCase();
          if (outcome != _filterOutcome) return false;
        }
        return true;
      }).toList();
      // Sort
      list = List.from(list);
      list.sort((a, b) {
        switch (_sortBy) {
          case _CallSort.dateNewest:
            final da = _callDate(a) ?? DateTime(0);
            final db = _callDate(b) ?? DateTime(0);
            return db.compareTo(da);
          case _CallSort.dateOldest:
            final da = _callDate(a) ?? DateTime(0);
            final db = _callDate(b) ?? DateTime(0);
            return da.compareTo(db);
          case _CallSort.durationLongest:
            return _durationSeconds(b).compareTo(_durationSeconds(a));
          case _CallSort.durationShortest:
            return _durationSeconds(a).compareTo(_durationSeconds(b));
        }
      });
      _filteredCalls = list;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedCallIds.clear();
      _selectionMode = false;
    });
  }

  void _toggleSelectionForCall(Map<String, dynamic> call) {
    final id = call['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() {
      if (_selectedCallIds.contains(id)) {
        _selectedCallIds.remove(id);
      } else {
        _selectedCallIds.add(id);
      }
      _selectionMode = _selectedCallIds.isNotEmpty;
    });
  }

  void _selectAllVisible() {
    setState(() {
      _selectedCallIds
        ..clear()
        ..addAll(_filteredCalls.map<String>((c) => (c as Map<String, dynamic>)['id']?.toString() ?? '').where((id) => id.isNotEmpty));
      _selectionMode = _selectedCallIds.isNotEmpty;
    });
  }

  Future<void> _onDeleteSelected() async {
    if (_selectedCallIds.isEmpty) return;
    final count = _selectedCallIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete calls'),
          content: Text('Are you sure you want to delete $count selected call${count == 1 ? '' : 's'}? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      final ids = _selectedCallIds.toList();
      final res = await NeyvoPulseApi.deleteCalls(ids);
      if (res['ok'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error']?.toString() ?? 'Failed to delete calls')),
          );
        }
        return;
      }
      setState(() {
        _allCalls = _allCalls.where((c) {
          final id = (c as Map<String, dynamic>)['id']?.toString() ?? '';
          return !_selectedCallIds.contains(id);
        }).toList();
        _selectedCallIds.clear();
        _selectionMode = false;
        _filterCalls();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $count call${count == 1 ? '' : 's'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete calls: $e')),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    final offset = _allCalls.length;
    setState(() {
      _loadingMore = true;
    });
    try {
      final now = DateTime.now();
      String? fromDate;
      String? toDate;
      if (_dateRange == '7d') {
        fromDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)).toIso8601String().split('T').first;
        toDate = now.toIso8601String().split('T').first;
      } else if (_dateRange == '30d') {
        fromDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)).toIso8601String().split('T').first;
        toDate = now.toIso8601String().split('T').first;
      }
      final list = (await NeyvoPulseApi.listCalls(limit: _fetchSize, offset: offset, from: fromDate, to: toDate))['calls'] as List? ?? [];
      if (mounted) {
        final existingIds = _allCalls
            .map<String>((c) => (c as Map<String, dynamic>)['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        final newCalls = list.where((c) {
          final id = (c as Map<String, dynamic>)['id']?.toString() ?? '';
          return id.isNotEmpty && !existingIds.contains(id);
        }).toList();
        setState(() {
          _allCalls = [..._allCalls, ...newCalls];
          _filteredCalls = _allCalls;
          _hasMore = list.length >= _fetchSize;
          _loadingMore = false;
        });
        _filterCalls();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _exportCsv() async {
    final sb = StringBuffer();
    sb.writeln('Contact Name,Phone,Date,Status,Duration,Recording URL,Transcript');
    for (final c in _filteredCalls) {
      final map = c as Map<String, dynamic>;
      final name = (map['student_name']?.toString() ?? '').replaceAll(',', ';');
      final phone = map['student_phone']?.toString() ?? '';
      final date = (map['created_at_display'] ?? map['created_at'] ?? map['date'] ?? '').toString();
      final status = map['status']?.toString() ?? '';
      final duration = formatDuration(map);
      final recording = map['recording_url']?.toString() ?? '';
      final transcript = (map['transcript']?.toString() ?? '').replaceAll(RegExp(r'[\r\n]'), ' ');
      sb.writeln('"$name","$phone","$date","$status","$duration","$recording","$transcript"');
    }
    final filename = 'call_history_${DateTime.now().toIso8601String().split('T').first}.csv';
    await downloadCsv(filename, sb.toString(), context);
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'resolved':
        return NeyvoTheme.success;
      case 'failed':
      case 'error':
      case 'unresolved':
        return NeyvoTheme.error;
      case 'pending':
      case 'ringing':
        return NeyvoTheme.warning;
      case 'transferred':
      case 'no_answer':
        return NeyvoTheme.info;
      default:
        return NeyvoTheme.textMuted;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'success':
        return Icons.check_circle;
      case 'failed':
      case 'error':
        return Icons.error;
      case 'pending':
      case 'ringing':
        return Icons.access_time;
      default:
        return Icons.phone;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Call History')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Something went wrong', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                const SizedBox(height: NeyvoSpacing.sm),
                Text(_error!, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary), textAlign: TextAlign.center),
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
        title: const Text('Call History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh (load latest $_fetchSize calls)',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            // Title + top-right actions (same format as Student section)
            Padding(
              padding: const EdgeInsets.fromLTRB(NeyvoSpacing.lg, NeyvoSpacing.md, NeyvoSpacing.lg, NeyvoSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Data Table', style: NeyvoType.headlineMedium.copyWith(fontWeight: FontWeight.w600)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loading ? null : _load,
                        tooltip: 'Refresh',
                      ),
                      OutlinedButton.icon(
                        onPressed: _filteredCalls.isEmpty ? null : _exportCsv,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Export'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: NeyvoColors.ubLightBlue,
                          side: BorderSide(color: NeyvoColors.ubLightBlue.withOpacity(0.6)),
                        ),
                      ),
                      if (_selectionMode) ...[
                        const SizedBox(width: NeyvoSpacing.sm),
                        FilledButton.icon(
                          onPressed: _selectedCallIds.isEmpty ? null : _onDeleteSelected,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete selected'),
                          style: FilledButton.styleFrom(backgroundColor: NeyvoColors.error),
                        ),
                        TextButton(
                          onPressed: _clearSelection,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search in current page (name or phone)',
                  filled: true,
                  fillColor: NeyvoColors.bgOverlay,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: NeyvoColors.borderSubtle),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: _clearSearch)
                      : const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.search, color: NeyvoColors.textMuted)),
                ),
              ),
            ),
            const SizedBox(height: NeyvoSpacing.sm),
            // Filter dropdowns
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg),
              child: IntrinsicHeight(
                child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<String>(
                            value: _filterDirection,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              labelText: 'Direction',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'inbound', child: Text('Inbound', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'outbound', child: Text('Outbound', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) { setState(() { _filterDirection = v ?? 'all'; _filterCalls(); }); },
                          ),
                        ),
                        const SizedBox(width: NeyvoSpacing.sm),
                        SizedBox(
                          width: 160,
                          child: DropdownButtonFormField<String>(
                            value: _dateRange,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              labelText: 'Date',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All time', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: '7d', child: Text('Last 7 days', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: '30d', child: Text('Last 30 days', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) { setState(() { _dateRange = v ?? 'all'; }); _load(); },
                          ),
                        ),
                        const SizedBox(width: NeyvoSpacing.sm),
                        SizedBox(
                          width: 140,
                          child: DropdownButtonFormField<int>(
                            value: _fetchSize,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              labelText: 'Show',
                            ),
                            items: _fetchSizeOptions.map((n) => DropdownMenuItem(value: n, child: Text('$n calls', overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) { if (v != null) { setState(() { _fetchSize = v; }); _load(); } },
                          ),
                        ),
                        const SizedBox(width: NeyvoSpacing.sm),
                        SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<String>(
                            value: _filterStatus,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              labelText: 'Status',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'completed', child: Text('Completed', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'failed', child: Text('Failed', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'pending', child: Text('Pending', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) { setState(() { _filterStatus = v ?? 'all'; _filterCalls(); }); },
                          ),
                        ),
                        const SizedBox(width: NeyvoSpacing.sm),
                        SizedBox(
                          width: 140,
                          child: DropdownButtonFormField<String>(
                            value: _filterOutcome,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              labelText: 'Outcome',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'callback', child: Text('Callback', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'booked', child: Text('Booked', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'handoff', child: Text('Handoff', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'missed', child: Text('Missed', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'completed', child: Text('Completed', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) { setState(() { _filterOutcome = v ?? 'all'; _filterCalls(); }); },
                          ),
                        ),
                        const SizedBox(width: NeyvoSpacing.sm),
                        SizedBox(
                          width: 190,
                          child: DropdownButtonFormField<_CallSort>(
                            value: _sortBy,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              labelText: 'Sort',
                            ),
                            items: const [
                              DropdownMenuItem(value: _CallSort.dateNewest, child: Text('Date (newest)', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: _CallSort.dateOldest, child: Text('Date (oldest)', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: _CallSort.durationLongest, child: Text('Duration (longest)', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: _CallSort.durationShortest, child: Text('Duration (shortest)', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) { setState(() { _sortBy = v ?? _CallSort.dateNewest; _filterCalls(); }); },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ),
            const SizedBox(height: NeyvoSpacing.md),
            // Table or empty state
            if (_filteredCalls.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_outlined, size: 64, color: NeyvoColors.textMuted),
                      const SizedBox(height: NeyvoSpacing.md),
                      Text(
                        _allCalls.isEmpty ? 'No calls yet. Assign a phone number to an agent to start receiving calls.' : 'No calls found',
                        style: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (_selectionMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg),
                  child: Row(
                    children: [
                      Text('${_selectedCallIds.length} selected', style: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.textSecondary)),
                      const SizedBox(width: NeyvoSpacing.md),
                      TextButton(onPressed: _selectAllVisible, child: const Text('Select all')),
                      TextButton(onPressed: _clearSelection, child: const Text('Clear')),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(NeyvoColors.ubLightBlue.withOpacity(0.2)),
                      headingTextStyle: NeyvoType.labelMedium.copyWith(fontWeight: FontWeight.w600, color: NeyvoColors.textLightPrimary),
                      columns: [
                        if (_selectionMode)
                          const DataColumn(label: SizedBox(width: 40, child: Text(''))),
                        DataColumn(label: Text('Name', style: NeyvoType.labelMedium)),
                        DataColumn(label: Text('Phone', style: NeyvoType.labelMedium)),
                        DataColumn(label: Text('Outcome', style: NeyvoType.labelMedium)),
                        DataColumn(label: Text('Date & time', style: NeyvoType.labelMedium)),
                        DataColumn(label: Text('Status', style: NeyvoType.labelMedium)),
                        DataColumn(label: Text('Duration', style: NeyvoType.labelMedium)),
                        DataColumn(label: Text('Credits', style: NeyvoType.labelMedium)),
                        const DataColumn(label: SizedBox(width: 56, child: Text('Actions'))),
                      ],
                      rows: _paginatedCalls.map<DataRow>((c) {
                        final call = c as Map<String, dynamic>;
                        final callId = call['id']?.toString() ?? '';
                        final isSelected = callId.isNotEmpty && _selectedCallIds.contains(callId);
                        final status = call['status']?.toString() ?? '—';
                        final studentName = (call['student_name'] ?? call['contact_name'] ?? call['caller'] ?? '—').toString();
                        final studentPhone = (call['student_phone'] ?? call['to'] ?? call['phone_number'] ?? '—').toString();
                        final outcome = (call['outcome'] ?? call['outcome_type'] ?? call['status'] ?? '—').toString();
                        final dateRaw = call['started_at'] ?? call['created_at'] ?? call['timestamp'] ?? call['date'];
                        final date = dateRaw != null ? UserTimezoneService.formatShort(dateRaw) : '—';
                        final durationStr = formatDuration(call);
                        final creditsUsed = (call['credits_used'] ?? call['credits_charged']) as num?;
                        final creditsStr = creditsUsed != null ? '${creditsUsed is int ? creditsUsed : creditsUsed.toInt()} cr' : '—';
                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: _selectionMode
                              ? (_) => _toggleSelectionForCall(call)
                              : null,
                          cells: [
                            if (_selectionMode)
                              DataCell(Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelectionForCall(call),
                                activeColor: NeyvoTheme.primary,
                              )),
                            DataCell(Text(studentName, style: NeyvoType.bodySmall)),
                            DataCell(Text(studentPhone, style: NeyvoType.bodySmall)),
                            DataCell(Text(outcome, style: NeyvoType.bodySmall)),
                            DataCell(Text(date, style: NeyvoType.bodySmall)),
                            DataCell(Text(status.toUpperCase(), style: NeyvoType.bodySmall)),
                            DataCell(Text(durationStr, style: NeyvoType.bodySmall)),
                            DataCell(Text(creditsStr, style: NeyvoType.bodySmall)),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.open_in_new, size: 20),
                                color: NeyvoColors.ubLightBlue,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => CallDetailPage(call: call)),
                                ),
                                tooltip: 'View details',
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              // Pagination bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg, vertical: NeyvoSpacing.sm),
                decoration: BoxDecoration(
                  color: NeyvoColors.bgOverlay,
                  border: Border(top: BorderSide(color: NeyvoColors.borderSubtle)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _effectivePage > 0 ? () => setState(() => _currentPage = _effectivePage - 1) : null,
                    ),
                    if (_totalPages <= 12)
                      ...List.generate(_totalPages, (i) {
                        final isCurrent = i == _effectivePage;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Material(
                            color: isCurrent ? NeyvoColors.ubLightBlue : NeyvoColors.bgRaised,
                            borderRadius: BorderRadius.circular(6),
                            child: InkWell(
                              onTap: () => setState(() => _currentPage = i),
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: NeyvoType.labelSmall.copyWith(
                                      color: isCurrent ? NeyvoColors.white : NeyvoColors.textPrimary,
                                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      })
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Page ${_effectivePage + 1} of $_totalPages', style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textSecondary)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _effectivePage < _totalPages - 1 ? () => setState(() => _currentPage = _effectivePage + 1) : null,
                    ),
                  ],
                ),
              ),
            ],
            // Keep Load more below table when there are more calls from API
            if (_hasMore && _filteredCalls.length >= _allCalls.length)
              Padding(
                padding: const EdgeInsets.only(left: NeyvoSpacing.lg, right: NeyvoSpacing.lg, bottom: NeyvoSpacing.md),
                child: OutlinedButton(
                  onPressed: _loadingMore ? null : _loadMore,
                  child: _loadingMore
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Load more calls'),
                ),
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
      label: Text(label, style: NeyvoType.bodySmall.copyWith(color: selected ? NeyvoTheme.teal : NeyvoTheme.textSecondary)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: NeyvoTheme.teal.withOpacity(0.2),
      checkmarkColor: NeyvoTheme.teal,
      backgroundColor: NeyvoTheme.bgCard,
      side: BorderSide(color: selected ? NeyvoTheme.teal : NeyvoTheme.border),
    );
  }
}
