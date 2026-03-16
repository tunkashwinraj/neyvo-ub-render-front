// lib/screens/call_history_page.dart
// Call logs ? history with filters, date range, transcripts, export, recording link

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../neyvo_pulse_api.dart';
import '../services/user_timezone_service.dart';
import '../tenant/tenant_brand.dart';
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
  String _filterDirection = 'all'; // all, inbound, outbound (default to all)
  String _dateRange = 'all'; // all, 7d, 30d
  _CallSort _sortBy = _CallSort.dateNewest;
  /// User-selectable number of call logs to fetch per page (20, 50, 100, 200, 500).
  int _fetchSize = 50;
  bool _hasMore = true;
  bool _loadingMore = false;
  static const List<int> _fetchSizeOptions = [20, 50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    _filterDirection = (widget.initialDirection).toLowerCase().trim();
    if (_filterDirection != 'inbound' && _filterDirection != 'outbound' && _filterDirection != 'all') {
      _filterDirection = 'all';
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
    final created = call['started_at'] ?? call['created_at'] ?? call['date'] ?? call['timestamp'];
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

  /// Date used for display/fallback.
  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  /// Date used for sorting and filtering; prefer same source as display.
  static DateTime? _callDate(dynamic c) {
    final raw = c['started_at'] ?? c['created_at'] ?? c['date'] ?? c['timestamp'];
    return _parseDate(raw);
  }

  /// Latest activity time (max of started/created/ended/updated) so "Date (newest)" shows recently ended calls first.
  static DateTime _callDateForSort(dynamic c) {
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
            final da = _callDateForSort(a);
            final db = _callDateForSort(b);
            return db.compareTo(da);
          case _CallSort.dateOldest:
            final da = _callDateForSort(a);
            final db = _callDateForSort(b);
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

  /// Show delete confirmation for a single call log (Goodwin: hold to delete).
  static Future<void> _showDeleteCallLogDialog(
    BuildContext context,
    String callId,
    String studentName,
    String date,
    VoidCallback onDeleted,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete call log?'),
        content: Text(
          'This will permanently remove this call log from history.\n\n'
          '${studentName.isNotEmpty ? studentName : "Call"}${date.isNotEmpty ? " · $date" : ""}',
          style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await NeyvoPulseApi.deleteCalls([callId]);
      if (!context.mounted) return;
      if (res['ok'] == true) {
        onDeleted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call log deleted'), backgroundColor: NeyvoTheme.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? res['error']?.toString() ?? 'Failed to delete call log'),
            backgroundColor: NeyvoTheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: NeyvoTheme.error),
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
                  itemCount: _filteredCalls.length + 1,
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
                        final idx = i - 1;
                        final call = _filteredCalls[idx] as Map<String, dynamic>;
                        final status = call['status']?.toString() ?? 'unknown';
                        final studentName = (call['student_name'] ?? call['contact_name'] ?? call['caller'] ?? 'Unknown').toString();
                        final studentPhone = (call['student_phone'] ?? call['to'] ?? call['phone_number'] ?? '').toString();
                        final agentName = (call['profile_name'] ?? call['agent_name'] ?? call['managed_profile_name'] ?? '').toString();
                        final numberCalled = (call['number_called'] ?? call['from'] ?? call['phone_number_id'] ?? '').toString();
                        final outcome = (call['outcome'] ?? call['outcome_type'] ?? call['status'] ?? '').toString();
                        final dateDisplay = (call['created_at_display'] ?? '').toString().trim();
                        final dateRaw = call['started_at'] ?? call['created_at'] ?? call['timestamp'] ?? call['date'];
                        final date = dateDisplay.isNotEmpty
                            ? dateDisplay
                            : (dateRaw != null ? UserTimezoneService.formatShort(dateRaw) : '');
                        final durationStr = formatDuration(call);
                        final transcript = call['transcript']?.toString() ?? '';
                        // Prefer mono recording_url, but fall back to stereo if only that exists.
                        final recordingUrl = (
                          call['recording_url'] ??
                          call['recordingUrl'] ??
                          call['stereo_recording_url'] ??
                          call['stereoRecordingUrl'] ??
                          ''
                        ).toString().trim();
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
                        final callId = (call['id'] ?? call['call_id'] ?? '').toString().trim();
                        final canDelete = TenantBrand.isGoodwin(context) && callId.isNotEmpty;

                        void _openCallDetail() {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => CallDetailPage(call: call)),
                          );
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: NeyvoSpacing.sm),
                          child: InkWell(
                            onTap: _openCallDetail,
                            onLongPress: canDelete
                                ? () => _showDeleteCallLogDialog(context, callId, studentName, date, () => _load())
                                : null,
                            child: ExpansionTile(
                              onExpansionChanged: (expanded) {
                                if (expanded) {
                                  _openCallDetail();
                                }
                              },
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.audiotrack,
                                      color: recordingUrl.isNotEmpty
                                          ? TenantBrand.primary(context)
                                          : NeyvoTheme.textMuted,
                                    ),
                                    onPressed: recordingUrl.isNotEmpty
                                        ? () async {
                                            final uri = Uri.tryParse(recordingUrl);
                                            if (uri != null && await canLaunchUrl(uri)) {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            }
                                          }
                                        : null,
                                    tooltip: recordingUrl.isNotEmpty ? 'Listen to recording' : 'No recording available',
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              leading: CircleAvatar(
                                backgroundColor: statusColor.withOpacity(0.1),
                                child: Icon(_getStatusIcon(status), color: statusColor),
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
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Transcript',
                                                style: NeyvoType.labelLarge.copyWith(
                                                  color: NeyvoTheme.textSecondary,
                                                ),
                                              ),
                                              TextButton.icon(
                                                onPressed: () async {
                                                  final safeName = studentName.isNotEmpty ? studentName.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '_') : 'call';
                                                  final fileDate = date.isNotEmpty ? date.replaceAll(RegExp(r'[^0-9\-T:]'), '_') : DateTime.now().toIso8601String();
                                                  final filename = 'transcript_${safeName}_$fileDate.txt';
                                                  await downloadCsv(filename, transcript, context);
                                                },
                                                icon: const Icon(Icons.download, size: 18),
                                                label: const Text('Download'),
                                              ),
                                            ],
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
