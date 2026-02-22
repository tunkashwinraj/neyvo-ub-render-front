// lib/screens/call_history_page.dart
// Call logs – history with filters, date range, transcripts, export, recording link

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../utils/export_csv.dart';
import '../theme/spearia_theme.dart';
import 'call_detail_page.dart';

/// Sort options: date desc/asc, duration desc/asc (when backend provides duration)
enum _CallSort { dateNewest, dateOldest, durationLongest, durationShortest }

class CallHistoryPage extends StatefulWidget {
  const CallHistoryPage({super.key});

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
  String _dateRange = 'all'; // all, 7d, 30d
  _CallSort _sortBy = _CallSort.dateNewest;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterCalls);
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
      final res = await NeyvoPulseApi.listCalls();
      final list = res['calls'] as List? ?? [];
      if (mounted) {
        setState(() {
          _allCalls = list;
          _filteredCalls = list;
          _loading = false;
        });
        _filterCalls();
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
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
    final sec = call['duration_seconds'];
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

  void _filterCalls() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      var list = _allCalls.where((c) {
        if (!_isInDateRange(c)) return false;
        final studentName = (c['student_name']?.toString() ?? '').toLowerCase();
        final phone = (c['student_phone']?.toString() ?? '').toLowerCase();
        final matchesSearch = query.isEmpty ||
            studentName.contains(query) ||
            phone.contains(query);
        if (!matchesSearch) return false;
        if (_filterStatus == 'all') return true;
        final status = (c['status']?.toString() ?? '').toLowerCase();
        return status == _filterStatus;
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

  Future<void> _exportCsv() async {
    final sb = StringBuffer();
    sb.writeln('Contact Name,Phone,Date,Status,Duration,Recording URL,Transcript');
    for (final c in _filteredCalls) {
      final map = c as Map<String, dynamic>;
      final name = (map['student_name']?.toString() ?? '').replaceAll(',', ';');
      final phone = map['student_phone']?.toString() ?? '';
      final date = map['created_at']?.toString() ?? map['date']?.toString() ?? '';
      final status = map['status']?.toString() ?? '';
      final duration = formatDuration(map);
      final recording = map['recording_url']?.toString() ?? '';
      final transcript = (map['transcript']?.toString() ?? '').replaceAll(RegExp(r'[\r\n]'), ' ');
      sb.writeln('"$name","$phone","$date","$status","$duration","$recording","$transcript"');
    }
    final filename = 'reach_history_${DateTime.now().toIso8601String().split('T').first}.csv';
    await downloadCsv(filename, sb.toString(), context);
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'success':
        return SpeariaAura.success;
      case 'failed':
      case 'error':
        return SpeariaAura.error;
      case 'pending':
      case 'ringing':
        return SpeariaAura.warning;
      default:
        return SpeariaAura.textMuted;
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
        appBar: AppBar(title: const Text('Reach history')),
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
        title: const Text('Reach history'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _filteredCalls.isEmpty ? null : _exportCsv,
            tooltip: 'Export CSV',
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            onPressed: () => Navigator.of(context).pushNamed(PulseRouteNames.aiInsights),
            tooltip: 'AI Insights',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search, date range, and filter bar
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
                    hintText: 'Search reaches...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterCalls();
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: SpeariaSpacing.sm),
                Text('Date range', style: SpeariaType.labelSmall.copyWith(color: SpeariaAura.textSecondary)),
                const SizedBox(height: SpeariaSpacing.xs),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: 'All time', selected: _dateRange == 'all', onTap: () { setState(() { _dateRange = 'all'; _filterCalls(); }); }),
                      const SizedBox(width: SpeariaSpacing.sm),
                      _FilterChip(label: 'Last 7 days', selected: _dateRange == '7d', onTap: () { setState(() { _dateRange = '7d'; _filterCalls(); }); }),
                      const SizedBox(width: SpeariaSpacing.sm),
                      _FilterChip(label: 'Last 30 days', selected: _dateRange == '30d', onTap: () { setState(() { _dateRange = '30d'; _filterCalls(); }); }),
                    ],
                  ),
                ),
                const SizedBox(height: SpeariaSpacing.sm),
                Text('Status', style: SpeariaType.labelSmall.copyWith(color: SpeariaAura.textSecondary)),
                const SizedBox(height: SpeariaSpacing.xs),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: 'All', selected: _filterStatus == 'all', onTap: () { setState(() => _filterStatus = 'all'); _filterCalls(); }),
                      const SizedBox(width: SpeariaSpacing.sm),
                      _FilterChip(label: 'Completed', selected: _filterStatus == 'completed', onTap: () { setState(() => _filterStatus = 'completed'); _filterCalls(); }),
                      const SizedBox(width: SpeariaSpacing.sm),
                      _FilterChip(label: 'Failed', selected: _filterStatus == 'failed', onTap: () { setState(() => _filterStatus = 'failed'); _filterCalls(); }),
                      const SizedBox(width: SpeariaSpacing.sm),
                      _FilterChip(label: 'Pending', selected: _filterStatus == 'pending', onTap: () { setState(() => _filterStatus = 'pending'); _filterCalls(); }),
                    ],
                  ),
                ),
                const SizedBox(height: SpeariaSpacing.sm),
                Text('Sort by', style: SpeariaType.labelSmall.copyWith(color: SpeariaAura.textSecondary)),
                const SizedBox(height: SpeariaSpacing.xs),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: 'Date (newest)', selected: _sortBy == _CallSort.dateNewest, onTap: () { setState(() { _sortBy = _CallSort.dateNewest; _filterCalls(); }); }),
                      const SizedBox(width: SpeariaSpacing.sm),
                      _FilterChip(label: 'Date (oldest)', selected: _sortBy == _CallSort.dateOldest, onTap: () { setState(() { _sortBy = _CallSort.dateOldest; _filterCalls(); }); }),
                      const SizedBox(width: SpeariaSpacing.sm),
                      _FilterChip(label: 'Duration (longest)', selected: _sortBy == _CallSort.durationLongest, onTap: () { setState(() { _sortBy = _CallSort.durationLongest; _filterCalls(); }); }),
                      const SizedBox(width: SpeariaSpacing.sm),
                      _FilterChip(label: 'Duration (shortest)', selected: _sortBy == _CallSort.durationShortest, onTap: () { setState(() { _sortBy = _CallSort.durationShortest; _filterCalls(); }); }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Calls List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _filteredCalls.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone_outlined, size: 64, color: SpeariaAura.textMuted),
                          const SizedBox(height: SpeariaSpacing.md),
                          Text(
                            _allCalls.isEmpty ? 'No reaches yet' : 'No reaches found',
                            style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(SpeariaSpacing.md),
                      itemCount: _filteredCalls.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.all(SpeariaSpacing.md),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Reaches (${_filteredCalls.length})',
                                  style: SpeariaType.headlineMedium,
                                ),
                                if (_filteredCalls.length != _allCalls.length)
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _filterStatus = 'all');
                                      _filterCalls();
                                    },
                                    child: const Text('Clear filters'),
                                  ),
                              ],
                            ),
                          );
                        }
                        final call = _filteredCalls[i - 1] as Map<String, dynamic>;
                        final status = call['status']?.toString() ?? 'unknown';
                        final studentName = call['student_name']?.toString() ?? 'Unknown';
                        final studentPhone = call['student_phone']?.toString() ?? '';
                        final date = call['created_at']?.toString() ?? call['date']?.toString() ?? '';
                        final durationStr = formatDuration(call);
                        final transcript = call['transcript']?.toString() ?? '';
                        final recordingUrl = call['recording_url']?.toString();
                        final statusColor = _getStatusColor(status);
                        final successMetric = call['success_metric']?.toString();
                        final attributedAmount = call['attributed_payment_amount']?.toString();
                        final attributedAt = call['attributed_payment_at']?.toString();
                        final outcomeType = call['outcome_type']?.toString();
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: SpeariaSpacing.sm),
                          child: ExpansionTile(
                            trailing: IconButton(
                              icon: const Icon(Icons.open_in_new),
                              tooltip: 'View full details',
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => CallDetailPage(call: call)),
                              ),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.1),
                              child: Icon(_getStatusIcon(status), color: statusColor),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(studentName, style: SpeariaType.titleMedium)),
                                if (successMetric == 'payment_received')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: SpeariaAura.success.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Resolution achieved', style: SpeariaType.labelSmall.copyWith(color: SpeariaAura.success, fontWeight: FontWeight.w600)),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (studentPhone.isNotEmpty) Text(studentPhone),
                                if (date.isNotEmpty) Text('Date: $date', style: SpeariaType.bodySmall),
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
                                        style: SpeariaType.labelSmall.copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (durationStr != '—') ...[
                                      const SizedBox(width: SpeariaSpacing.sm),
                                      Text('• $durationStr', style: SpeariaType.bodySmall),
                                    ],
                                    if (outcomeType != null && outcomeType.isNotEmpty) ...[
                                      const SizedBox(width: SpeariaSpacing.sm),
                                      Text('• ${outcomeType.replaceAll('_', ' ')}', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary)),
                                    ],
                                  ],
                                ),
                                if (attributedAmount != null && attributedAmount.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('Payment received: $attributedAmount${attributedAt != null && attributedAt.isNotEmpty ? " ($attributedAt)" : ""}', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.success, fontWeight: FontWeight.w500)),
                                  ),
                              ],
                            ),
                            children: [
                              if (recordingUrl != null && recordingUrl.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(SpeariaSpacing.md, SpeariaSpacing.sm, SpeariaSpacing.md, 0),
                                  child: InkWell(
                                    onTap: () async {
                                      final uri = Uri.tryParse(recordingUrl);
                                      if (uri != null && await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        Icon(Icons.audiotrack, size: 20, color: SpeariaAura.primary),
                                        const SizedBox(width: SpeariaSpacing.sm),
                                        Text('Listen to recording', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.primary, decoration: TextDecoration.underline)),
                                      ],
                                    ),
                                  ),
                                ),
                              if (transcript.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(SpeariaSpacing.md),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(SpeariaSpacing.md),
                                    decoration: BoxDecoration(
                                      color: SpeariaAura.bgDark,
                                      borderRadius: BorderRadius.circular(SpeariaRadius.sm),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Transcript',
                                          style: SpeariaType.labelMedium.copyWith(
                                            color: SpeariaAura.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: SpeariaSpacing.sm),
                                        Text(
                                          transcript,
                                          style: SpeariaType.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.all(SpeariaSpacing.md),
                                  child: Text(
                                    'No transcript available',
                                    style: SpeariaType.bodySmall.copyWith(
                                      color: SpeariaAura.textMuted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
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
