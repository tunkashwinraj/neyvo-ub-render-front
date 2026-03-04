// File: analytics_page.dart
// Neyvo Analytics: Overview (stat cards + line chart), Voice Comms (donut + bar + table), Voice Studio.

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';
import '../widgets/neyvo_empty_state.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _comms;
  Map<String, dynamic>? _studio;
  String _dateRange = '30d'; // Today | 7d | 30d | 90d | Custom

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final o = await NeyvoPulseApi.getAnalyticsOverview();
      final c = await NeyvoPulseApi.getAnalyticsComms();
      final s = await NeyvoPulseApi.getAnalyticsStudio();
      if (mounted) {
        setState(() {
          _overview = o;
          _comms = c;
          _studio = s;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab bar (no Scaffold — we're inside shell)
        Container(
          color: NeyvoColors.bgBase,
          child: TabBar(
            controller: _tabController,
            labelColor: NeyvoColors.teal,
            unselectedLabelColor: NeyvoColors.textMuted,
            indicatorColor: NeyvoColors.teal,
            labelStyle: NeyvoTextStyles.body.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Voice Comms'),
              Tab(text: 'Voice Studio'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? buildNeyvoLoadingState()
              : _error != null
                  ? buildNeyvoErrorState(onRetry: _load)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildCommsTab(),
                        _buildStudioTab(),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    final d = _overview ?? {};
    final creditsConsumed = (d['total_credits_consumed'] ?? d['credits_consumed'] ?? 0) as num;
    final walletCredits = (d['wallet_credits'] ?? d['credits'] ?? 0) as num;
    final totalCalls = (d['total_calls'] ?? d['calls_this_period'] ?? 0) as num;
    final ttsMinutes = (d['total_tts_minutes'] ?? d['tts_minutes'] ?? 0) as num;

    // Build line chart spots from overview or placeholder
    final List<FlSpot> creditsSpots = _creditsBurnedSpots(d);

    final bookingsCreated = (d['bookings_created'] ?? d['bookings'] ?? 0) as num;
    final leadsCaptured = (d['leads_captured'] ?? d['leads'] ?? 0) as num;
    final handoffRate = (d['handoff_rate'] ?? d['handoff_rate_pct'] ?? 0) as num;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Outcomes', style: NeyvoTextStyles.heading),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              int cols = 4;
              if (w < 980) cols = 2;
              if (w < 520) cols = 1;
              final spacing = 16.0;
              final cardW = cols == 1 ? w : (w - spacing * (cols - 1)) / cols;
              final kpiCards = <Widget>[
                _OverviewStatCard(label: 'Total Calls', value: totalCalls.toInt().toString()),
                _OverviewStatCard(label: 'Bookings Created', value: bookingsCreated.toInt().toString()),
                _OverviewStatCard(label: 'Leads Captured', value: leadsCaptured.toInt().toString()),
                _OverviewStatCard(label: 'Handoff Rate', value: '${handoffRate.toStringAsFixed(1)}%'),
              ];
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: kpiCards.map((c) => SizedBox(width: cardW, child: c)).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Usage', style: NeyvoTextStyles.heading),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              int cols = 4;
              if (w < 980) cols = 2;
              if (w < 520) cols = 1;
              final spacing = 24.0;
              final cardW = cols == 1 ? w : (w - spacing * (cols - 1)) / cols;
              final cards = <Widget>[
                _OverviewStatCard(label: 'Credits Consumed', value: creditsConsumed.toInt().toString()),
                _OverviewStatCard(label: 'TTS Minutes', value: ttsMinutes.toStringAsFixed(0)),
                _OverviewStatCard(label: 'Wallet Balance', value: walletCredits.toInt().toString()),
              ];
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: cards.map((c) => SizedBox(width: cardW, child: c)).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          // Row 2: Date range selector
          Row(
            children: [
              _dateChip('Today', 'today'),
              const SizedBox(width: 8),
              _dateChip('7d', '7d'),
              const SizedBox(width: 8),
              _dateChip('30d', '30d'),
              const SizedBox(width: 8),
              _dateChip('90d', '90d'),
              const SizedBox(width: 8),
              _dateChip('Custom', 'custom'),
            ],
          ),
          const SizedBox(height: 24),
          // Row 3: Credits Burned Per Day (Line Chart)
          NeyvoCard(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: 220,
              child: creditsSpots.isEmpty
                  ? Center(
                      child: Text(
                        'Make calls to see usage data',
                        style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
                      ),
                    )
                  : _CreditsLineChart(spots: creditsSpots),
            ),
          ),
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
      onTap: () => setState(() => _dateRange = value),
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

  Widget _buildCommsTab() {
    final d = _comms ?? {};
    final totalCalls = (d['total_calls'] ?? 0) as num;
    final resolved = (d['resolved_count'] ?? d['resolved'] ?? 0) as num;
    final unresolved = (d['unresolved_count'] ?? d['unresolved'] ?? 0) as num;
    final noAnswer = (d['no_answer_count'] ?? d['no_answer'] ?? 0) as num;
    final transferred = (d['transferred_count'] ?? d['transferred'] ?? 0) as num;
    final agents = (d['by_agent'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final callsPerDay = (d['calls_per_day'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Call Outcomes Donut
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
                  children: [
                    chart,
                    const SizedBox(height: 16),
                    legend,
                  ],
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
          const SizedBox(height: 24),
          // Calls Per Day Bar Chart
          NeyvoCard(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: 200,
              child: callsPerDay.isEmpty
                  ? Center(
                      child: Text(
                        'Create operators and make calls to see data.',
                        style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
                      ),
                    )
                  : _CallsBarChart(callsPerDay: callsPerDay),
            ),
          ),
          const SizedBox(height: 24),
          Text('Per-Agent Performance', style: NeyvoTextStyles.heading),
          const SizedBox(height: 12),
          NeyvoCard(
            padding: EdgeInsets.zero,
            child: agents.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Create operators and make calls to see performance data.',
                        style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
                      ),
                    ),
                  )
                : _AgentPerfTable(agents: agents),
          ),
        ],
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

  Widget _buildStudioTab() {
    final d = _studio ?? {};
    final totalGens = (d['total_generations'] ?? 0) as num;
    final totalMinutes = (d['total_audio_minutes'] ?? 0) as num;
    final projects = (d['by_project'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalGens == 0 && totalMinutes == 0 && projects.isEmpty)
            NeyvoCard(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.mic_none_outlined, size: 48, color: NeyvoColors.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'Enable Voice Studio to see studio analytics.',
                      style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(child: _OverviewStatCard(label: 'TTS Generations', value: totalGens.toString())),
                const SizedBox(width: 24),
                Expanded(child: _OverviewStatCard(label: 'Audio Minutes', value: totalMinutes.toStringAsFixed(1))),
              ],
            ),
            const SizedBox(height: 24),
            if (projects.isNotEmpty) ...[
              Text('By Project', style: NeyvoTextStyles.heading),
              const SizedBox(height: 12),
              NeyvoCard(
                padding: EdgeInsets.zero,
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                  },
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

class _CallsBarChart extends StatelessWidget {
  final List<dynamic> callsPerDay;

  const _CallsBarChart({required this.callsPerDay});

  @override
  Widget build(BuildContext context) {
    final maxY = callsPerDay.isEmpty ? 2.0 : (callsPerDay.map((e) => (e is num ? e : 0).toDouble()).reduce((a, b) => a > b ? a : b) + 2);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY.toDouble(),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: NeyvoTextStyles.micro),
              reservedSize: 24,
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
        barGroups: callsPerDay.asMap().entries.map((e) {
          final v = e.value is num ? (e.value as num).toDouble() : 0.0;
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
              getTitlesWidget: (v, _) => Text('Day ${v.toInt()}', style: NeyvoTextStyles.micro),
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
