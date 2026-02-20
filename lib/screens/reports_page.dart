// lib/screens/reports_page.dart
// Enhanced reports page with comprehensive analytics and insights

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../utils/export_csv.dart';
import '../../theme/spearia_theme.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  Map<String, dynamic>? _summary;
  List<dynamic> _students = [];
  List<dynamic> _payments = [];
  List<dynamic> _calls = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final reports = await NeyvoPulseApi.reportsSummary();
      final students = await NeyvoPulseApi.listStudents();
      final payments = await NeyvoPulseApi.listPayments();
      final calls = await NeyvoPulseApi.listCalls();
      
      if (mounted) setState(() {
        _summary = reports['summary'] as Map<String, dynamic>? ?? {};
        _students = students['students'] as List? ?? [];
        _payments = payments['payments'] as List? ?? [];
        _calls = calls['calls'] as List? ?? [];
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  double _calculateTotalPayments() {
    double total = 0.0;
    for (final payment in _payments) {
      final amountStr = payment['amount']?.toString() ?? '';
      if (amountStr.isNotEmpty) {
        final amount = double.tryParse(amountStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
        total += amount;
      }
    }
    return total;
  }

  int _getCompletedCalls() {
    return _calls.where((c) {
      final status = (c['status']?.toString() ?? '').toLowerCase();
      return status == 'completed' || status == 'success';
    }).length;
  }

  int _getOverdueStudents() {
    return _students.where((s) {
      final dueDate = s['due_date']?.toString() ?? '';
      return dueDate.isNotEmpty;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reports')),
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
    
    final totalStudents = _students.length;
    final totalBalance = (_summary?['total_balance'] as num?)?.toDouble() ?? 0.0;
    final totalPayments = _calculateTotalPayments();
    final overdueCount = _getOverdueStudents();
    final completedCalls = _getCompletedCalls();
    final totalCalls = _calls.length;
    final callSuccessRate = totalCalls > 0 ? (completedCalls / totalCalls * 100) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportReport(
              totalStudents: totalStudents,
              totalBalance: totalBalance,
              totalPayments: totalPayments,
              overdueCount: overdueCount,
              completedCalls: completedCalls,
              totalCalls: totalCalls,
              callSuccessRate: callSuccessRate,
            ),
            tooltip: 'Export report CSV',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(SpeariaSpacing.lg),
          children: [
          Text('Reports & Analytics', style: SpeariaType.headlineLarge),
          const SizedBox(height: SpeariaSpacing.sm),
          Text(
            'Financial insights and performance metrics',
            style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
          ),
          const SizedBox(height: SpeariaSpacing.xl),
          
          // Key Metrics
          Text('Key Metrics', style: SpeariaType.titleLarge),
          const SizedBox(height: SpeariaSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  'Total Students',
                  '$totalStudents',
                  Icons.school_outlined,
                  SpeariaAura.primary,
                ),
              ),
              const SizedBox(width: SpeariaSpacing.md),
              Expanded(
                child: _StatCard(
                  'Total Balance',
                  '\$${totalBalance.toStringAsFixed(0)}',
                  Icons.account_balance_wallet_outlined,
                  SpeariaAura.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpeariaSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  'Total Payments',
                  '\$${totalPayments.toStringAsFixed(2)}',
                  Icons.payment_outlined,
                  SpeariaAura.success,
                ),
              ),
              const SizedBox(width: SpeariaSpacing.md),
              Expanded(
                child: _StatCard(
                  'Overdue',
                  '$overdueCount',
                  Icons.warning_amber_outlined,
                  SpeariaAura.warning,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: SpeariaSpacing.xl),
          
          // Call Performance
          Text('Call Performance', style: SpeariaType.titleLarge),
          const SizedBox(height: SpeariaSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SpeariaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Calls', style: SpeariaType.titleMedium),
                      Text('$totalCalls', style: SpeariaType.headlineMedium.copyWith(color: SpeariaAura.primary)),
                    ],
                  ),
                  const SizedBox(height: SpeariaSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Completed', style: SpeariaType.bodyMedium),
                      Text('$completedCalls', style: SpeariaType.titleMedium.copyWith(color: SpeariaAura.success)),
                    ],
                  ),
                  const SizedBox(height: SpeariaSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Success Rate', style: SpeariaType.bodyMedium),
                      Text(
                        '${callSuccessRate.toStringAsFixed(1)}%',
                        style: SpeariaType.titleMedium.copyWith(color: SpeariaAura.info),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpeariaSpacing.md),
                  LinearProgressIndicator(
                    value: callSuccessRate / 100,
                    backgroundColor: SpeariaAura.bgDark,
                    valueColor: AlwaysStoppedAnimation<Color>(SpeariaAura.success),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: SpeariaSpacing.xl),
          
          // Financial Summary
          Text('Financial Summary', style: SpeariaType.titleLarge),
          const SizedBox(height: SpeariaSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SpeariaSpacing.lg),
              child: Column(
                children: [
                  _InfoRow('Outstanding Balance', '\$${totalBalance.toStringAsFixed(2)}', SpeariaAura.accent),
                  const Divider(),
                  _InfoRow('Total Collected', '\$${totalPayments.toStringAsFixed(2)}', SpeariaAura.success),
                  const Divider(),
                  _InfoRow('Collection Rate', totalBalance > 0 
                      ? '${(totalPayments / (totalBalance + totalPayments) * 100).toStringAsFixed(1)}%'
                      : 'N/A', SpeariaAura.info),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: SpeariaSpacing.xl),
          
          // Payment Methods Breakdown
          if (_payments.isNotEmpty) ...[
            Text('Payment Methods', style: SpeariaType.titleLarge),
            const SizedBox(height: SpeariaSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SpeariaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildPaymentMethodBreakdown(),
                ),
              ),
            ),
            const SizedBox(height: SpeariaSpacing.xl),
          ],
          
          // Quick Actions
          Text('Quick Actions', style: SpeariaType.titleLarge),
          const SizedBox(height: SpeariaSpacing.md),
          OutlinedButton.icon(
            onPressed: () => _exportReport(
              totalStudents: totalStudents,
              totalBalance: totalBalance,
              totalPayments: totalPayments,
              overdueCount: overdueCount,
              completedCalls: completedCalls,
              totalCalls: totalCalls,
              callSuccessRate: callSuccessRate,
            ),
            icon: const Icon(Icons.download),
            label: const Text('Export Report CSV'),
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _exportReport({
    required int totalStudents,
    required double totalBalance,
    required double totalPayments,
    required int overdueCount,
    required int completedCalls,
    required int totalCalls,
    required double callSuccessRate,
  }) async {
    final sb = StringBuffer();
    sb.writeln('Report,Metric,Value');
    sb.writeln('Key Metrics,Total Students,$totalStudents');
    sb.writeln('Key Metrics,Total Balance,\$${totalBalance.toStringAsFixed(2)}');
    sb.writeln('Key Metrics,Total Payments,\$${totalPayments.toStringAsFixed(2)}');
    sb.writeln('Key Metrics,Overdue Count,$overdueCount');
    sb.writeln('Call Performance,Total Calls,$totalCalls');
    sb.writeln('Call Performance,Completed,$completedCalls');
    sb.writeln('Call Performance,Success Rate %,${callSuccessRate.toStringAsFixed(1)}');
    sb.writeln('Financial,Outstanding Balance,\$${totalBalance.toStringAsFixed(2)}');
    sb.writeln('Financial,Total Collected,\$${totalPayments.toStringAsFixed(2)}');
    final methodCounts = <String, int>{};
    for (final p in _payments) {
      final method = p['method']?.toString() ?? 'Unknown';
      methodCounts[method] = (methodCounts[method] ?? 0) + 1;
    }
    for (final e in methodCounts.entries) {
      final pct = _payments.isEmpty ? 0.0 : (e.value / _payments.length * 100);
      sb.writeln('Payment Methods,${e.key},${e.value} (${pct.toStringAsFixed(1)}%)');
    }
    final filename = 'reports_${DateTime.now().toIso8601String().split('T').first}.csv';
    await downloadCsv(filename, sb.toString(), context);
  }

  List<Widget> _buildPaymentMethodBreakdown() {
    final methodCounts = <String, int>{};
    for (final payment in _payments) {
      final method = payment['method']?.toString() ?? 'Unknown';
      methodCounts[method] = (methodCounts[method] ?? 0) + 1;
    }
    
    if (methodCounts.isEmpty) {
      return [
        Text(
          'No payment methods data available',
          style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted),
        ),
      ];
    }
    
    return methodCounts.entries.map((entry) {
      final percentage = (_payments.length > 0) ? (entry.value / _payments.length * 100) : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: SpeariaSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(entry.key, style: SpeariaType.bodyMedium),
            Row(
              children: [
                Text('${entry.value} (${percentage.toStringAsFixed(1)}%)', 
                    style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary)),
                const SizedBox(width: SpeariaSpacing.sm),
                SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: SpeariaAura.bgDark,
                    valueColor: AlwaysStoppedAnimation<Color>(SpeariaAura.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpeariaSpacing.lg),
      decoration: SpeariaFX.statCard(accentColor: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: SpeariaType.headlineMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpeariaSpacing.sm),
          Text(
            label,
            style: SpeariaType.bodySmall.copyWith(
              color: SpeariaAura.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpeariaSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary)),
          Text(value, style: SpeariaType.titleMedium.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
