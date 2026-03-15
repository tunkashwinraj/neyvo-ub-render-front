// lib/screens/call_history_page.dart
// Call logs ? history with filters, date range, transcripts, export, recording link

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

  @override
  void initState() {
    super.initState();
    _filterDirection = (widget.initialDirection).toLowerCase().trim();
    if (_filterDirection != 'inbound' && _filterDirection != 'outbound' && _filterDirection != 'all') {
      _filterDirection = 'outbound';
    }
    _searchController.addListener(_filterCalls);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Build from/to date params for API (YYYY-MM-DD). Returns null for 'all'.
  (String? fromStr, String? toStr) _dateRangeParams() {
    if (_dateRange == 'all') return (null, null);
    final now = DateTime.now();
    final toStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (_dateRange == '7d') {
      final from = now.subtract(const Duration(days: 7));
      final fromStr = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
      return (fromStr, toStr);
    }
    if (_dateRange == '30d') {
      final from = now.subtract(const Duration(days: 30));
      final fromStr = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
      return (fromStr, toStr);
    }
    return (null, null);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectionMode = false;
      _selectedCallIds.clear();
    });
    try {
      final (fromStr, toStr) = _dateRangeParams();
      final res = await NeyvoPulseApi.listCalls(
        limit: _fetchSize,
        offset: 0,
        from: fromStr,
        to: toStr,
      );
      if (!mounted) return;
      final list = res['calls'];
      final calls = list is List ? List<dynamic>.from(list) : <dynamic>[];
      setState(() {
        _allCalls = calls;
        _hasMore = calls.length >= _fetchSize;
        _loading = false;
        if (res['ok'] != true && _error == null) {
          _error = res['error']?.toString() ?? 'Failed to load call logs';
        }
      });
      _filterCalls();
    } catch (e) {
      if (mounted) {
        setState(() {
          _allCalls = [];
          _filteredCalls = [];
          _hasMore = false;
          _loading = false;
          _error = e.toString();
        });
        _filterCalls();
      }
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
    return d?.isNotEmpty == true ? d! : '?';
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
    setState(() => _loadingMore = true);
    try {
      final (fromStr, toStr) = _dateRangeParams();
      final res = await NeyvoPulseApi.listCalls(
        limit: _fetchSize,
        offset: _allCalls.length,
        from: fromStr,
        to: toStr,
      );
      if (!mounted) return;
      final list = res['calls'];
      final newCalls = list is List ? List<dynamic>.from(list) : <dynamic>[];
      setState(() {
        _allCalls = [..._allCalls, ...newCalls];
        _hasMore = newCalls.length >= _fetchSize;
        _loadingMore = false;
      });
      _filterCalls();
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Search + inline filters (single row)
              Container(
            padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.md, vertical: NeyvoSpacing.sm),
            decoration: BoxDecoration(
              color: NeyvoTheme.bgSurface,
              border: Border(bottom: BorderSide(color: NeyvoTheme.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search in current page (name or phone)',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: _clearSearch,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: NeyvoSpacing.md),
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: _filteredCalls.isEmpty ? null : _exportCsv,
                      tooltip: 'Export CSV',
                    ),
                  ],
                ),
                const SizedBox(height: NeyvoSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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
              ],
            ),
              ),
              
              // Calls List (single page scroll: list does not scroll independently)
              if (_filteredCalls.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(NeyvoSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_outlined, size: 64, color: NeyvoTheme.textMuted),
                      const SizedBox(height: NeyvoSpacing.md),
                      Text(
                        _allCalls.isEmpty ? 'No calls yet. Assign a phone number to an agent to start receiving calls.' : 'No calls found',
                        style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else ...[
                ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NeyvoSpacing.sm,
                    vertical: NeyvoSpacing.sm,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredCalls.length + 1 + (_selectionMode ? 1 : 0),
                  itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: NeyvoSpacing.sm,
                              vertical: NeyvoSpacing.sm,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Calls (${_filteredCalls.length})',
                                  style: NeyvoType.headlineMedium.copyWith(color: NeyvoTheme.textPrimary),
                                ),
                                if (_filteredCalls.length != _allCalls.length)
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _filterStatus = 'all';
                                        _filterOutcome = 'all';
                                      });
                                      _filterCalls();
                                    },
                                    child: const Text('Clear filters'),
                                  ),
                              ],
                            ),
                          );
                        }
                        if (_selectionMode && i == 1) {
                          final totalVisible = _filteredCalls.length;
                          final selectedCount = _selectedCallIds.length;
                          final allSelected = selectedCount > 0 && selectedCount >= totalVisible;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(NeyvoSpacing.md, 0, NeyvoSpacing.md, NeyvoSpacing.sm),
                            child: Row(
                              children: [
                                Text(
                                  '$selectedCount selected',
                                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
                                ),
                                const Spacer(),
                                if (selectedCount > 0)
                                  FilledButton.icon(
                                    onPressed: _onDeleteSelected,
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Delete'),
                                  ),
                                const SizedBox(width: NeyvoSpacing.sm),
                                TextButton(
                                  onPressed: allSelected ? _clearSelection : _selectAllVisible,
                                  child: Text(allSelected ? 'Clear' : 'Select all'),
                                ),
                              ],
                            ),
                          );
                        }
                        final idx = _selectionMode ? i - 2 : i - 1;
                        final call = _filteredCalls[idx] as Map<String, dynamic>;
                        final callId = call['id']?.toString() ?? '';
                        final isSelected = callId.isNotEmpty && _selectedCallIds.contains(callId);
                        final status = call['status']?.toString() ?? 'unknown';
                        final studentName = (call['student_name'] ?? call['contact_name'] ?? call['caller'] ?? 'Unknown').toString();
                        final studentPhone = (call['student_phone'] ?? call['to'] ?? call['phone_number'] ?? '').toString();
                        final agentName = (call['profile_name'] ?? call['agent_name'] ?? call['managed_profile_name'] ?? '').toString();
                        final numberCalled = (call['number_called'] ?? call['from'] ?? call['phone_number_id'] ?? '').toString();
                        final outcome = (call['outcome'] ?? call['outcome_type'] ?? call['status'] ?? '').toString();
                        final dateRaw = call['started_at'] ?? call['created_at'] ?? call['timestamp'] ?? call['date'];
                        final date = dateRaw != null ? UserTimezoneService.formatShort(dateRaw) : '';
                        final durationStr = formatDuration(call);
                        final transcript = call['transcript']?.toString() ?? '';
                        final recordingUrl = call['recording_url']?.toString();
                        final statusColor = _getStatusColor(status);
                        final successMetric = call['success_metric']?.toString();
                        final attributedAmount = call['attributed_payment_amount']?.toString();
                        final attributedAt = call['attributed_payment_at']?.toString();
                        final outcomeType = call['outcome_type']?.toString();
                        final creditsUsed = (call['credits_used'] ?? call['credits_charged']) as num?;
                        final voiceTier = (call['voice_tier'] as String?)?.toLowerCase() ?? '';
                        final creditsStr = creditsUsed != null ? '${creditsUsed is int ? creditsUsed : creditsUsed.toInt()} cr' : null;
                        final tooltipStr = creditsStr != null
                            ? '$creditsStr ? $durationStr${voiceTier.isNotEmpty ? ' ? ${voiceTier == 'neutral' ? 'Neutral' : voiceTier == 'natural' ? 'Natural' : voiceTier == 'ultra' ? 'Ultra' : voiceTier}' : ''}'
                            : null;
                        final routedIntentRaw = (call['routed_intent'] ?? call['primary_intent'] ?? call['analysis']?['primaryIntent']);
                        final routedIntent = routedIntentRaw == null
                            ? ''
                            : routedIntentRaw.toString().trim();
                        
                        final showNumberCalled = numberCalled.isNotEmpty && numberCalled != studentPhone;

                        return Card(
                          margin: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                          child: InkWell(
                            onLongPress: () {
                              if (!_selectionMode) {
                                setState(() {
                                  _selectionMode = true;
                                  _selectedCallIds
                                    ..clear()
                                    ..add(callId);
                                });
                              }
                            },
                            onTap: _selectionMode
                                ? () => _toggleSelectionForCall(call)
                                : null,
                            child: ExpansionTile(
                              trailing: IconButton(
                                icon: const Icon(Icons.open_in_new),
                                tooltip: 'View full details',
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => CallDetailPage(call: call)),
                                ),
                              ),
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_selectionMode)
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (_) => _toggleSelectionForCall(call),
                                    ),
                                  CircleAvatar(
                                    backgroundColor: statusColor.withOpacity(0.1),
                                    child: Icon(_getStatusIcon(status), color: statusColor),
                                  ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      studentName,
                                      style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                                    ),
                                  ),
                                  if (successMetric == 'payment_received')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: NeyvoTheme.success.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Resolution achieved',
                                        style: NeyvoType.labelSmall.copyWith(
                                          color: NeyvoTheme.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (studentPhone.isNotEmpty)
                                    Text('Phone: $studentPhone', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                                  if (agentName.isNotEmpty)
                                    Text('Operator: $agentName', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                                  if (showNumberCalled)
                                    Text('Number dialed: $numberCalled', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                                  if (outcome.isNotEmpty && outcome != 'unknown')
                                    Text('Outcome: $outcome', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                                  if (date.isNotEmpty)
                                    Text('Date: $date', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: NeyvoType.labelSmall.copyWith(
                                            color: statusColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (routedIntent.isNotEmpty) ...[
                                        const SizedBox(width: NeyvoSpacing.sm),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: NeyvoTheme.bgSurface,
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(color: NeyvoTheme.border),
                                          ),
                                          child: Text(
                                            'Routed: ${routedIntent[0].toUpperCase()}${routedIntent.substring(1)}',
                                            style: NeyvoType.bodySmall.copyWith(fontSize: 11, color: NeyvoTheme.textMuted),
                                          ),
                                        ),
                                      ],
                                      if (durationStr != '?') ...[
                                        const SizedBox(width: NeyvoSpacing.sm),
                                        Text('? $durationStr', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                                      ],
                                      if (creditsStr != null) ...[
                                        const SizedBox(width: NeyvoSpacing.sm),
                                        Tooltip(
                                          message: tooltipStr ?? creditsStr,
                                          child: Text('? $creditsStr', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.teal)),
                                        ),
                                      ],
                                      if (outcomeType != null && outcomeType.isNotEmpty) ...[
                                        const SizedBox(width: NeyvoSpacing.sm),
                                        Text('? ${outcomeType.replaceAll('_', ' ')}', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                                      ],
                                    ],
                                  ),
                                  if (attributedAmount != null && attributedAmount.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Payment received: $attributedAmount${attributedAt != null && attributedAt.isNotEmpty ? " ($attributedAt)" : ""}',
                                        style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.success, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                ],
                              ),
                              children: [
                                if (recordingUrl != null && recordingUrl.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(NeyvoSpacing.sm, NeyvoSpacing.sm, NeyvoSpacing.sm, 0),
                                    child: InkWell(
                                      onTap: () async {
                                        final uri = Uri.tryParse(recordingUrl);
                                        if (uri != null && await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          Icon(Icons.audiotrack, size: 20, color: NeyvoTheme.teal),
                                          const SizedBox(width: NeyvoSpacing.sm),
                                          Text(
                                            'Listen to recording',
                                            style: NeyvoType.bodyMedium.copyWith(
                                              color: NeyvoTheme.teal,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (transcript.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(NeyvoSpacing.sm),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(NeyvoSpacing.sm),
                                      decoration: BoxDecoration(
                                        color: NeyvoTheme.bgHover,
                                        borderRadius: BorderRadius.circular(NeyvoRadius.sm),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Transcript',
                                            style: NeyvoType.labelLarge.copyWith(
                                              color: NeyvoTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: NeyvoSpacing.sm),
                                          SelectableText(
                                            transcript,
                                            style: NeyvoType.bodySmall.copyWith(
                                              color: NeyvoTheme.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.all(NeyvoSpacing.md),
                                    child: Text(
                                      'No transcript available',
                                      style: NeyvoType.bodySmall.copyWith(
                                        color: NeyvoTheme.textMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                  },
                ),
                if (_hasMore)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: NeyvoSpacing.md,
                      right: NeyvoSpacing.md,
                      bottom: NeyvoSpacing.lg,
                    ),
                    child: OutlinedButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: _loadingMore
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Load more calls'),
                    ),
                  ),
              ],
            ],
          ),
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
