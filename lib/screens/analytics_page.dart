// File: analytics_page.dart
// Insights: full analytics (Overview, Calls, Campaigns, Students, Operators, Lines, Wallet, Pulse, Callbacks, Studio).

import 'dart:math' show sqrt;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../services/user_timezone_service.dart';
import '../theme/neyvo_theme.dart';
import '../tenant/tenant_brand.dart';
import '../widgets/neyvo_empty_state.dart';
import '../ui/components/glass/neyvo_glass_panel.dart';
import '../utils/export_csv.dart';
import 'pulse_shell.dart';

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
  /// Performance Trend view: 'calls' | 'both' | 'rate'
  String _performanceTrendTab = 'both';

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
    return ColoredBox(
      color: const Color(0xFFF5F7FB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAlertBanner(),
            _buildPageHeader(),
            const SizedBox(height: 20),
            _buildGoodwinKpiGrid(),
            const SizedBox(height: 22),
            _buildChartsRow(),
            const SizedBox(height: 22),
            _buildRecBanner(),
            const SizedBox(height: 22),
            _buildBottomRow(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBanner() {
    final balance = (_wallet?['credits'] ?? 0) as num;
    if (balance.toInt() > 200) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border(bottom: BorderSide(color: NeyvoColors.warning.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFF92400E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Low credits — ${balance.toInt()} remaining. Top up to keep calling.',
              style: NeyvoTextStyles.body.copyWith(fontSize: 13, color: const Color(0xFF92400E)),
            ),
          ),
          GestureDetector(
            onTap: () => PulseShellController.navigatePulse(context, PulseRouteNames.billing),
            child: Text(
              'Top up →',
              style: NeyvoTextStyles.label.copyWith(
                color: NeyvoColors.ubLightBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    final lastUpdated = DateFormat('MMMM d, y').format(DateTime.now());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Performance Overview', style: NeyvoTextStyles.heading.copyWith(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                'Last updated: $lastUpdated',
                style: NeyvoTextStyles.body.copyWith(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Single gray container for time tabs (segmented control)
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFE4E9F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _timeTab('Today', 'today'),
                  _timeTab('7d', '7d'),
                  _timeTab('30d', '30d'),
                  _timeTab('90d', '90d'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: const Color(0xFF0D2B6E),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _openDownloadReportDialog,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download_outlined, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Download report', style: NeyvoTextStyles.label.copyWith(color: Colors.white, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _timeTab(String label, String value) {
    final isActive = _dateRange == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _dateRange = value);
          _load();
        },
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))] : null,
          ),
          child: Text(
            label,
            style: NeyvoTextStyles.label.copyWith(
              color: isActive ? const Color(0xFF0D2B6E) : const Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// Goodwin-style 5 KPI cards: Total Calls, Success Rate, Credits Consumed, Active Campaigns, TTS Minutes
  Widget _buildGoodwinKpiGrid() {
    final d = _overview ?? {};
    final comms = _comms ?? {};
    final totalCalls = (d['total_calls'] ?? d['calls_total'] ?? 0) as num;
    final creditsConsumed = (d['total_credits_consumed'] ?? d['credits_consumed'] ?? 0) as num;
    final walletCredits = (d['wallet_credits'] ?? _wallet?['credits'] ?? 0) as num;
    final ttsMinutes = (d['total_tts_minutes'] ?? d['tts_minutes'] ?? 0) as num;
    final successRate = (_insights?['success_rate_pct'] ?? 0) as num;
    final resolvedCount = (comms['resolved_count'] ?? 0) as num;
    final runningCampaigns = _campaigns.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'running').length;
    final priorTotal = _priorCallsForKpi.length;
    final deltaCalls = _callsForKpi.length - priorTotal;
    final voiceTier = _wallet?['voice_tier']?.toString() ?? 'natural';

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900 ? 5 : (constraints.maxWidth > 600 ? 3 : 1);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.5,
          children: [
            _GoodwinKpiCard(
              label: 'Total Calls',
              value: '${totalCalls.toInt()}',
              badge: deltaCalls != 0 ? '${deltaCalls > 0 ? "↗ " : ""}+$deltaCalls this period' : null,
              badgeUp: deltaCalls > 0,
              accentColor: NeyvoColors.ubLightBlue,
            ),
            _GoodwinKpiCard(
              label: 'Success Rate',
              value: '${successRate.toStringAsFixed(1)}%',
              badge: resolvedCount == 0 ? '↓ No resolved yet' : '↗ ${successRate.toStringAsFixed(1)}%',
              badgeUp: resolvedCount > 0,
              accentColor: NeyvoColors.success,
            ),
            _GoodwinKpiCard(
              label: 'Credits Consumed',
              value: '${creditsConsumed.toInt()}',
              badge: 'Balance: ${walletCredits.toInt()}',
              accentColor: NeyvoColors.warning,
            ),
            _GoodwinKpiCard(
              label: 'Active Campaigns',
              value: '$runningCampaigns',
              badge: '↑ $runningCampaigns running',
              badgeUp: true,
              accentColor: NeyvoColors.ubPurple,
            ),
            _GoodwinKpiCard(
              label: 'TTS Minutes',
              value: '${ttsMinutes.toStringAsFixed(0)}',
              subtitle: 'Voice tier: $voiceTier',
              accentColor: NeyvoColors.ubLightBlue,
            ),
          ],
        );
      },
    );
  }

  /// Performance Trend (bars + resolution rate line) + Call Outcomes donut
  Widget _buildChartsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 700;
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildPerformanceTrendCard(),
                ),
                if (!narrow) const SizedBox(width: 14),
                if (!narrow) Expanded(flex: 1, child: _buildCallOutcomesCard()),
              ],
            ),
            if (narrow) ...[
              const SizedBox(height: 14),
              _buildCallOutcomesCard(),
            ],
          ],
        );
      },
    );
  }

  /// Performance Trend: Total Calls (bars) + Resolution Rate % (line). Tabs: Calls | Both | Rate.
  Widget _buildPerformanceTrendCard() {
    final dailyBreakdown = _dailyCallBreakdown();
    final year = DateTime.now().year;
    final trendData = dailyBreakdown.map((d) {
      final r = (d['resolved'] as num?)?.toInt() ?? 0;
      final u = (d['unresolved'] as num?)?.toInt() ?? 0;
      final n = (d['no_answer'] as num?)?.toInt() ?? 0;
      final total = r + u + n;
      final resolutionRate = total > 0 ? (r / total * 100) : 0.0;
      return {'date': d['date'], 'total': total, 'resolutionRate': resolutionRate};
    }).toList();
    String dateRangeLabel = '—';
    if (trendData.isNotEmpty) {
      try {
        final first = DateFormat.MMMd().format(DateTime.parse((trendData.first['date'] ?? '').toString().substring(0, 10)));
        final last = DateFormat.MMMd().format(DateTime.parse((trendData.last['date'] ?? '').toString().substring(0, 10)));
        dateRangeLabel = '$first - $last, $year';
      } catch (_) {}
    }

    return _InsightsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with tabs at top right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Performance Trend', style: NeyvoTextStyles.heading.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _performanceTrendTabButton('Calls', 'calls'),
                  const SizedBox(width: 4),
                  _performanceTrendTabButton('Both', 'both'),
                  const SizedBox(width: 4),
                  _performanceTrendTabButton('Rate', 'rate'),
                ],
              ),
            ],
          ),
          // Notations (legend) below heading
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Total Calls ($dateRangeLabel)',
                    style: NeyvoTextStyles.micro.copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size(20, 4),
                    painter: _DashedLinePainter(color: const Color(0xFFF97316), strokeWidth: 2),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Resolution Rate',
                    style: NeyvoTextStyles.micro.copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: trendData.isEmpty
                ? Center(
                    child: Text(
                      'Make calls to see performance trend',
                      style: NeyvoTextStyles.body.copyWith(color: const Color(0xFF94A3B8)),
                    ),
                  )
                : _PerformanceTrendChart(
                    trendData: trendData,
                    tab: _performanceTrendTab,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _performanceTrendTabButton(String label, String value) {
    final isSelected = _performanceTrendTab == value;
    return Material(
      color: isSelected ? const Color(0xFFE2E8F0) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () => setState(() => _performanceTrendTab = value),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: NeyvoTextStyles.micro.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? const Color(0xFF334155) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 5),
        Text(label, style: NeyvoTextStyles.micro),
      ],
    );
  }

  /// Per-day resolved / unresolved / no_answer from _callsForKpi
  List<Map<String, dynamic>> _dailyCallBreakdown() {
    final now = DateTime.now();
    final range = _dateRangeToIso();
    final from = DateTime.tryParse(range.from);
    final to = DateTime.tryParse(range.to);
    if (from == null || to == null) return [];
    final days = <String, Map<String, dynamic>>{};
    for (var d = DateTime(from.year, from.month, from.day);
        !d.isAfter(DateTime(to.year, to.month, to.day));
        d = d.add(const Duration(days: 1))) {
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      days[key] = {'date': key, 'resolved': 0, 'unresolved': 0, 'no_answer': 0};
    }
    for (final c in _callsForKpi) {
      final created = _parseDate(c['created_at'] ?? c['start_time'] ?? c['date']);
      if (created == null) continue;
      final key = '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
      final row = days[key];
      if (row == null) continue;
      final o = ((c['outcome'] ?? c['status']) as String?)?.toLowerCase() ?? '';
      if (o == 'completed' || o == 'success') {
        row['resolved'] = (row['resolved'] as int) + 1;
      } else if (o == 'failed' || o == 'error') {
        row['unresolved'] = (row['unresolved'] as int) + 1;
      } else if (o == 'no_answer' || o == 'no-answer' || o == 'no answer') {
        row['no_answer'] = (row['no_answer'] as int) + 1;
      } else {
        row['unresolved'] = (row['unresolved'] as int) + 1;
      }
    }
    final sorted = days.keys.toList()..sort();
    return sorted.map((k) => days[k]!).toList();
  }

  Widget _buildCallOutcomesCard() {
    final comms = _comms ?? {};
    final total = (comms['total_calls'] ?? 0) as num;
    final resolved = (comms['resolved_count'] ?? 0) as num;
    final unresolved = (comms['unresolved_count'] ?? 0) as num;
    final noAnswer = (comms['no_answer_count'] ?? 0) as num;
    final transferred = (comms['transferred_count'] ?? 0) as num;
    final resPct = total > 0 ? (resolved / total * 100).toStringAsFixed(0) : '0';
    final unrPct = total > 0 ? (unresolved / total * 100).toStringAsFixed(0) : '0';
    final noPct = total > 0 ? (noAnswer / total * 100).toStringAsFixed(0) : '0';
    final trPct = total > 0 ? (transferred / total * 100).toStringAsFixed(0) : '0';

    return _InsightsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Call Outcomes', style: NeyvoTextStyles.heading.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('${total.toInt()} total calls', style: NeyvoTextStyles.micro.copyWith(color: const Color(0xFF94A3B8))),
          const SizedBox(height: 16),
          _DonutOutcomes(
            total: total.toInt(),
            resolvedPct: total > 0 ? resolved / total : 0,
            unresolvedPct: total > 0 ? unresolved / total : 0,
            noAnswerPct: total > 0 ? noAnswer / total : 0,
            transferredPct: total > 0 ? transferred / total : 0,
          ),
          const SizedBox(height: 16),
          _DonutLegendRow(color: const Color(0xFF3B82F6), name: 'Resolved', value: '$resPct%'),
          _DonutLegendRow(color: const Color(0xFFEF4444), name: 'Unresolved', value: '$unrPct%'),
          _DonutLegendRow(color: const Color(0xFF94A3B8), name: 'No answer', value: '$noPct%'),
          _DonutLegendRow(color: const Color(0xFF60A5FA), name: 'Transferred', value: '$trPct%'),
        ],
      ),
    );
  }

  Widget _buildRecBanner() {
    final recs = (_insights?['recommendations'] as List?) ?? [];
    final total = (_insights?['total_calls'] ?? 0) as num;
    final text = recs.isNotEmpty
        ? (recs.first as String?)
        : 'Add FAQ entries for common questions once patterns emerge from your call logs. With ${total.toInt()} calls recorded, more data will improve resolution rates.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
        ),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: NeyvoTextStyles.body.copyWith(color: const Color(0xFF1E40AF), height: 1.5),
                children: [
                  const TextSpan(text: 'Pulse Insight: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 700;
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildCampaignsCard()),
                if (!narrow) const SizedBox(width: 14),
                if (!narrow) Expanded(child: _buildOperatorWalletCallbacksCard()),
              ],
            ),
            if (narrow) ...[
              const SizedBox(height: 14),
              _buildOperatorWalletCallbacksCard(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCampaignsCard() {
    final running = _campaigns.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'running').length;
    final draft = _campaigns.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'draft').length;
    final completed = _campaigns.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'completed').length;

    return _InsightsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Campaigns', style: NeyvoTextStyles.heading.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${_campaigns.length} total · $running running · $draft draft',
                    style: NeyvoTextStyles.micro.copyWith(color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _campaignStat('$running', 'Running', const Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  _campaignStat('$draft', 'Draft', const Color(0xFF94A3B8)),
                  const SizedBox(width: 10),
                  _campaignStat('$completed', 'Done', const Color(0xFF94A3B8)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CampaignTable(campaigns: _campaigns),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              if (_campaigns.length == 1) {
                _downloadSingleCampaignReport(_campaigns.first['id']?.toString() ?? '');
              } else {
                _showCampaignReportPicker();
              }
            },
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Download campaign report'),
            style: TextButton.styleFrom(
              foregroundColor: NeyvoColors.ubLightBlue,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campaignStat(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: NeyvoTextStyles.heading.copyWith(fontSize: 18, color: color, fontFamily: 'monospace')),
        Text(label.toUpperCase(), style: NeyvoTextStyles.micro.copyWith(letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildOperatorWalletCallbacksCard() {
    final byAgent = (_comms?['by_agent'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final balance = (_wallet?['credits'] ?? 0) as num;
    final plan = _wallet?['subscription_tier']?.toString() ?? '—';
    final voiceTier = _wallet?['voice_tier']?.toString() ?? '—';
    final a = _callbacksAnalytics?['analytics'] as Map? ?? {};
    final scheduled = a['scheduled'] ?? 0;
    final completed = a['completed'] ?? 0;
    final exhausted = a['exhausted'] ?? 0;

    return _InsightsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Per-Operator Performance', style: NeyvoTextStyles.heading.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('30-day period', style: NeyvoTextStyles.micro.copyWith(color: const Color(0xFF94A3B8))),
          const SizedBox(height: 16),
          _AgentPerfTable(agents: byAgent.isEmpty ? [{'name': 'unknown', 'total_calls': _callsForKpi.length, 'resolution_rate': 0, 'avg_duration_seconds': 0, 'credits_used': 0}] : byAgent),
          const SizedBox(height: 16),
          Text('Wallet & Billing', style: NeyvoTextStyles.label),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: NeyvoColors.bgBase,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeyvoColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Balance', style: NeyvoTextStyles.micro),
                      Text('${balance.toInt()}', style: NeyvoTextStyles.heading.copyWith(fontSize: 20, fontFamily: 'monospace')),
                      Text('credits', style: NeyvoTextStyles.micro),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: NeyvoColors.bgBase,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeyvoColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plan', style: NeyvoTextStyles.micro),
                      Text(plan, style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                      Text('~230 cr/mo', style: NeyvoTextStyles.micro),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: NeyvoColors.bgBase,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeyvoColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Voice tier', style: NeyvoTextStyles.micro),
                      Text(voiceTier, style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                      Text('TTS quality', style: NeyvoTextStyles.micro),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Callbacks', style: NeyvoTextStyles.label),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: NeyvoColors.bgBase,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeyvoColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Text('$scheduled', style: NeyvoTextStyles.heading.copyWith(fontSize: 18, fontFamily: 'monospace')),
                      Text('Scheduled', style: NeyvoTextStyles.micro),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: NeyvoColors.bgBase,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeyvoColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Text('$completed', style: NeyvoTextStyles.heading.copyWith(fontSize: 18, fontFamily: 'monospace')),
                      Text('Completed', style: NeyvoTextStyles.micro),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: NeyvoColors.bgBase,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeyvoColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Text('$exhausted', style: NeyvoTextStyles.heading.copyWith(fontSize: 18, fontFamily: 'monospace')),
                      Text('Exhausted', style: NeyvoTextStyles.micro),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

/// White card matching Goodwin reference: border #e4e9f2, radius 12, shadow.
class _InsightsCard extends StatelessWidget {
  final Widget child;

  const _InsightsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E9F2)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}

/// KPI card matching image: white box, thin light grey border, subtle shadow, narrow vertical accent bar on full left edge.
class _GoodwinKpiCard extends StatefulWidget {
  final String label;
  final String value;
  final String? subtitle;
  final String? badge;
  final bool? badgeUp;
  final Color accentColor;

  const _GoodwinKpiCard({
    required this.label,
    required this.value,
    this.subtitle,
    this.badge,
    this.badgeUp,
    required this.accentColor,
  });

  @override
  State<_GoodwinKpiCard> createState() => _GoodwinKpiCardState();
}

class _GoodwinKpiCardState extends State<_GoodwinKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4E9F2), width: 1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.06),
              blurRadius: _hover ? 8 : 6,
              offset: Offset(0, _hover ? 3 : 2),
              spreadRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Narrow solid vertical accent bar along entire left edge (full height)
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label.toUpperCase(),
                        style: NeyvoTextStyles.micro.copyWith(
                          fontSize: 11,
                          letterSpacing: 0.6,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.value,
                        style: NeyvoTextStyles.heading.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          height: 1,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle!,
                          style: NeyvoTextStyles.micro.copyWith(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                      if (widget.badge != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.badgeUp == true
                                ? const Color(0xFFD1FAE5)
                                : widget.badgeUp == false
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.badge!,
                            style: NeyvoTextStyles.micro.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: widget.badgeUp == true
                                  ? const Color(0xFF065F46)
                                  : widget.badgeUp == false
                                      ? const Color(0xFF991B1B)
                                      : const Color(0xFF0369A1),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bar chart: total calls per day (blue bar when > 0, grey dash when 0). Y-axis grid labels 0, 2, 4, 6.
class _CallVolumeBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailyTotals;

  const _CallVolumeBarChart({required this.dailyTotals});

  static const double _barAreaHeight = 148;
  static const double _gridLabelWidth = 28;

  @override
  Widget build(BuildContext context) {
    if (dailyTotals.isEmpty) return const SizedBox.shrink();
    final maxVal = dailyTotals.fold<int>(0, (m, d) {
      final t = (d['total'] as num?)?.toInt() ?? 0;
      return t > m ? t : m;
    });
    final yMax = maxVal < 2 ? 2 : (maxVal <= 6 ? 6 : (maxVal + 2));
    final scale = yMax > 0 ? _barAreaHeight / yMax : 1.0;
    final gridValues = [yMax, (yMax * 2 / 3).round(), (yMax / 3).round(), 0].toSet().toList()..sort((a, b) => b.compareTo(a));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Y-axis labels (aligned to bar area height)
        SizedBox(
          width: _gridLabelWidth,
          height: _barAreaHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: gridValues.map((v) => Text('$v', style: NeyvoTextStyles.micro.copyWith(color: const Color(0xFF94A3B8), fontFamily: 'monospace'))).toList(),
          ),
        ),
        const SizedBox(width: 4),
        // Bars row
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bar area with grid
              SizedBox(
                height: _barAreaHeight,
                child: Stack(
                  children: [
                    // Horizontal dashed grid lines
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(gridValues.length, (_) => Container(height: 1, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE4E9F2)))))),
                    ),
                    // Bars
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: dailyTotals.map((d) {
                        final total = (d['total'] as num?)?.toInt() ?? 0;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: total > 0
                                ? Container(
                                    height: (total * scale).clamp(4.0, _barAreaHeight),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  )
                                : Container(
                                    height: 3,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF94A3B8).withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // X labels (every 5th + last)
              SizedBox(
                height: 18,
                child: Row(
                  children: dailyTotals.asMap().entries.map((entry) {
                    final i = entry.key;
                    final d = entry.value;
                    final showLabel = i % 5 == 0 || i == dailyTotals.length - 1;
                    String dateLabel = '';
                    if (showLabel) {
                      try {
                        dateLabel = DateFormat.MMMd().format(DateTime.parse((d['date'] ?? '').toString().substring(0, 10)));
                      } catch (_) {}
                    }
                    return Expanded(
                      child: Text(
                        showLabel ? dateLabel : '',
                        style: NeyvoTextStyles.micro.copyWith(color: const Color(0xFF94A3B8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Draws a short horizontal dashed line (for legend).
class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _DashedLinePainter({required this.color, this.strokeWidth = 2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    const dashWidth = 4.0;
    const gap = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2), Offset((x + dashWidth).clamp(0.0, size.width), size.height / 2), paint);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Performance Trend: blue bars (Total Calls) + orange dashed line (Resolution Rate %). Dual Y-axes.
class _PerformanceTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> trendData;
  final String tab; // 'calls' | 'both' | 'rate'

  const _PerformanceTrendChart({required this.trendData, required this.tab});

  static const double _chartAreaHeight = 148;
  static const double _leftAxisWidth = 92;
  static const double _rightAxisWidth = 98;

  @override
  Widget build(BuildContext context) {
    if (trendData.isEmpty) return const SizedBox.shrink();
    final maxCalls = trendData.fold<int>(0, (m, d) {
      final t = (d['total'] as num?)?.toInt() ?? 0;
      return t > m ? t : m;
    });
    const yCallsMin = 0;
    final yCallsMax = maxCalls < 2 ? 2 : (maxCalls <= 6 ? 6 : (maxCalls + 2));
    final callsScale = (yCallsMax - yCallsMin) > 0 ? _chartAreaHeight / (yCallsMax - yCallsMin) : 1.0;
    final showBars = tab == 'calls' || tab == 'both';
    final showLine = tab == 'rate' || tab == 'both';
    final gridValuesCalls = [yCallsMax, (yCallsMax * 2 / 3).round(), (yCallsMax / 3).round(), 0].toSet().toList()..sort((a, b) => b.compareTo(a));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Left Y-axis: NUMBER OF CALLS (vertical label on left)
        SizedBox(
          width: _leftAxisWidth,
          height: _chartAreaHeight + 22,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: _chartAreaHeight + 22,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      'NUMBER OF CALLS',
                      style: NeyvoTextStyles.micro.copyWith(color: const Color(0xFF94A3B8), fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (showBars)
                      SizedBox(
                        height: _chartAreaHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: gridValuesCalls.map((v) => Text('$v', style: NeyvoTextStyles.micro.copyWith(color: const Color(0xFF94A3B8), fontFamily: 'monospace'))).toList(),
                        ),
                      )
                    else
                      SizedBox(height: _chartAreaHeight),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // Chart area: bars + line
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _chartAreaHeight,
                child: Stack(
                  children: [
                    // Horizontal dashed grid lines
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(5, (_) => Container(height: 1, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE4E9F2), style: BorderStyle.solid))))),
                    ),
                    // Bars (when calls or both)
                    if (showBars)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: trendData.map((d) {
                          final total = (d['total'] as num?)?.toInt() ?? 0;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: total > 0
                                  ? Container(
                                      height: ((total - yCallsMin) * callsScale).clamp(4.0, _chartAreaHeight),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    )
                                  : Container(
                                      height: 3,
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF94A3B8).withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                            ),
                          );
                        }).toList(),
                      ),
                    // Resolution rate line (orange, dashed)
                    if (showLine && trendData.length >= 2)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final n = trendData.length;
                          final barW = w / n;
                          final pts = <Offset>[];
                          for (var i = 0; i < n; i++) {
                            final rate = (trendData[i]['resolutionRate'] as num?)?.toDouble() ?? 0.0;
                            final y = _chartAreaHeight - (rate / 100.0 * _chartAreaHeight);
                            pts.add(Offset((i + 0.5) * barW, y.clamp(0.0, _chartAreaHeight)));
                          }
                          return CustomPaint(
                            size: Size(w, _chartAreaHeight),
                            painter: _DashedLineChartPainter(pts: pts, color: const Color(0xFFF97316)),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // X-axis date labels (every ~5th + last)
              SizedBox(
                height: 18,
                child: Row(
                  children: trendData.asMap().entries.map((entry) {
                    final i = entry.key;
                    final d = entry.value;
                    final showLabel = i % 5 == 0 || i == trendData.length - 1;
                    String dateLabel = '';
                    if (showLabel) {
                      try {
                        dateLabel = DateFormat.MMMd().format(DateTime.parse((d['date'] ?? '').toString().substring(0, 10)));
                      } catch (_) {}
                    }
                    return Expanded(
                      child: Text(
                        showLabel ? dateLabel : '',
                        style: NeyvoTextStyles.micro.copyWith(color: const Color(0xFF94A3B8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // Right Y-axis: RESOLUTION RATE, % (vertical label on right)
        if (showLine)
          SizedBox(
            width: _rightAxisWidth,
            height: _chartAreaHeight + 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: _chartAreaHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: ['100', '75', '50', '25', '0'].map((v) => Text('$v%', style: NeyvoTextStyles.micro.copyWith(color: const Color(0xFF94A3B8), fontFamily: 'monospace'))).toList(),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 16,
                  height: _chartAreaHeight + 22,
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'RESOLUTION RATE, %',
                        style: NeyvoTextStyles.micro.copyWith(color: const Color(0xFF94A3B8), fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox(width: _rightAxisWidth),
      ],
    );
  }
}

/// Draws dashed polyline through points (for resolution rate line).
class _DashedLineChartPainter extends CustomPainter {
  final List<Offset> pts;
  final Color color;

  _DashedLineChartPainter({required this.pts, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashLength = 6.0;
    const gapLength = 4.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final dx = p1.dx - p0.dx;
      final dy = p1.dy - p0.dy;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 0.01) continue;
      final ux = dx / dist;
      final uy = dy / dist;
      double t = 0;
      bool draw = true;
      while (t < dist) {
        final next = draw ? (t + dashLength).clamp(0.0, dist) : (t + gapLength).clamp(0.0, dist);
        if (draw) {
          canvas.drawLine(
            Offset(p0.dx + ux * t, p0.dy + uy * t),
            Offset(p0.dx + ux * next, p0.dy + uy * next),
            paint,
          );
        }
        t = next.toDouble();
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Donut center + segments (Resolved / Unresolved / No answer / Transferred)
class _DonutOutcomes extends StatelessWidget {
  final int total;
  final double resolvedPct;
  final double unresolvedPct;
  final double noAnswerPct;
  final double transferredPct;

  const _DonutOutcomes({
    required this.total,
    required this.resolvedPct,
    required this.unresolvedPct,
    required this.noAnswerPct,
    required this.transferredPct,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _DonutPainter(
                resolvedPct: resolvedPct,
                unresolvedPct: unresolvedPct,
                noAnswerPct: noAnswerPct,
                transferredPct: transferredPct,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$total', style: NeyvoTextStyles.heading.copyWith(fontSize: 22, fontFamily: 'monospace')),
              Text('calls', style: NeyvoTextStyles.micro),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double resolvedPct;
  final double unresolvedPct;
  final double noAnswerPct;
  final double transferredPct;

  _DonutPainter({
    required this.resolvedPct,
    required this.unresolvedPct,
    required this.noAnswerPct,
    required this.transferredPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 16.0;
    const r = 54.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final total = resolvedPct + unresolvedPct + noAnswerPct + transferredPct;
    if (total <= 0) {
      final paint = Paint()..color = NeyvoColors.borderSubtle..strokeWidth = strokeWidth..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(cx, cy), r, paint);
      return;
    }
    final sweep = 2 * 3.14159265359 * r;
    double start = -3.14159265359 / 2;
    void arc(Color color, double pct) {
      if (pct <= 0) return;
      final paint = Paint()..color = color..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      final dash = (pct / total) * sweep;
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start, dash / r, false, paint);
      start += dash / r;
    }
    arc(NeyvoColors.ubLightBlue, resolvedPct);
    arc(NeyvoColors.error, unresolvedPct);
    arc(NeyvoColors.textMuted, noAnswerPct);
    arc(NeyvoColors.ubLightBlueSoft, transferredPct);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DonutLegendRow extends StatelessWidget {
  final Color color;
  final String name;
  final String value;

  const _DonutLegendRow({required this.color, required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: NeyvoTextStyles.body.copyWith(fontSize: 12, color: NeyvoColors.textSecondary))),
          Text(value, style: NeyvoTextStyles.label.copyWith(fontFamily: 'monospace', color: NeyvoColors.textPrimary)),
        ],
      ),
    );
  }
}

/// Campaigns table with status pills (running / ready / draft / stopped)
class _CampaignTable extends StatelessWidget {
  final List<Map<String, dynamic>> campaigns;

  const _CampaignTable({required this.campaigns});

  static String _statusLabel(String? s) {
    final lower = (s ?? '').toString().toLowerCase();
    if (lower == 'running') return 'Running';
    if (lower == 'ready') return 'Ready';
    if (lower == 'draft') return 'Draft';
    if (lower == 'stopped' || lower == 'completed') return lower == 'stopped' ? 'Stopped' : 'Done';
    return s ?? '—';
  }

  static Color _statusPillColor(String? s) {
    final lower = (s ?? '').toString().toLowerCase();
    if (lower == 'running') return NeyvoColors.success;
    if (lower == 'ready') return const Color(0xFF0EA5E9);
    if (lower == 'draft') return NeyvoColors.textMuted;
    if (lower == 'stopped') return NeyvoColors.error;
    return NeyvoColors.textMuted;
  }

  static Color _statusPillBg(String? s) {
    final lower = (s ?? '').toString().toLowerCase();
    if (lower == 'running') return NeyvoColors.success.withValues(alpha: 0.2);
    if (lower == 'ready') return const Color(0xFFE0F2FE);
    if (lower == 'draft') return NeyvoColors.borderSubtle;
    if (lower == 'stopped') return NeyvoColors.error.withValues(alpha: 0.2);
    return NeyvoColors.borderSubtle;
  }

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(0.8)},
      children: [
        TableRow(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: NeyvoColors.borderSubtle))),
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('NAME', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted, letterSpacing: 0.6))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('STATUS', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted, letterSpacing: 0.6))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('PLANNED', style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted, letterSpacing: 0.6))),
          ],
        ),
        ...campaigns.take(15).map((c) {
          final status = c['status']?.toString();
          final label = _statusLabel(status);
          final bg = _statusPillBg(status);
          final fg = _statusPillColor(status);
          return TableRow(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: NeyvoColors.borderSubtle))),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(c['name']?.toString() ?? '—', style: NeyvoTextStyles.body.copyWith(fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: fg)),
                      const SizedBox(width: 4),
                      Text(label, style: NeyvoTextStyles.micro.copyWith(color: fg, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text('${c['total_planned'] ?? '—'}', style: NeyvoTextStyles.body.copyWith(fontSize: 12, fontFamily: 'monospace')),
              ),
            ],
          );
        }),
      ],
    );
  }
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
