// Executive Dashboard – rebuild per spec: tabs, date filter, KPIs from listCalls,
// Live Call Activity, Call Resolution, CSAT, Recent Call Logs, Quick Actions.
// Data from NeyvoPulseApi; 5s auto-refresh. Charts via fl_chart.

import 'dart:async';
import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../theme/neyvo_theme.dart';
import 'pulse_shell.dart';

enum _DateRange { today, yesterday, thisWeek, thisMonth, thisYear, custom }

class ExecutiveDashboardPage extends StatefulWidget {
  const ExecutiveDashboardPage({super.key});

  @override
  State<ExecutiveDashboardPage> createState() => _ExecutiveDashboardPageState();
}

class _ExecutiveDashboardPageState extends State<ExecutiveDashboardPage> with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0;
  _DateRange _dateRange = _DateRange.thisWeek;
  DateTime? _customFrom;
  DateTime? _customTo;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  List<Map<String, dynamic>> _calls = [];
  List<Map<String, dynamic>> _priorCalls = [];
  List<Map<String, dynamic>> _recentCalls = [];

  String? _runningCampaignId;
  List<Map<String, dynamic>> _campaignItems = [];
  Map<String, dynamic>? _campaignMetrics;

  Map<String, dynamic>? _successSummary;
  Map<String, dynamic>? _health;
  Map<String, dynamic>? _ubStatus;
  Map<String, dynamic>? _accountInfo;
  int _activeOperatorsCount = 0;

  Timer? _refreshTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String get _fromIso {
    final now = DateTime.now();
    switch (_dateRange) {
      case _DateRange.today:
        return _dayStartEnd(now).start;
      case _DateRange.yesterday:
        final y = now.subtract(const Duration(days: 1));
        return _dayStartEnd(y).start;
      case _DateRange.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return _dayStartEnd(monday).start;
      case _DateRange.thisMonth:
        return _dayStartEnd(DateTime(now.year, now.month, 1)).start;
      case _DateRange.thisYear:
        return _dayStartEnd(DateTime(now.year, 1, 1)).start;
      case _DateRange.custom:
        if (_customFrom != null) return _toIsoDate(_customFrom!);
        return _dayStartEnd(now).start;
    }
  }

  String get _toIso {
    final now = DateTime.now();
    switch (_dateRange) {
      case _DateRange.today:
        return _dayStartEnd(now).end;
      case _DateRange.yesterday:
        final y = now.subtract(const Duration(days: 1));
        return _dayStartEnd(y).end;
      case _DateRange.thisWeek:
      case _DateRange.thisMonth:
      case _DateRange.thisYear:
        return _dayStartEnd(now).end;
      case _DateRange.custom:
        if (_customTo != null) return _toIsoDateEndOfDay(_customTo!);
        return _dayStartEnd(now).end;
    }
  }

  ({String start, String end}) _dayStartEnd(DateTime d) {
    final start = DateTime(d.year, d.month, d.day, 0, 0, 0);
    final end = DateTime(d.year, d.month, d.day, 23, 59, 59);
    return (start: start.toIso8601String(), end: end.toIso8601String());
  }

  String _toIsoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T00:00:00';
  String _toIsoDateEndOfDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T23:59:59';

  ({String from, String to}) _priorRange() {
    final now = DateTime.now();
    switch (_dateRange) {
      case _DateRange.today:
        final y = now.subtract(const Duration(days: 1));
        final p = _dayStartEnd(y);
        return (from: p.start, to: p.end);
      case _DateRange.yesterday:
        final y = now.subtract(const Duration(days: 2));
        final p = _dayStartEnd(y);
        return (from: p.start, to: p.end);
      case _DateRange.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final prevMonday = monday.subtract(const Duration(days: 7));
        return (from: _dayStartEnd(prevMonday).start, to: _dayStartEnd(prevMonday.add(const Duration(days: 6))).end);
      case _DateRange.thisMonth:
        final prev = DateTime(now.year, now.month - 1, 1);
        final lastPrev = DateTime(now.year, now.month, 0);
        return (from: _dayStartEnd(prev).start, to: _dayStartEnd(lastPrev).end);
      case _DateRange.thisYear:
        return (from: _dayStartEnd(DateTime(now.year - 1, 1, 1)).start, to: _dayStartEnd(DateTime(now.year - 1, 12, 31)).end);
      case _DateRange.custom:
        return (from: _fromIso, to: _toIso);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await _fetchAll();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    if (_loading || _selectedTabIndex != 0) return;
    if (!mounted) return;
    setState(() => _refreshing = true);
    await _fetchAll();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _fetchAll() async {
    final from = _fromIso;
    final to = _toIso;
    final prior = _priorRange();
    try {
      final results = await Future.wait([
        NeyvoPulseApi.getAnalyticsComms(from: from, to: to),
        NeyvoPulseApi.listCalls(from: from, to: to, limit: 500),
        NeyvoPulseApi.listCalls(from: prior.from, to: prior.to, limit: 500),
        NeyvoPulseApi.getCallsSuccessSummary(from: from, to: to),
        NeyvoPulseApi.listCalls(limit: 5),
        _loadCampaignData(),
        NeyvoPulseApi.health(),
        NeyvoPulseApi.getUbStatus(),
        NeyvoPulseApi.getAccountInfo(),
        _loadOperatorsCount(),
      ]);
      if (!mounted) return;
      final callsRes = results[1] as Map<String, dynamic>;
      final priorRes = results[2] as Map<String, dynamic>;
      final successRes = results[3] as Map<String, dynamic>;
      final recentRes = results[4] as Map<String, dynamic>;
      // ignore: unnecessary_cast - record type from Future.wait
      final campaignData = results[5] as ({String? id, List<Map<String, dynamic>> items, Map<String, dynamic>? metrics});
      final health = results[6] as Map<String, dynamic>?;
      final ubStatus = results[7] as Map<String, dynamic>?;
      final accountInfo = results[8] as Map<String, dynamic>?;
      final operatorsCount = results[9] as int;

      final calls = (callsRes['calls'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final priorCalls = (priorRes['calls'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final recent = (recentRes['calls'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

      setState(() {
        _error = null;
        _calls = calls;
        _priorCalls = priorCalls;
        _recentCalls = recent;
        _successSummary = successRes != null && successRes['ok'] == true ? Map<String, dynamic>.from(successRes) : null;
        _health = health != null ? Map<String, dynamic>.from(health) : null;
        _ubStatus = ubStatus != null ? Map<String, dynamic>.from(ubStatus) : null;
        _accountInfo = accountInfo != null ? Map<String, dynamic>.from(accountInfo) : null;
        _runningCampaignId = campaignData.id;
        _campaignItems = campaignData.items;
        _campaignMetrics = campaignData.metrics;
        _activeOperatorsCount = operatorsCount;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<({String? id, List<Map<String, dynamic>> items, Map<String, dynamic>? metrics})> _loadCampaignData() async {
    try {
      final res = await NeyvoPulseApi.listCampaigns();
      final campaigns = (res['campaigns'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final running = campaigns.cast<Map<String, dynamic>?>().where((c) {
        final s = (c!['status'] as String?)?.toLowerCase() ?? '';
        return s == 'running' || s == 'active';
      }).toList();
      if (running.isEmpty) return (id: null, items: <Map<String, dynamic>>[], metrics: null);
      final c = running.first as Map<String, dynamic>;
      final id = c['id'] as String?;
      if (id == null) return (id: null, items: <Map<String, dynamic>>[], metrics: null);
      final itemsRes = await NeyvoPulseApi.getCampaignCallItems(id, limit: 500);
      final metricsRes = await NeyvoPulseApi.getCampaignMetrics(id);
      final items = (itemsRes['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final metrics = metricsRes['metrics'] as Map<String, dynamic>?;
      return (id: id, items: items, metrics: metrics != null ? Map<String, dynamic>.from(metrics) : null);
    } catch (_) {
      return (id: null, items: <Map<String, dynamic>>[], metrics: null);
    }
  }

  Future<int> _loadOperatorsCount() async {
    try {
      final res = await NeyvoPulseApi.listAgents();
      final list = (res['agents'] as List?) ?? [];
      int n = 0;
      for (final a in list) {
        final m = a is Map ? Map<String, dynamic>.from(a as Map) : null;
        if (m != null && ((m['status'] as String?) ?? '').toLowerCase() == 'active') n++;
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  void _applyCustomRange(DateTime from, DateTime to) {
    setState(() {
      _customFrom = from;
      _customTo = to;
      _dateRange = _DateRange.custom;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeyvoColors.bgBase,
      body: _selectedTabIndex == 0
          ? CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTabs(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyFilterBarDelegate(
                    barHeight: _kFilterBarHeight,
                    child: _buildDateFilterBar(),
                    backgroundColor: NeyvoColors.bgBase,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: _buildMainContent(),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTabs(),
                  const SizedBox(height: 12),
                  _buildComingSoon(),
                ],
              ),
            ),
    );
  }

  Widget _buildTabs() {
    const tabs = ['Executive Dashboard', 'Department Performance', 'Weekly Performance'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _selectedTabIndex == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedTabIndex = i),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? NeyvoColors.ubLightBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tabs[i],
                    style: NeyvoTextStyles.body.copyWith(
                      color: active ? Colors.white : NeyvoTheme.textSecondary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  static const double _kFilterBarHeight = 52;

  Widget _buildDateFilterBar() {
    final labels = {
      _DateRange.today: 'Today',
      _DateRange.yesterday: 'Yesterday',
      _DateRange.thisWeek: 'This Week',
      _DateRange.thisMonth: 'This Month',
      _DateRange.thisYear: 'This Year',
      _DateRange.custom: 'Custom',
    };
    return Container(
      height: _kFilterBarHeight,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised,
        border: Border(bottom: BorderSide(color: NeyvoTheme.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final e in _DateRange.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton(
                        onPressed: e == _DateRange.custom
                            ? () async {
                                final from = _customFrom ?? DateTime.now();
                                final to = _customTo ?? DateTime.now();
                                final picked = await showDialog<({DateTime from, DateTime to})>(
                                  context: context,
                                  builder: (ctx) => _CustomDateRangeDialog(initialFrom: from, initialTo: to),
                                );
                                if (picked != null && mounted) _applyCustomRange(picked.from, picked.to);
                              }
                            : () => setState(() {
                                  _dateRange = e;
                                  _load();
                                }),
                        style: TextButton.styleFrom(
                          foregroundColor: _dateRange == e ? NeyvoColors.ubLightBlue : NeyvoTheme.textSecondary,
                        ),
                        child: Text(labels[e]!),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_refreshing)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          _LiveBadge(pulse: _pulseController),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: NeyvoTheme.error))));
    }
    return _buildExecutiveContent();
  }

  Widget _buildComingSoon() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: Text('Coming soon', style: NeyvoTextStyles.heading.copyWith(color: NeyvoTheme.textMuted)),
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveContent() {
    final kpi = _computeKpis(_calls);
    final priorKpi = _computeKpis(_priorCalls);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKpiRow(kpi: kpi, priorKpi: priorKpi),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 800;
            if (narrow) {
              return Column(
                children: [
                  _buildLiveCallActivityPanel(),
                  const SizedBox(height: 16),
                  _buildCallResolutionPanel(),
                  const SizedBox(height: 16),
                  _buildCsatPanel(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildLiveCallActivityPanel()),
                const SizedBox(width: 16),
                Expanded(child: _buildCallResolutionPanel()),
                const SizedBox(width: 16),
                Expanded(child: _buildCsatPanel()),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 700;
            if (narrow) {
              return Column(
                children: [
                  _buildRecentCallLogsPanel(),
                  const SizedBox(height: 16),
                  _buildQuickActionsPanel(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildRecentCallLogsPanel()),
                const SizedBox(width: 16),
                Expanded(child: _buildQuickActionsPanel()),
              ],
            );
          },
        ),
      ],
    );
  }

  ({int total, int answered, int abandoned, int? asaSec, int? ahtSec}) _computeKpis(List<Map<String, dynamic>> calls) {
    int total = calls.length;
    final answeredList = calls.where((c) {
      final o = ((c['outcome'] ?? c['status']) as String?)?.toLowerCase() ?? '';
      return o == 'answered' || o == 'completed' || o == 'goal_achieved' || o == 'success';
    }).toList();
    int answered = answeredList.length;
    int abandoned = calls.where((c) {
      final o = ((c['outcome'] ?? c['status']) as String?)?.toLowerCase() ?? '';
      return o == 'dropped' || o == 'no_answer';
    }).length;

    int? asaSec;
    int? ahtSec;
    int asaSum = 0;
    int ahtSum = 0;
    int asaCount = 0;
    for (final c in answeredList) {
      final start = _parseDate(c['created_at'] ?? c['start_time'] ?? c['date']);
      final answer = _parseDate(c['answered_at'] ?? c['answer_time']);
      if (start != null && answer != null) {
        asaSum += answer.difference(start).inSeconds;
        asaCount++;
      }
      final dur = c['duration_seconds'] ?? c['duration_sec'];
      if (dur != null) {
        final s = dur is int ? dur : int.tryParse(dur.toString());
        if (s != null) ahtSum += s;
      }
    }
    if (asaCount > 0) asaSec = (asaSum / asaCount).round();
    if (answeredList.isNotEmpty && ahtSum > 0) ahtSec = (ahtSum / answeredList.length).round();

    return (total: total, answered: answered, abandoned: abandoned, asaSec: asaSec, ahtSec: ahtSec);
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  static String _formatDuration(dynamic call) {
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

  Widget _buildKpiRow({
    required ({int total, int answered, int abandoned, int? asaSec, int? ahtSec}) kpi,
    required ({int total, int answered, int abandoned, int? asaSec, int? ahtSec}) priorKpi,
  }) {
    final total = kpi.total;
    final answerRate = total > 0 ? (kpi.answered / total * 100) : 0.0;
    final abandonRate = total > 0 ? (kpi.abandoned / total * 100) : 0.0;

    String trendTotal = '';
    if (priorKpi.total > 0) {
      final d = kpi.total - priorKpi.total;
      trendTotal = d >= 0 ? '+$d' : '$d';
    }
    String trendAnswered = '';
    if (priorKpi.total > 0) {
      final pctNow = total > 0 ? (kpi.answered / total * 100) : 0.0;
      final pctPrev = priorKpi.answered / priorKpi.total * 100;
      final d = pctNow - pctPrev;
      trendAnswered = d >= 0 ? '+${d.toStringAsFixed(1)}%' : '${d.toStringAsFixed(1)}%';
    }
    String trendAbandon = '';
    if (priorKpi.total > 0 && total > 0) {
      final pctNow = kpi.abandoned / total * 100;
      final pctPrev = priorKpi.abandoned / priorKpi.total * 100;
      final d = pctNow - pctPrev;
      trendAbandon = d >= 0 ? '+${d.toStringAsFixed(1)}%' : '${d.toStringAsFixed(1)}%';
    }
    String trendAsa = '';
    if (kpi.asaSec != null && priorKpi.asaSec != null) {
      final d = kpi.asaSec! - priorKpi.asaSec!;
      trendAsa = d >= 0 ? '+${d}s' : '${d}s';
    }
    String trendAht = '';
    if (kpi.ahtSec != null && priorKpi.ahtSec != null) {
      final d = kpi.ahtSec! - priorKpi.ahtSec!;
      trendAht = d >= 0 ? '+${d}s' : '${d}s';
    }

    final cards = [
      _KpiCard(
        title: 'TOTAL CALLS',
        value: total > 0 ? NumberFormat('#,###').format(total) : '--',
        trend: trendTotal,
        topBorderColor: Colors.blue,
        icon: Icons.phone_outlined,
        iconColor: Colors.blue,
      ),
      _KpiCard(
        title: 'CALLS ANSWERED',
        value: total > 0 ? NumberFormat('#,###').format(kpi.answered) : '--',
        subtitle: total > 0 ? '${answerRate.toStringAsFixed(1)}%' : null,
        trend: trendAnswered,
        topBorderColor: Colors.green,
        icon: Icons.check_circle_outline,
        iconColor: Colors.green,
      ),
      _KpiCard(
        title: 'ABANDON CALLS',
        value: total > 0 ? NumberFormat('#,###').format(kpi.abandoned) : '--',
        subtitle: total > 0 ? '${abandonRate.toStringAsFixed(1)}%' : null,
        trend: trendAbandon,
        topBorderColor: Colors.red,
        icon: Icons.phone_disabled_outlined,
        iconColor: Colors.red,
      ),
      _KpiCard(
        title: 'ASA (Sec)',
        value: kpi.asaSec != null ? '${kpi.asaSec}' : '--',
        trend: trendAsa,
        topBorderColor: Colors.orange,
        icon: Icons.timer_outlined,
        iconColor: Colors.orange,
        tooltip: 'Average Speed of Answer',
      ),
      _KpiCard(
        title: 'AHT (Sec)',
        value: kpi.ahtSec != null ? '${kpi.ahtSec}' : '--',
        trend: trendAht,
        topBorderColor: Colors.purple,
        icon: Icons.headset_outlined,
        iconColor: Colors.purple,
        tooltip: 'Average Handle Time',
      ),
    ];
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 12),
          Expanded(child: cards[1]),
          const SizedBox(width: 12),
          Expanded(child: cards[2]),
          const SizedBox(width: 12),
          Expanded(child: cards[3]),
          const SizedBox(width: 12),
          Expanded(child: cards[4]),
        ],
      ),
    );
  }

  Widget _buildLiveCallActivityPanel() {
    final total = _campaignMetrics?['total_planned'] != null
        ? (_campaignMetrics!['total_planned'] is int ? _campaignMetrics!['total_planned'] as int : int.tryParse(_campaignMetrics!['total_planned'].toString()) ?? _campaignItems.length)
        : _campaignItems.isEmpty ? 0 : _campaignItems.length;
    final queue = _campaignItems.where((e) => ((e['status'] as String?) ?? '').toLowerCase() == 'queued').length;
    final ongoing = _campaignItems.where((e) {
      final s = ((e['status'] as String?) ?? '').toLowerCase();
      return s == 'in_progress' || s == 'dialing';
    }).length;
    final unanswered = _campaignItems.where((e) {
      final o = ((e['outcome'] as String?) ?? '').toLowerCase();
      return o == 'no_answer' || o == 'voicemail';
    }).length;
    final scheduled = _campaignItems.where((e) {
      final s = ((e['status'] as String?) ?? '').toLowerCase();
      return s == 'scheduled' || s.contains('callback');
    }).length;
    final failed = _campaignItems.where((e) {
      final s = ((e['status'] as String?) ?? '').toLowerCase();
      final o = ((e['outcome'] as String?) ?? '').toLowerCase();
      return s == 'failed' || o == 'failed';
    }).length;

    final totalForBars = total > 0 ? total : 1;
    final completion = total > 0 ? ((total - queue - ongoing) / total * 100) : 0.0;
    String estimatedRemaining = '—';
    if (_campaignMetrics != null && total > 0 && (queue + ongoing) > 0) {
      final throughput = (_campaignMetrics!['throughput_per_minute'] as num?)?.toDouble();
      if (throughput != null && throughput > 0) {
        final remaining = (queue + ongoing).toDouble() / throughput;
        estimatedRemaining = '~${remaining.round()} min';
      }
    }

    final hasRunningCampaign = _runningCampaignId != null || _campaignItems.isNotEmpty;
    final semanticColors = [
      Colors.indigo,
      Colors.amber,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.grey.shade700,
    ];
    const rainbowColors = [
      Color(0xFFE53935),
      Color(0xFFFB8C00),
      Color(0xFFFDD835),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFF8E24AA),
    ];
    final rowColors = hasRunningCampaign ? semanticColors : rainbowColors;

    final rows = [
      ('Total Contacts', total, rowColors[0]),
      ('In Queue', queue, rowColors[1]),
      ('On-going / Talking', ongoing, rowColors[2]),
      ('Unanswered / VM', unanswered, rowColors[3]),
      ('Scheduled / Callback', scheduled, rowColors[4]),
      ('Failed', failed, rowColors[5]),
    ];

    final completionStr = total > 0 ? '${completion.toStringAsFixed(0)}%' : '0%';
    final estRemainingParts = estimatedRemaining.startsWith('~')
        ? (estimatedRemaining.split(' ')..removeWhere((s) => s.isEmpty))
        : <String>[];
    final estRemainingValue = estRemainingParts.isNotEmpty ? estRemainingParts[0] : estimatedRemaining;
    final estRemainingUnit = estRemainingParts.length > 1 ? estRemainingParts[1] : '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Call Activity', style: NeyvoTextStyles.heading),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text('Current campaign progress', style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
                ),
                if (_refreshing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: Colors.green.shade700, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text('Updating', style: NeyvoTextStyles.micro.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: NeyvoTheme.borderSubtle),
            const SizedBox(height: 12),
            if (!hasRunningCampaign)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('No campaign is currently running.', style: NeyvoTextStyles.label.copyWith(color: NeyvoTheme.textMuted)),
              ),
            ...rows.map((r) => _LiveBarRow(label: r.$1, count: r.$2, pct: totalForBars > 0 ? (r.$2 / totalForBars) : 0, color: r.$3)),
            const SizedBox(height: 12),
            Divider(height: 1, color: NeyvoTheme.borderSubtle),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Completion:', style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
                    const SizedBox(height: 2),
                    Text(completionStr, style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.ubPurple, fontWeight: FontWeight.w700)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Est. remaining:', style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
                    const SizedBox(height: 2),
                    Text(estRemainingValue, style: NeyvoTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                    if (estRemainingUnit.isNotEmpty)
                      Text(estRemainingUnit, style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallResolutionPanel() {
    final total = _calls.length;
    final succeeded = _calls.where((c) {
      final o = ((c['outcome'] ?? c['status']) as String?)?.toLowerCase() ?? '';
      return o == 'answered' || o == 'completed' || o == 'goal_achieved' || o == 'success';
    }).length;
    int resolved;
    final summary = _successSummary?['success_summary'] as Map<String, dynamic>?;
    if (summary != null && summary['calls_with_payment_received'] != null) {
      final v = summary['calls_with_payment_received'];
      resolved = (v is int ? v : int.tryParse(v.toString()) ?? 0).clamp(0, total);
    } else {
      resolved = _calls.where((c) {
        final o = ((c['outcome'] ?? c['status']) as String?)?.toLowerCase() ?? '';
        return o == 'goal_achieved' || (c['success_metric'] ?? '').toString().toLowerCase() == 'payment_received';
      }).length;
    }
    final unresolved = total - resolved;
    final resolutionPct = total > 0 ? (resolved / total * 100) : 0.0;
    final succeededNotResolved = succeeded - resolved;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Call Resolution', style: NeyvoTextStyles.heading),
            const SizedBox(height: 4),
            Text('Success rate by outcome', style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
            const SizedBox(height: 12),
            _ResolutionBar(label: 'Calls Received', value: total, total: total, color: Colors.amber),
            _ResolutionBar(label: 'Calls Succeeded', value: succeeded, total: total, color: Colors.purple),
            _ResolutionBar(label: 'Resolution Count', value: resolved, total: total, color: Colors.blue),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRect(
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 30.6,
                            sections: total > 0
                                ? [
                                    PieChartSectionData(value: resolutionPct, color: Colors.blue, showTitle: false),
                                    PieChartSectionData(value: (succeededNotResolved / total * 100), color: Colors.purple, showTitle: false),
                                    PieChartSectionData(value: ((total - succeeded) / total * 100).clamp(0.0, 100.0), color: Colors.grey.shade300, showTitle: false),
                                  ]
                                : [
                                    PieChartSectionData(value: 25, color: Colors.amber, showTitle: false),
                                    PieChartSectionData(value: 25, color: Colors.purple, showTitle: false),
                                    PieChartSectionData(value: 25, color: Colors.blue, showTitle: false),
                                    PieChartSectionData(value: 25, color: Colors.grey, showTitle: false),
                                  ],
                          ),
                        ),
                        Text('${resolutionPct.toStringAsFixed(1)}%', style: NeyvoTextStyles.title.copyWith(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LegendRow('Received', total, Colors.amber),
                        _LegendRow('Succeeded', succeeded, Colors.purple),
                        _LegendRow('Resolved', resolved, Colors.blue),
                        _LegendRow('Unresolved', unresolved, Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCsatPanel() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Customer Satisfaction Score', style: NeyvoTextStyles.heading),
            const SizedBox(height: 4),
            Text('CSAT · Based on post-call surveys', style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
            const SizedBox(height: 12),
            SizedBox(
              width: 160,
              height: 90,
              child: CustomPaint(
                painter: _HalfDoughnutPainter(
                  value: null,
                  noDataColors: [
                    Colors.green,
                    Colors.green.shade700,
                    Colors.yellow.shade700,
                    Colors.red,
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('—', style: NeyvoTextStyles.title.copyWith(fontSize: 20)),
                      Text('awaiting data', style: NeyvoTextStyles.micro),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _CsatLegendItem('Satisfied (5★)', Colors.green),
                _CsatLegendItem('Good (4★)', Colors.green.shade700),
                _CsatLegendItem('Neutral (3★)', Colors.yellow.shade700),
                _CsatLegendItem('Poor (1-2★)', Colors.red),
              ],
            ),
            const SizedBox(height: 8),
            Text('Connect post-call survey to populate CSAT', style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCallLogsPanel() {
    final sorted = List<Map<String, dynamic>>.from(_recentCalls)
      ..sort((a, b) {
        final da = _parseDate(a['created_at'] ?? a['date']);
        final db = _parseDate(b['created_at'] ?? b['date']);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    final list = sorted.take(5).toList();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Call Logs', style: NeyvoTextStyles.heading),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Text('No recent calls', style: NeyvoTextStyles.label.copyWith(color: NeyvoTheme.textMuted))
            else
              Table(
                columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(0.8), 3: FlexColumnWidth(0.8), 4: FlexColumnWidth(0.6), 5: FlexColumnWidth(0.8)},
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: NeyvoColors.bgOverlay),
                    children: [
                      _tableHeader('Student'),
                      _tableHeader('Campaign'),
                      _tableHeader('Direction'),
                      _tableHeader('Outcome'),
                      _tableHeader('Duration'),
                      _tableHeader('Time'),
                    ],
                  ),
                  ...list.map((c) {
                    final name = (c['student_name'] ?? c['customer_name'] ?? '—').toString();
                    final phone = (c['student_phone'] ?? c['customer_phone'] ?? '').toString();
                    final campaign = (c['campaign_name'] ?? '—').toString();
                    final direction = ((c['direction'] ?? 'outbound') as String).toLowerCase();
                    final outcome = ((c['outcome'] ?? c['status']) as String?)?.toLowerCase() ?? '—';
                    final duration = _formatDuration(c);
                    final created = _parseDate(c['created_at'] ?? c['date']);
                    final timeStr = created != null ? DateFormat('MMM d, HH:mm').format(created) : '—';
                    return TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text('$name\n$phone', style: NeyvoTextStyles.micro, maxLines: 2, overflow: TextOverflow.ellipsis)),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text(campaign, style: NeyvoTextStyles.micro, overflow: TextOverflow.ellipsis)),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: _OutcomePill(label: direction, outcome: direction)),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: _OutcomePill(label: outcome, outcome: outcome)),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text(duration, style: NeyvoTextStyles.micro)),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text(timeStr, style: NeyvoTextStyles.micro)),
                      ],
                    );
                  }),
                ],
              ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.calls),
              child: Text('View all →', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.ubLightBlue)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text(t, style: NeyvoTextStyles.label));

  Widget _buildQuickActionsPanel() {
    final voiceOk = _health != null && (_health!['ok'] == true || _health!['status'] == 'ok');
    final ubStatus = (_ubStatus?['status'] as String?)?.toLowerCase() ?? 'missing';
    final credits = _accountInfo?['wallet_credits'];
    final creditsStr = credits != null ? NumberFormat('#,###').format(credits is int ? credits : int.tryParse(credits.toString()) ?? 0) : '—';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions', style: NeyvoTextStyles.heading),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.8,
              children: [
                _QuickActionButton(icon: Icons.person_add_outlined, label: 'Add Operator', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.agents)),
                _QuickActionButton(icon: Icons.campaign_outlined, label: 'Campaigns', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.campaigns)),
                _QuickActionButton(icon: Icons.psychology_outlined, label: 'UB Model', onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.ubModelOverview)),
                _QuickActionButton(icon: Icons.analytics_outlined, label: 'Analytics', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.analytics)),
                _QuickActionButton(icon: Icons.call_outlined, label: 'Start Outbound', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.calls)),
                _QuickActionButton(icon: Icons.add_card_outlined, label: 'Add Credits', onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.wallet)),
              ],
            ),
            const SizedBox(height: 16),
            Text('System status', style: NeyvoTextStyles.label),
            const SizedBox(height: 8),
            _StatusRow('Voice OS', voiceOk ? 'Healthy' : 'Error', voiceOk ? Colors.green : Colors.red),
            _StatusRow('UB Model', ubStatus == 'ready' ? 'Ready' : ubStatus == 'building' ? 'Building' : 'Error', ubStatus == 'ready' ? Colors.green : ubStatus == 'building' ? Colors.orange : Colors.red),
            _StatusRow('Coverage', '$_activeOperatorsCount / 6 depts', NeyvoTheme.textSecondary),
            _StatusRow('Credits', creditsStr, NeyvoColors.ubPurple),
          ],
        ),
      ),
    );
  }
}

class _StickyFilterBarDelegate extends SliverPersistentHeaderDelegate {
  final double barHeight;
  final Widget child;
  final Color backgroundColor;

  _StickyFilterBarDelegate({
    required this.barHeight,
    required this.child,
    required this.backgroundColor,
  });

  @override
  double get minExtent => barHeight;

  @override
  double get maxExtent => barHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyFilterBarDelegate oldDelegate) =>
      oldDelegate.barHeight != barHeight;
}

class _CustomDateRangeDialog extends StatefulWidget {
  final DateTime initialFrom;
  final DateTime initialTo;

  const _CustomDateRangeDialog({required this.initialFrom, required this.initialTo});

  @override
  State<_CustomDateRangeDialog> createState() => _CustomDateRangeDialogState();
}

class _CustomDateRangeDialogState extends State<_CustomDateRangeDialog> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom date range'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('From'),
            subtitle: Text(DateFormat.yMMMd().format(_from)),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _from, firstDate: DateTime(2020), lastDate: DateTime.now());
              if (d != null) setState(() => _from = d);
            },
          ),
          ListTile(
            title: const Text('To'),
            subtitle: Text(DateFormat.yMMMd().format(_to)),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _to, firstDate: DateTime(2020), lastDate: DateTime.now());
              if (d != null) setState(() => _to = d);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (from: _from, to: _to)),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final Animation<double> pulse;

  const _LiveBadge({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3 + pulse.value * 0.4), blurRadius: 4, spreadRadius: 1)],
              ),
            ),
            const SizedBox(width: 6),
            Text('Live · Refreshes every 5s', style: NeyvoTextStyles.micro),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String trend;
  final Color topBorderColor;
  final IconData icon;
  final Color iconColor;
  final String? tooltip;

  const _KpiCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.trend,
    required this.topBorderColor,
    required this.icon,
    required this.iconColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? title,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: NeyvoTheme.borderSubtle),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(top: BorderSide(color: topBorderColor, width: 3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: NeyvoTextStyles.label.copyWith(fontSize: 10, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: iconColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: NeyvoTextStyles.title.copyWith(fontSize: 22),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (trend.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          trend,
                          style: NeyvoTextStyles.micro.copyWith(color: trend.startsWith('+') ? Colors.green : Colors.red),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted), overflow: TextOverflow.ellipsis, maxLines: 1),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveBarRow extends StatelessWidget {
  final String label;
  final int count;
  final double pct;
  final Color color;

  const _LiveBarRow({required this.label, required this.count, required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    final fill = pct.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: NeyvoTextStyles.micro.copyWith(color: color))),
          Expanded(
            child: SizedBox(
              height: 20,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        if (fill > 0)
                          Container(
                            width: (w * fill).clamp(0.0, w),
                            height: 20,
                            color: color,
                          ),
                        Expanded(
                          child: Container(
                            height: 20,
                            color: Colors.grey.shade200,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 40, child: Text('$count', style: NeyvoTextStyles.micro, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _ResolutionBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _ResolutionBar({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: NeyvoTextStyles.micro),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 20,
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${NumberFormat('#,###').format(value)}${total > 0 ? ', ${(pct * 100).toStringAsFixed(1)}%' : ''}', style: NeyvoTextStyles.micro),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _LegendRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: NeyvoTextStyles.micro,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HalfDoughnutPainter extends CustomPainter {
  final double? value;
  final List<Color>? noDataColors;

  _HalfDoughnutPainter({this.value, this.noDataColors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const strokeWidth = 12.0;

    if (value == null && noDataColors != null && noDataColors!.length >= 4) {
      final segmentSweep = pi / noDataColors!.length;
      for (var i = 0; i < noDataColors!.length; i++) {
        final paint = Paint()
          ..color = noDataColors![i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(rect, pi + i * segmentSweep, segmentSweep, false, paint);
      }
    } else {
      final paint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, pi, pi, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CsatLegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _CsatLegendItem(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: NeyvoTextStyles.micro),
      ],
    );
  }
}

class _OutcomePill extends StatelessWidget {
  final String label;
  final String outcome;

  const _OutcomePill({required this.label, required this.outcome});

  Color get _color {
    final o = outcome.toLowerCase();
    if (o == 'goal_achieved' || o == 'completed' || o == 'success') return Colors.green;
    if (o == 'dropped' || o == 'no_answer') return Colors.red;
    if (o == 'voicemail') return Colors.amber;
    if (o == 'in_progress' || o == 'dialing') return Colors.blue;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.5)),
      ),
      child: Text(label, style: NeyvoTextStyles.micro.copyWith(color: _color)),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: NeyvoTextStyles.micro, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatusRow(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: NeyvoTextStyles.micro),
          Text(value, style: NeyvoTextStyles.micro.copyWith(color: valueColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
