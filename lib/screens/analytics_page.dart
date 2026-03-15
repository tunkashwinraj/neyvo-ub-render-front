// File: analytics_page.dart
// Insights: full analytics (Overview, Calls, Campaigns, Students, Operators, Lines, Wallet, Pulse, Callbacks, Studio).

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../neyvo_pulse_api.dart';
import '../services/user_timezone_service.dart';
import '../theme/neyvo_theme.dart';
import '../tenant/tenant_brand.dart';
import '../widgets/neyvo_empty_state.dart';
import '../ui/components/glass/neyvo_glass_panel.dart';
import '../utils/export_csv.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _comms;
  Map<String, dynamic>? _studio;
  Map<String, dynamic>? _insights;
  Map<String, dynamic>? _callbacksAnalytics;
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _transactionsRes;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _agents = [];
  List<Map<String, dynamic>> _numbers = [];
  List<Map<String, dynamic>> _callsForKpi = [];
  List<Map<String, dynamic>> _priorCallsForKpi = [];
  String _dateRange = '30d';

  ({String from, String to}) _dateRangeToIso() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfToday = startOfToday.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
    String toIso(DateTime d) => d.toIso8601String();
    switch (_dateRange) {
      case 'today':
        return (from: toIso(startOfToday), to: toIso(endOfToday));
      case '7d':
        final from = startOfToday.subtract(const Duration(days: 6));
        return (from: toIso(from), to: toIso(endOfToday));
      case '90d':
        final from = startOfToday.subtract(const Duration(days: 89));
        return (from: toIso(from), to: toIso(endOfToday));
      case '30d':
      default:
        final from = startOfToday.subtract(const Duration(days: 29));
        return (from: toIso(from), to: toIso(endOfToday));
    }
  }

  ({String from, String to}) _priorRangeIso() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfToday = startOfToday.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
    String toIso(DateTime d) => d.toIso8601String();
    switch (_dateRange) {
      case 'today':
        final y = startOfToday.subtract(const Duration(days: 1));
        return (from: toIso(y), to: toIso(y.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1))));
      case '7d':
        final from = startOfToday.subtract(const Duration(days: 13));
        final to = startOfToday.subtract(const Duration(days: 7)).subtract(const Duration(microseconds: 1));
        return (from: toIso(from), to: toIso(to));
      case '90d':
        final from = startOfToday.subtract(const Duration(days: 179));
        final to = startOfToday.subtract(const Duration(days: 90)).subtract(const Duration(microseconds: 1));
        return (from: toIso(from), to: toIso(to));
      case '30d':
      default:
        final from = startOfToday.subtract(const Duration(days: 59));
        final to = startOfToday.subtract(const Duration(days: 30)).subtract(const Duration(microseconds: 1));
        return (from: toIso(from), to: toIso(to));
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final range = _dateRangeToIso();
    final prior = _priorRangeIso();
    try {
      final results = await Future.wait([
        NeyvoPulseApi.getAnalyticsOverview(from: range.from, to: range.to),
        NeyvoPulseApi.getAnalyticsComms(from: range.from, to: range.to),
        NeyvoPulseApi.getAnalyticsStudio(from: range.from, to: range.to),
        NeyvoPulseApi.getInsights().catchError((_) => <String, dynamic>{}),
        NeyvoPulseApi.getCallbacksAnalytics().catchError((_) => <String, dynamic>{}),
        NeyvoPulseApi.getBillingWallet().catchError((_) => <String, dynamic>{}),
        NeyvoPulseApi.getBillingTransactions(limit: 50, offset: 0, type: 'all').catchError((_) => <String, dynamic>{}),
        NeyvoPulseApi.listStudents().catchError((_) => <String, dynamic>{'students': []}),
        NeyvoPulseApi.listCampaigns().catchError((_) => <String, dynamic>{'campaigns': []}),
        NeyvoPulseApi.listAgents().catchError((_) => <String, dynamic>{'agents': []}),
        NeyvoPulseApi.listNumbers().catchError((_) => <String, dynamic>{'numbers': []}),
        NeyvoPulseApi.listCalls(from: range.from, to: range.to, limit: 500).catchError((_) => <String, dynamic>{'calls': []}),
        NeyvoPulseApi.listCalls(from: prior.from, to: prior.to, limit: 500).catchError((_) => <String, dynamic>{'calls': []}),
      ]);
      if (!mounted) return;
      final stList = (results[7] as Map)['students'] as List? ?? [];
      final campList = (results[8] as Map)['campaigns'] as List? ?? [];
      final agList = (results[9] as Map)['agents'] as List? ?? [];
      final numList = (results[10] as Map)['numbers'] as List? ?? (results[10] as Map)['items'] as List? ?? [];
      final callsRes = results[11] as Map<String, dynamic>;
      final priorCallsRes = results[12] as Map<String, dynamic>;
      final calls = (callsRes['calls'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final priorCalls = (priorCallsRes['calls'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      setState(() {
        _overview = results[0] as Map<String, dynamic>;
        _comms = results[1] as Map<String, dynamic>;
        _studio = results[2] as Map<String, dynamic>;
        _insights = results[3] as Map<String, dynamic>? ?? {};
        _callbacksAnalytics = results[4] as Map<String, dynamic>? ?? {};
        _wallet = results[5] as Map<String, dynamic>? ?? {};
        _transactionsRes = results[6] as Map<String, dynamic>? ?? {};
        _students = stList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _campaigns = campList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _agents = agList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _numbers = numList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _callsForKpi = calls;
        _priorCallsForKpi = priorCalls;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openDownloadReportDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NeyvoTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _InsightsReportDownloadSheet(
        onGenerate: (sections) => _generateReportCsv(sections),
      ),
    );
  }

  Future<void> _generateReportCsv(Set<String> sections) async {
    Navigator.of(context).pop();
    final sb = StringBuffer();
    sb.writeln('Insights Report,Generated ${DateTime.now().toIso8601String().substring(0, 19)}');
    sb.writeln('Date range,$_dateRange');
    sb.writeln('');
    if (sections.contains('overview')) {
      final d = _overview ?? {};
      sb.writeln('Section,Overview');
      sb.writeln('Total Calls,${d['total_calls'] ?? d['calls_this_period'] ?? 0}');
      sb.writeln('Credits Consumed,${d['total_credits_consumed'] ?? d['credits_consumed'] ?? 0}');
      sb.writeln('Wallet Balance,${d['wallet_credits'] ?? d['credits'] ?? _wallet?['credits'] ?? 0}');
      sb.writeln('TTS Minutes,${d['total_tts_minutes'] ?? d['tts_minutes'] ?? 0}');
      sb.writeln('');
    }
    if (sections.contains('calls')) {
      sb.writeln('Section,Calls Summary');
      sb.writeln('Total Calls,${(_comms?['total_calls'] ?? 0)}');
      sb.writeln('Resolved,${(_comms?['resolved_count'] ?? 0)}');
      sb.writeln('Unresolved,${(_comms?['unresolved_count'] ?? 0)}');
      sb.writeln('');
    }
    if (sections.contains('campaigns')) {
      sb.writeln('Section,Campaigns');
      sb.writeln('Name,Status,Total Planned');
      for (final c in _campaigns) {
        sb.writeln('"${(c['name'] ?? '').toString().replaceAll('"', '""')}",${c['status'] ?? ''},${c['total_planned'] ?? ''}');
      }
      sb.writeln('');
    }
    if (sections.contains('students')) {
      sb.writeln('Section,Students');
      sb.writeln('Total,${_students.length}');
      sb.writeln('');
    }
    if (sections.contains('operators')) {
      sb.writeln('Section,Operators');
      final byAgent = (_comms?['by_agent'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final a in byAgent) {
        sb.writeln('"${(a['name'] ?? '').toString().replaceAll('"', '""')}",${a['total_calls'] ?? 0},${a['credits_used'] ?? 0}');
      }
      sb.writeln('');
    }
    if (sections.contains('lines')) {
      sb.writeln('Section,Lines');
      sb.writeln('Numbers Count,${_numbers.length}');
      sb.writeln('');
    }
    if (sections.contains('wallet')) {
      sb.writeln('Section,Wallet & Transactions');
      sb.writeln('Balance,${_wallet?['credits'] ?? 0}');
      final txList = (_transactionsRes?['transactions'] as List?) ?? [];
      sb.writeln('Date,Type,Amount,Description');
      for (final t in txList.take(100)) {
        final m = Map<String, dynamic>.from(t as Map);
        sb.writeln('${UserTimezoneService.format(m['created_at'])},${m['type']},${m['amount'] ?? ''},"${(m['description'] ?? '').toString().replaceAll('"', '""')}"');
      }
      sb.writeln('');
    }
    if (sections.contains('pulse')) {
      sb.writeln('Section,Pulse Insights');
      sb.writeln('Success Rate %,${_insights?['success_rate_pct'] ?? 0}');
      sb.writeln('Recommendations,${(_insights?['recommendations'] as List?)?.join('; ') ?? ''}');
      sb.writeln('');
    }
    if (sections.contains('callbacks')) {
      sb.writeln('Section,Callbacks');
      final a = _callbacksAnalytics?['analytics'] as Map? ?? {};
      sb.writeln('Scheduled,${a['scheduled'] ?? 0}');
      sb.writeln('Completed,${a['completed'] ?? 0}');
      sb.writeln('');
    }
    final csv = sb.toString();
    if (csv.isEmpty) return;
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final filename = 'insights_report_$date.csv';
    if (mounted) {
      await downloadCsv(filename, '\uFEFF$csv', context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = TenantBrand.primary(context);
    if (_loading && _overview == null) {
      return buildNeyvoLoadingState();
    }
    if (_error != null && _overview == null) {
      return buildNeyvoErrorState(onRetry: _load);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: title + date range + prominent Download button
          Row(
            children: [
              Text(
                'Insights',
                style: NeyvoTextStyles.title.copyWith(
                  fontWeight: FontWeight.w700,
                  color: NeyvoColors.textPrimary,
                ),
              ),
              const SizedBox(width: 24),
              _dateChip('Today', 'today'),
              const SizedBox(width: 8),
              _dateChip('7d', '7d'),
              const SizedBox(width: 8),
              _dateChip('30d', '30d'),
              const SizedBox(width: 8),
              _dateChip('90d', '90d'),
              const Spacer(),
              FilledButton.icon(
                onPressed: _openDownloadReportDialog,
                icon: const Icon(Icons.download_outlined, size: 20),
                label: const Text('Download report'),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildOverviewSection(),
          const SizedBox(height: 24),
          _buildCallsSection(),
          const SizedBox(height: 24),
          _buildCampaignsSection(),
          const SizedBox(height: 24),
          _buildStudentsSection(),
          const SizedBox(height: 24),
          _buildOperatorsSection(),
          const SizedBox(height: 24),
          _buildLinesSection(),
          const SizedBox(height: 24),
          _buildWalletBillingSection(),
          const SizedBox(height: 24),
          _buildPulseInsightsSection(),
          const SizedBox(height: 24),
          _buildCallbacksSection(),
          const SizedBox(height: 24),
          _buildStudioSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    final d = _overview ?? {};
    final comms = _comms ?? {};
    final creditsConsumed = (d['total_credits_consumed'] ?? d['credits_consumed'] ?? 0) as num;
    final walletCredits = (d['wallet_credits'] ?? d['credits'] ?? 0) as num;
    final totalCalls = (d['total_calls'] ?? d['calls_this_period'] ?? 0) as num;
    final ttsMinutes = (d['total_tts_minutes'] ?? d['tts_minutes'] ?? 0) as num;
    final List<FlSpot> creditsSpots = _creditsBurnedSpots(d);
    // Prefer calls-by-calendar-date for the analysis chart (Overview)
    final callsByDateRaw = comms['calls_by_date'] as List?;
    final overviewCallsByDate = callsByDateRaw != null
        ? callsByDateRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final overviewCallsPerDay = overviewCallsByDate.isNotEmpty
        ? overviewCallsByDate.map((e) => (e['count'] as num?)?.toInt() ?? 0).toList()
        : (comms['calls_per_day'] as List?) ?? [];
    final hasCallsChart = overviewCallsByDate.isNotEmpty || overviewCallsPerDay.isNotEmpty;
    final kpi = _computeKpis(_callsForKpi);
    final priorKpi = _computeKpis(_priorCallsForKpi);

    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: NeyvoTextStyles.heading),
          const SizedBox(height: 16),
          _buildKpiRow(kpi: kpi, priorKpi: priorKpi),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _OverviewStatCard(label: 'Total Calls', value: totalCalls.toInt().toString()),
              _OverviewStatCard(label: 'Credits Consumed', value: creditsConsumed.toInt().toString()),
              _OverviewStatCard(label: 'Wallet Balance', value: walletCredits.toInt().toString()),
              _OverviewStatCard(label: 'TTS Minutes', value: ttsMinutes.toStringAsFixed(0)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: hasCallsChart
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final count = overviewCallsByDate.isNotEmpty ? overviewCallsByDate.length : overviewCallsPerDay.length;
                      final minWidth = (count * 24).toDouble().clamp(200.0, 1200.0);
                      final content = _CallsBarChart(
                        callsByDate: overviewCallsByDate,
                        callsPerDay: overviewCallsPerDay,
                      );
                      if (constraints.maxWidth < minWidth) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(width: minWidth, height: 220, child: content),
                        );
                      }
                      return content;
                    },
                  )
                : creditsSpots.isEmpty
                    ? Center(
                        child: Text(
                          'Make calls to see usage data',
                          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
                        ),
                      )
                    : _CreditsLineChart(spots: creditsSpots),
          ),
        ],
      ),
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
      _InsightsKpiCard(
        title: 'TOTAL CALLS',
        value: total > 0 ? NumberFormat('#,###').format(total) : '--',
        trend: trendTotal,
        topBorderColor: Colors.blue,
        icon: Icons.phone_outlined,
        iconColor: Colors.blue,
      ),
      _InsightsKpiCard(
        title: 'CALLS ANSWERED',
        value: total > 0 ? NumberFormat('#,###').format(kpi.answered) : '--',
        subtitle: total > 0 ? '${answerRate.toStringAsFixed(1)}%' : null,
        trend: trendAnswered,
        topBorderColor: Colors.green,
        icon: Icons.check_circle_outline,
        iconColor: Colors.green,
      ),
      _InsightsKpiCard(
        title: 'ABANDON CALLS',
        value: total > 0 ? NumberFormat('#,###').format(kpi.abandoned) : '--',
        subtitle: total > 0 ? '${abandonRate.toStringAsFixed(1)}%' : null,
        trend: trendAbandon,
        topBorderColor: Colors.red,
        icon: Icons.phone_disabled_outlined,
        iconColor: Colors.red,
      ),
      _InsightsKpiCard(
        title: 'ASA (Sec)',
        value: kpi.asaSec != null ? '${kpi.asaSec}' : '--',
        trend: trendAsa,
        topBorderColor: Colors.orange,
        icon: Icons.timer_outlined,
        iconColor: Colors.orange,
        tooltip: 'Average Speed of Answer',
      ),
      _InsightsKpiCard(
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

  Widget _buildCallsSection() {
    final d = _comms ?? {};
    final totalCalls = (d['total_calls'] ?? 0) as num;
    final resolved = (d['resolved_count'] ?? d['resolved'] ?? 0) as num;
    final unresolved = (d['unresolved_count'] ?? d['unresolved'] ?? 0) as num;
    final noAnswer = (d['no_answer_count'] ?? d['no_answer'] ?? 0) as num;
    final transferred = (d['transferred_count'] ?? d['transferred'] ?? 0) as num;
    final agents = (d['by_agent'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calls', style: NeyvoTextStyles.heading),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 720;
              final chart = NeyvoCard(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 70,
                      sections: [
                        PieChartSectionData(
                          value: resolved.toDouble(),
                          color: NeyvoColors.success,
                          title: resolved > 0 ? resolved.toString() : '',
                          titleStyle: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textPrimary),
                          radius: 24,
                        ),
                        PieChartSectionData(
                          value: unresolved.toDouble(),
                          color: NeyvoColors.error,
                          title: unresolved > 0 ? unresolved.toString() : '',
                          titleStyle: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textPrimary),
                          radius: 24,
                        ),
                        PieChartSectionData(
                          value: noAnswer.toDouble(),
                          color: NeyvoColors.textMuted,
                          title: noAnswer > 0 ? noAnswer.toString() : '',
                          titleStyle: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textPrimary),
                          radius: 24,
                        ),
                        PieChartSectionData(
                          value: transferred.toDouble(),
                          color: NeyvoColors.info,
                          title: transferred > 0 ? transferred.toString() : '',
                          titleStyle: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textPrimary),
                          radius: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              );
              final legend = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendItem('Resolved', NeyvoColors.success, resolved, totalCalls),
                  _legendItem('Unresolved', NeyvoColors.error, unresolved, totalCalls),
                  _legendItem('No Answer', NeyvoColors.textMuted, noAnswer, totalCalls),
                  _legendItem('Transferred', NeyvoColors.info, transferred, totalCalls),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [chart, const SizedBox(height: 16), legend],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  chart,
                  const SizedBox(width: 24),
                  Expanded(child: legend),
                ],
              );
            },
          ),
          if (agents.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Per-Operator Performance', style: NeyvoTextStyles.heading),
            const SizedBox(height: 8),
            NeyvoCard(
              padding: EdgeInsets.zero,
              child: _AgentPerfTable(agents: agents),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCampaignsSection() {
    final running = _campaigns.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'running').length;
    final completed = _campaigns.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'completed').length;
    final draft = _campaigns.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'draft').length;
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Campaigns', style: NeyvoTextStyles.heading),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _OverviewStatCard(label: 'Total', value: '${_campaigns.length}'),
              _OverviewStatCard(label: 'Running', value: '$running'),
              _OverviewStatCard(label: 'Completed', value: '$completed'),
              _OverviewStatCard(label: 'Draft', value: '$draft'),
            ],
          ),
          if (_campaigns.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'No campaigns yet.',
                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Download campaign report'),
                onPressed: _campaigns.length == 1
                    ? () => _downloadSingleCampaignReport(_campaigns.first['id']?.toString() ?? '')
                    : () => _showCampaignReportPicker(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Table(
                columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
                children: [
                  TableRow(
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: NeyvoColors.borderSubtle))),
                    children: [
                      _th('Name'),
                      _th('Status'),
                      _th('Planned'),
                    ],
                  ),
                  ..._campaigns.take(15).map((c) => TableRow(
                        children: [
                          _td(c['name']?.toString() ?? '—'),
                          _td(c['status']?.toString() ?? '—'),
                          _td('${c['total_planned'] ?? '—'}'),
                        ],
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _downloadSingleCampaignReport(String campaignId) async {
    try {
      final res = await NeyvoPulseApi.getCampaignReport(campaignId);
      if (res['ok'] != true || !mounted) return;
      final campaign = Map<String, dynamic>.from(res['campaign'] as Map);
      final items = (res['call_items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final callDetails = (res['call_details'] as Map?)?.map((k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map))) ?? {};
      final sb = StringBuffer();
      sb.writeln('Campaign,${_escapeCsv(campaign['name']?.toString() ?? '')}');
      sb.writeln('Status,${campaign['status'] ?? ''}');
      sb.writeln('Call Items,,,,');
      sb.writeln('Name,Phone,Status,VAPI Call ID,Summary');
      for (final it in items) {
        final vapiId = (it['vapi_call_id'] ?? '').toString();
        final detail = callDetails[vapiId];
        final summary = _escapeCsv((detail?['summary'] ?? '').toString().replaceAll('\n', ' '));
        sb.writeln('"${_escapeCsv(it['name']?.toString() ?? '')}","${_escapeCsv(it['phone']?.toString() ?? '')}",${it['status'] ?? ''},$vapiId,"$summary"');
      }
      final date = DateTime.now().toIso8601String().substring(0, 10);
      if (!mounted) return;
      await downloadCsv('campaign_report_$date.csv', '\uFEFF${sb.toString()}', context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  String _escapeCsv(String s) => s.replaceAll('"', '""');

  void _showCampaignReportPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NeyvoTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Select campaign to download report', style: NeyvoTextStyles.heading),
            const SizedBox(height: 16),
            ..._campaigns.map((c) => ListTile(
                  title: Text(c['name']?.toString() ?? 'Unnamed'),
                  subtitle: Text('${c['status'] ?? ''} · ${c['total_planned'] ?? 0} contacts'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _downloadSingleCampaignReport(c['id']?.toString() ?? '');
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsSection() {
    final withBalance = _students.where((s) {
      final b = s['balance'];
      if (b == null) return false;
      final n = double.tryParse(b.toString().replaceAll(r'$', '').replaceAll(',', ''));
      return n != null && n > 0;
    }).length;
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Students', style: NeyvoTextStyles.heading),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _OverviewStatCard(label: 'Total', value: '${_students.length}'),
              _OverviewStatCard(label: 'With balance', value: '$withBalance'),
            ],
          ),
          if (_students.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'No students yet.',
                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOperatorsSection() {
    final byAgent = (_comms?['by_agent'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Operators', style: NeyvoTextStyles.heading),
          const SizedBox(height: 8),
          Text('Total: ${_agents.length}', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted)),
          if (byAgent.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'No call data by operator yet.',
                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _AgentPerfTable(agents: byAgent),
            ),
        ],
      ),
    );
  }

  Widget _buildLinesSection() {
    final count = _numbers.length;
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lines (Numbers)', style: NeyvoTextStyles.heading),
          const SizedBox(height: 12),
          _OverviewStatCard(label: 'Phone numbers', value: '$count'),
          if (count > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '~${115 * count} credits/mo',
                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWalletBillingSection() {
    final balance = (_wallet?['credits'] ?? 0) as num;
    final plan = _wallet?['subscription_tier'] ?? '—';
    final tier = _wallet?['voice_tier'] ?? '—';
    final txList = (_transactionsRes?['transactions'] as List?) ?? [];
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Wallet & Billing', style: NeyvoTextStyles.heading),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _OverviewStatCard(label: 'Balance (credits)', value: balance.toInt().toString()),
              _OverviewStatCard(label: 'Plan', value: plan.toString()),
              _OverviewStatCard(label: 'Voice tier', value: tier.toString()),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Recent transactions: ${txList.length}',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseInsightsSection() {
    final total = (_insights?['total_calls'] ?? 0) as num;
    final rate = (_insights?['success_rate_pct'] ?? 0) as num;
    final topics = (_insights?['topics'] as List?) ?? [];
    final recs = (_insights?['recommendations'] as List?) ?? [];
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pulse Insights', style: NeyvoTextStyles.heading),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _OverviewStatCard(label: 'Total calls', value: '$total'),
              _OverviewStatCard(label: 'Success rate', value: '${rate.toStringAsFixed(1)}%'),
            ],
          ),
          if (topics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Topics', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: topics.map<Widget>((t) {
                final m = Map<String, dynamic>.from(t as Map);
                return Chip(
                  label: Text('${m['label'] ?? ''} (${m['count'] ?? 0})'),
                  backgroundColor: NeyvoColors.teal.withValues(alpha: 0.1),
                );
              }).toList(),
            ),
          ],
          if (recs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Recommendations', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
            const SizedBox(height: 4),
            ...recs.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $r', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
                )),
          ],
          if (total == 0 && topics.isEmpty && recs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No insights yet. Make calls to see topics and recommendations.',
                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCallbacksSection() {
    final a = _callbacksAnalytics?['analytics'] as Map? ?? {};
    final scheduled = a['scheduled'] ?? 0;
    final completed = a['completed'] ?? 0;
    final exhausted = a['exhausted'] ?? 0;
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Callbacks', style: NeyvoTextStyles.heading),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _OverviewStatCard(label: 'Scheduled', value: '$scheduled'),
              _OverviewStatCard(label: 'Completed', value: '$completed'),
              _OverviewStatCard(label: 'Exhausted', value: '$exhausted'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudioSection() {
    final d = _studio ?? {};
    final totalGens = (d['total_generations'] ?? 0) as num;
    final totalMinutes = (d['total_audio_minutes'] ?? 0) as num;
    final projects = (d['by_project'] ?? d['projects'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Voice Studio', style: NeyvoTextStyles.heading),
          const SizedBox(height: 12),
          if (totalGens == 0 && totalMinutes == 0 && projects.isEmpty)
            Text(
              'Enable Voice Studio to see studio analytics.',
              style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
            )
          else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _OverviewStatCard(label: 'TTS Generations', value: totalGens.toString()),
                _OverviewStatCard(label: 'Audio Minutes', value: totalMinutes.toStringAsFixed(1)),
              ],
            ),
            if (projects.isNotEmpty) ...[
              const SizedBox(height: 16),
              NeyvoCard(
                padding: EdgeInsets.zero,
                child: Table(
                  columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: NeyvoColors.borderSubtle))),
                      children: [_th('Project'), _th('Generations'), _th('Minutes')],
                    ),
                    ...projects.map((p) => TableRow(
                          children: [
                            _td(p['name']?.toString() ?? '—'),
                            _td('${p['generations'] ?? 0}'),
                            _td('${p['minutes'] ?? 0}'),
                          ],
                        )),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<FlSpot> _creditsBurnedSpots(Map<String, dynamic> d) {
    final perDay = d['credits_per_day'] as List?;
    if (perDay != null && perDay.isNotEmpty) {
      return perDay.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value as num).toDouble())).toList();
    }
    final total = (d['total_credits_consumed'] ?? d['credits_consumed'] ?? 0) as num;
    if (total > 0) {
      return [const FlSpot(0, 0), FlSpot(1, total.toDouble())];
    }
    return [];
  }

  Widget _dateChip(String label, String value) {
    final isActive = _dateRange == value;
    return GestureDetector(
      onTap: () {
        setState(() => _dateRange = value);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? NeyvoColors.teal.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isActive ? NeyvoColors.teal.withValues(alpha: 0.3) : NeyvoColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: NeyvoTextStyles.label.copyWith(
            color: isActive ? NeyvoColors.teal : NeyvoColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color, num value, num total) {
    final pct = total > 0 ? (value / total * 100).toStringAsFixed(0) : '0';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Text('$label — $pct%', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _th(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text.toUpperCase(),
          style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted, letterSpacing: 0.5),
        ),
      );

  Widget _td(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(text, style: NeyvoTextStyles.bodyPrimary),
      );
}

class _InsightsReportDownloadSheet extends StatefulWidget {
  final void Function(Set<String> sections) onGenerate;

  const _InsightsReportDownloadSheet({required this.onGenerate});

  @override
  State<_InsightsReportDownloadSheet> createState() => _InsightsReportDownloadSheetState();
}

class _InsightsReportDownloadSheetState extends State<_InsightsReportDownloadSheet> {
  final Set<String> _selected = {
    'overview', 'calls', 'campaigns', 'students', 'operators', 'lines', 'wallet', 'pulse', 'callbacks',
  };

  static const _options = [
    ('overview', 'Overview', 'Total calls, credits consumed, wallet balance, TTS minutes'),
    ('calls', 'Calls', 'Call volume, resolved/unresolved counts'),
    ('campaigns', 'Campaigns', 'Campaign list with name, status, total planned'),
    ('students', 'Students', 'Student count summary'),
    ('operators', 'Operators', 'Per-operator calls and credits used'),
    ('lines', 'Lines', 'Phone numbers count'),
    ('wallet', 'Wallet & Billing', 'Balance and recent transactions'),
    ('pulse', 'Pulse Insights', 'Success rate and recommendations'),
    ('callbacks', 'Callbacks', 'Scheduled and completed callbacks'),
  ];

  void _selectAll() {
    setState(() {
      for (final e in _options) _selected.add(e.$1);
    });
  }

  void _clearAll() {
    setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.download_outlined, size: 28, color: NeyvoColors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download report',
                      style: NeyvoTextStyles.heading,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose what to include in your CSV report. You can select one or more sections.',
                      style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: _selectAll,
                child: const Text('Select all'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _clearAll,
                child: const Text('Clear all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: _options.map((e) {
                  final id = e.$1;
                  final label = e.$2;
                  final desc = e.$3;
                  return CheckboxListTile(
                    value: _selected.contains(id),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) _selected.add(id);
                        else _selected.remove(id);
                      });
                    },
                    title: Text(label, style: NeyvoTextStyles.bodyPrimary),
                    subtitle: desc.isNotEmpty
                        ? Text(desc, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted, fontSize: 12))
                        : null,
                    activeColor: NeyvoColors.teal,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () {
                  if (_selected.isEmpty) return;
                  widget.onGenerate(_selected);
                },
                icon: const Icon(Icons.download_outlined, size: 18),
                style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                label: const Text('Generate & download'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallsBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> callsByDate;
  final List<dynamic> callsPerDay;

  const _CallsBarChart({required this.callsByDate, required this.callsPerDay});

  static String _formatCalendarDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final d = DateTime.parse(dateStr);
      return DateFormat.MMMd().format(d);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = callsByDate.isNotEmpty
        ? callsByDate.map((e) => (e['count'] as num?)?.toDouble() ?? 0.0).toList()
        : callsPerDay.map((e) => (e is num ? e : 0).toDouble()).toList();
    final dateLabels = callsByDate.isNotEmpty
        ? callsByDate.map((e) => _formatCalendarDate((e['date'] as String?)?.substring(0, 10))).toList()
        : List.generate(counts.length, (i) {
            final d = DateTime.now().subtract(Duration(days: counts.length - 1 - i));
            return DateFormat.MMMd().format(d);
          });
    final maxY = counts.isEmpty ? 2.0 : (counts.reduce((a, b) => a > b ? a : b) + 2);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                final label = i >= 0 && i < dateLabels.length ? dateLabels[i] : '${v.toInt()}';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(label, style: NeyvoTextStyles.micro, maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              },
              reservedSize: 32,
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: NeyvoTextStyles.micro),
              reservedSize: 28,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: NeyvoColors.borderSubtle, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: counts.asMap().entries.map((e) {
          final v = e.value;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: v,
                color: NeyvoColors.teal,
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
            showingTooltipIndicators: [0],
          );
        }).toList(),
      ),
    );
  }
}

class _AgentPerfTable extends StatelessWidget {
  final List<Map<String, dynamic>> agents;

  const _AgentPerfTable({required this.agents});

  static Widget _cell(String text, {bool header = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: header
              ? NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted, letterSpacing: 0.5)
              : NeyvoTextStyles.bodyPrimary,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: FixedColumnWidth(220),
          1: FixedColumnWidth(90),
          2: FixedColumnWidth(110),
          3: FixedColumnWidth(120),
          4: FixedColumnWidth(110),
          5: FixedColumnWidth(110),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: NeyvoColors.borderSubtle))),
            children: [
              _cell('AGENT', header: true),
              _cell('CALLS', header: true),
              _cell('RESOLVED %', header: true),
              _cell('AVG DURATION', header: true),
              _cell('CREDITS', header: true),
              _cell('CR/CALL', header: true),
            ],
          ),
          ...agents.map((a) {
            final calls = (a['total_calls'] as num?)?.toInt() ?? 0;
            final credits = (a['credits_used'] as num?)?.toInt() ?? 0;
            final crPerCall = calls > 0 ? (credits / calls).toStringAsFixed(1) : '—';
            return TableRow(
              children: [
                _cell(a['name']?.toString() ?? '—'),
                _cell('$calls'),
                _cell('${a['resolution_rate'] ?? 0}%'),
                _cell('${a['avg_duration_seconds'] ?? 0}s'),
                _cell('$credits'),
                _cell(crPerCall),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  final String label;
  final String value;

  const _OverviewStatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return NeyvoCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
          const SizedBox(height: 8),
          Text(
            value,
            style: NeyvoTextStyles.display.copyWith(fontSize: 22, color: NeyvoColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _CreditsLineChart extends StatelessWidget {
  final List<FlSpot> spots;

  const _CreditsLineChart({required this.spots});

  @override
  Widget build(BuildContext context) {
    final maxY = spots.isEmpty ? 1.0 : (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 10);
    final maxX = spots.isEmpty ? 7.0 : spots.last.x;
    // Calendar date labels for x-axis (last N days) instead of "Day 0", "Day 1"
    final bottomLabels = spots.isEmpty
        ? <String>[]
        : List.generate(spots.length, (i) {
            final d = DateTime.now().subtract(Duration(days: spots.length - 1 - i));
            return DateFormat.MMMd().format(d);
          });
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) => FlLine(color: NeyvoColors.borderSubtle, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: NeyvoTextStyles.micro),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                final label = (i >= 0 && i < bottomLabels.length) ? bottomLabels[i] : 'Day ${v.toInt()}';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(label, style: NeyvoTextStyles.micro, maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: NeyvoColors.teal,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  NeyvoColors.tealGlow,
                  NeyvoColors.tealGlow.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String trend;
  final Color topBorderColor;
  final IconData icon;
  final Color iconColor;
  final String? tooltip;

  const _InsightsKpiCard({
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
