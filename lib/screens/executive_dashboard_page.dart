// Executive Dashboard – call center KPIs for staging sites.
// ASA = Average Speed of Answer, AHT = Average Handled Time (both in seconds).

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';

class ExecutiveDashboardPage extends StatefulWidget {
  const ExecutiveDashboardPage({super.key});

  @override
  State<ExecutiveDashboardPage> createState() => _ExecutiveDashboardPageState();
}

class _ExecutiveDashboardPageState extends State<ExecutiveDashboardPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _departments = [];
  int _selectedYear = DateTime.now().year;
  List<int> _selectedMonths = [DateTime.now().month];
  List<String> _selectedDepartments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _fromDate {
    if (_selectedMonths.isEmpty) return '';
    final m = _selectedMonths.reduce((a, b) => a < b ? a : b);
    return '$_selectedYear-${m.toString().padLeft(2, '0')}-01';
  }

  String get _toDate {
    if (_selectedMonths.isEmpty) return '';
    final m = _selectedMonths.reduce((a, b) => a > b ? a : b);
    final lastDay = DateTime(_selectedYear, m + 1, 0).day;
    return '$_selectedYear-${m.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final from = _fromDate;
      final to = _toDate;
      final results = await Future.wait([
        NeyvoPulseApi.getKpiOverview(from: from.isEmpty ? null : from, to: to.isEmpty ? null : to),
        NeyvoPulseApi.getKpiDepartmentSummary(from: from.isEmpty ? null : from, to: to.isEmpty ? null : to),
      ]);
      if (!mounted) return;
      final ov = results[0] as Map<String, dynamic>;
      final deptRes = results[1] as Map<String, dynamic>;
      setState(() {
        _overview = ov['ok'] == true ? ov : null;
        _departments = (deptRes['departments'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ?? [];
        _loading = false;
        _error = ov['ok'] != true ? (ov['error'] ?? 'Failed to load') : null;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeyvoColors.bgBase,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTabs(),
                  const SizedBox(height: 20),
                  if (_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
                  else if (_error != null)
                    Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, style: TextStyle(color: NeyvoTheme.error)),
                    ))
                  else
                    _buildContent(),
                ],
              ),
            ),
          ),
          _buildFiltersPanel(),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    const tabs = ['Executive Dashboard', 'Department Performance', 'Team Performance', 'Weekly Performance'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {},
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

  Widget _buildFiltersPanel() {
    final deptNames = _departments.map((d) => d['department_name'] as String? ?? '').where((s) => s.isNotEmpty).toSet().toList()..sort();
    if (deptNames.isEmpty) deptNames.addAll(['Air Conditioner', 'Fridge', 'Microwave Oven', 'Television', 'Toaster', 'Washing Machine']);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised,
        border: Border(left: BorderSide(color: NeyvoTheme.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filters', style: NeyvoTextStyles.heading),
          const SizedBox(height: 16),
          Text('Year', style: NeyvoTextStyles.label),
          const SizedBox(height: 4),
          DropdownButton<int>(
            value: _selectedYear,
            isExpanded: true,
            items: [for (int y = DateTime.now().year; y >= DateTime.now().year - 5; y--) DropdownMenuItem(value: y, child: Text('$y'))],
            onChanged: (v) => setState(() { _selectedYear = v ?? DateTime.now().year; _load(); }),
          ),
          const SizedBox(height: 16),
          Text('Month', style: NeyvoTextStyles.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(12, (i) {
              final m = i + 1;
              final selected = _selectedMonths.contains(m);
              return FilterChip(
                label: Text(DateFormat('MMM').format(DateTime(2023, m)), style: const TextStyle(fontSize: 11)),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) _selectedMonths = [..._selectedMonths, m]..sort();
                    else _selectedMonths = _selectedMonths.where((x) => x != m).toList();
                    _load();
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          Text('Department', style: NeyvoTextStyles.label),
          const SizedBox(height: 8),
          ...deptNames.take(10).map((name) {
            final selected = _selectedDepartments.isEmpty || _selectedDepartments.contains(name);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: CheckboxListTile(
                value: selected,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text(name, style: NeyvoTextStyles.micro),
                onChanged: (v) {
                  setState(() {
                    if (v == true) _selectedDepartments = [..._selectedDepartments, name];
                    else _selectedDepartments = _selectedDepartments.where((x) => x != name).toList();
                    _load();
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final o = _overview ?? {};
    final totalCalls = (o['total_calls'] as num?)?.toInt() ?? 0;
    final callsAnswered = (o['calls_answered'] as num?)?.toInt() ?? 0;
    final abandonRate = (o['abandon_rate_pct'] as num?)?.toDouble() ?? 0.0;
    final asaSec = (o['asa_sec'] as num?)?.toInt() ?? 0;
    final ahtSec = (o['aht_sec'] as num?)?.toInt() ?? 0;
    final callsResolved = (o['calls_resolved'] as num?)?.toInt() ?? 0;
    final resolutionPct = (o['resolution_rate_pct'] as num?)?.toDouble() ?? 0.0;
    final npsScore = (o['nps_score'] as num?)?.toDouble() ?? 0.0;
    final avgCsat = (o['avg_csat'] as num?)?.toDouble() ?? 0.0;
    final pctPromoters = (o['pct_promoters'] as num?)?.toDouble() ?? 0.0;
    final pctDetractors = (o['pct_detractors'] as num?)?.toDouble() ?? 0.0;
    final pctPassives = (o['pct_passives'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKpiRow(
          totalCalls: totalCalls,
          callsAnswered: callsAnswered,
          abandonRate: abandonRate,
          asaSec: asaSec,
          ahtSec: ahtSec,
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildNpsSection(npsScore, pctPromoters, pctPassives, pctDetractors)),
            const SizedBox(width: 16),
            Expanded(child: _buildCallResolutions(totalCalls, callsAnswered, callsResolved, resolutionPct)),
            const SizedBox(width: 16),
            Expanded(child: _buildCsatSection(avgCsat)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildNpsByDept()),
            const SizedBox(width: 16),
            Expanded(child: _buildCallsHandledResolutionByDept()),
            const SizedBox(width: 16),
            Expanded(child: _buildAbandonRateByDept()),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiRow({
    required int totalCalls,
    required int callsAnswered,
    required double abandonRate,
    required int asaSec,
    required int ahtSec,
  }) {
    final cards = [
      _KpiCard(title: 'Total Calls', value: NumberFormat('#,###').format(totalCalls), icon: Icons.phone_outlined, color: const Color(0xFFE6A800)),
      _KpiCard(title: 'Calls Answered', value: NumberFormat('#,###').format(callsAnswered), icon: Icons.phone_callback_outlined, color: const Color(0xFF7B4FA8)),
      _KpiCard(title: 'Abandon Rate', value: '${abandonRate.toStringAsFixed(1)}%', icon: Icons.phone_disabled_outlined, color: const Color(0xFFE91E8C)),
      _KpiCard(
        title: 'ASA (Sec)',
        value: '$asaSec',
        icon: Icons.timer_outlined,
        color: const Color(0xFF4CAF50),
        subtitle: 'Average Speed of Answer',
      ),
      _KpiCard(
        title: 'AHT (Sec)',
        value: '$ahtSec',
        icon: Icons.schedule_outlined,
        color: const Color(0xFFFF9800),
        subtitle: 'Average Handled Time',
      ),
    ];
    return Row(
      children: cards.map((c) => Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: c,
      ))).toList(),
    );
  }

  Widget _buildNpsSection(double npsScore, double pctPromoters, double pctPassives, double pctDetractors) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Net Promoter Score', style: NeyvoTextStyles.heading),
            const SizedBox(height: 12),
            _SemiGauge(value: npsScore, min: -100, max: 100),
            const SizedBox(height: 8),
            Text(npsScore.toStringAsFixed(1), style: NeyvoTextStyles.display.copyWith(fontSize: 24)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StackedBarSegment(label: '% Detractors', pct: pctDetractors, color: Colors.red)),
                const SizedBox(width: 4),
                Expanded(child: _StackedBarSegment(label: '% Passives', pct: pctPassives, color: Colors.orange)),
                const SizedBox(width: 4),
                Expanded(child: _StackedBarSegment(label: '% Promoters', pct: pctPromoters, color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallResolutions(int totalCalls, int callsAnswered, int callsResolved, double resolutionPct) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call Resolutions %', style: NeyvoTextStyles.heading),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ResolutionBar(label: 'Call Received', value: totalCalls, color: const Color(0xFFE6A800)),
                      _ResolutionBar(label: 'Call Answered', value: callsAnswered, total: totalCalls, color: const Color(0xFF7B4FA8)),
                      _ResolutionBar(label: 'Call Resolutions', value: callsResolved, total: totalCalls, color: const Color(0xFF5E35B1)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 24,
                      sections: [
                        PieChartSectionData(value: resolutionPct, color: NeyvoColors.ubLightBlue, showTitle: false),
                        PieChartSectionData(value: 100 - resolutionPct, color: Colors.grey.shade300, showTitle: false),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${resolutionPct.toStringAsFixed(1)}% resolution', style: NeyvoTextStyles.label),
          ],
        ),
      ),
    );
  }

  Widget _buildCsatSection(double avgCsat) {
    final depts = _departments.take(6).toList();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer Satisfaction Score', style: NeyvoTextStyles.heading),
            const SizedBox(height: 12),
            _SemiGauge(value: avgCsat, min: 1, max: 5),
            Text(avgCsat.toStringAsFixed(1), style: NeyvoTextStyles.display.copyWith(fontSize: 24)),
            const SizedBox(height: 16),
            if (depts.isNotEmpty) ...[
              Text('By department', style: NeyvoTextStyles.label),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 5.5,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) => Text(
                          depts.length > v.toInt() ? (depts[v.toInt()]['department_name'] as String? ?? '').replaceAll(' ', '\n') : '',
                          style: const TextStyle(fontSize: 9),
                        ),
                      )),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(depts.length, (i) {
                      final v = (depts[i]['avg_csat'] as num?)?.toDouble() ?? 0.0;
                      return BarChartGroupData(x: i, barRods: [
                        BarChartRodData(toY: v, color: NeyvoColors.ubLightBlue, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                      ], showingTooltipIndicators: []);
                    }),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNpsByDept() {
    final depts = _departments.take(8).toList();
    if (depts.isEmpty) return _emptyChartCard('NPS By Department');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NPS By Department', style: NeyvoTextStyles.heading),
            const SizedBox(height: 12),
            SizedBox(
              height: 40.0 * depts.length,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  minY: -100,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) => Text(
                        depts.length > v.toInt() ? (depts[v.toInt()]['department_name'] as String? ?? '') : '',
                        style: const TextStyle(fontSize: 10),
                      ),
                    )),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(depts.length, (i) {
                    final v = (depts[i]['nps_score'] as num?)?.toDouble() ?? 0.0;
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(toY: v, color: NeyvoColors.ubLightBlue, width: 20, borderRadius: const BorderRadius.horizontal(right: Radius.circular(4))),
                    ], showingTooltipIndicators: []);
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallsHandledResolutionByDept() {
    final depts = _departments.take(8).toList();
    if (depts.isEmpty) return _emptyChartCard('Calls Handled & Resolution %');
    final maxCalls = depts.fold<int>(0, (m, d) {
      final v = (d['calls_answered'] as num?)?.toInt() ?? 0;
      return v > m ? v : m;
    });
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calls Handled & Resolution % By Department', style: NeyvoTextStyles.heading),
            const SizedBox(height: 12),
            SizedBox(
              height: 40.0 * depts.length,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxCalls * 1.2).toDouble(),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) => Text(
                        depts.length > v.toInt() ? (depts[v.toInt()]['department_name'] as String? ?? '') : '',
                        style: const TextStyle(fontSize: 10),
                      ),
                    )),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(depts.length, (i) {
                    final ca = (depts[i]['calls_answered'] as num?)?.toInt() ?? 0;
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(toY: ca.toDouble(), color: NeyvoColors.ubLightBlue, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                    ], showingTooltipIndicators: []);
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: depts.map((d) => Text('${d['department_name']}: ${(d['resolution_rate_pct'] as num?)?.toStringAsFixed(1) ?? '0'}%', style: NeyvoTextStyles.micro)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbandonRateByDept() {
    final depts = _departments.take(8).toList();
    if (depts.isEmpty) return _emptyChartCard('Call Abandon Rate By Department');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call Abandon Rate By Department', style: NeyvoTextStyles.heading),
            const SizedBox(height: 12),
            SizedBox(
              height: 40.0 * depts.length,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 15,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) => Text(
                        depts.length > v.toInt() ? (depts[v.toInt()]['department_name'] as String? ?? '') : '',
                        style: const TextStyle(fontSize: 10),
                      ),
                    )),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(depts.length, (i) {
                    final v = (depts[i]['abandon_rate_pct'] as num?)?.toDouble() ?? 0.0;
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(toY: v, color: v > 10 ? Colors.red : Colors.orange, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                    ], showingTooltipIndicators: []);
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyChartCard(String title) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: NeyvoTextStyles.heading),
            const SizedBox(height: 12),
            Text('No department data for selected filters.', style: NeyvoTextStyles.label),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _KpiCard({required this.title, required this.value, required this.icon, required this.color, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: subtitle ?? title,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.borderSubtle)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 8),
                  Text(title, style: NeyvoTextStyles.label),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: NeyvoTextStyles.title.copyWith(fontSize: 22)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SemiGauge extends StatelessWidget {
  final double value;
  final double min;
  final double max;

  const _SemiGauge({required this.value, required this.min, required this.max});

  @override
  Widget build(BuildContext context) {
    final pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
    Color needleColor = Colors.grey;
    if (value >= 50) needleColor = Colors.green;
    else if (value > 0) needleColor = Colors.orange;
    else needleColor = Colors.red;
    return SizedBox(
      height: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      colors: [Colors.red, Colors.grey, Colors.green],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Positioned(
                            left: constraints.maxWidth * pct - 2,
                            top: -4,
                            child: Container(
                              width: 4,
                              height: 20,
                              decoration: BoxDecoration(
                                color: needleColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StackedBarSegment extends StatelessWidget {
  final String label;
  final double pct;
  final Color color;

  const _StackedBarSegment({required this.label, required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: NeyvoTextStyles.micro),
        const SizedBox(height: 2),
        SizedBox(
          height: 8,
          child: LinearProgressIndicator(value: pct / 100, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(color)),
        ),
        Text('${pct.toStringAsFixed(1)}%', style: NeyvoTextStyles.micro),
      ],
    );
  }
}

class _ResolutionBar extends StatelessWidget {
  final String label;
  final int value;
  final int? total;
  final Color color;

  const _ResolutionBar({required this.label, required this.value, this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = total ?? value;
    final pct = t > 0 ? (value / t) * 100 : 0.0;
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
                flex: 1,
                child: SizedBox(
                  height: 20,
                  child: LinearProgressIndicator(
                    value: t > 0 ? (value / t) : 0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${NumberFormat('#,###').format(value)}${t != value ? ', ${pct.toStringAsFixed(1)}%' : ''}', style: NeyvoTextStyles.micro),
            ],
          ),
        ],
      ),
    );
  }
}
