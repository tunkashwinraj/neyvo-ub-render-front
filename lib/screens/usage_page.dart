// lib/screens/usage_page.dart
// Usage analytics: date range, summary cards, daily chart, tier breakdown, per-call log.

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../theme/spearia_theme.dart';

class UsagePage extends StatefulWidget {
  const UsagePage({super.key});

  @override
  State<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  String _range = '30'; // 7, 30, 90 or custom
  Map<String, dynamic>? _usage;
  List<dynamic>? _callLog;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  (String, String) _dateRange() {
    final now = DateTime.now();
    final end = now;
    DateTime start;
    switch (_range) {
      case '7':
        start = end.subtract(const Duration(days: 7));
        break;
      case '90':
        start = end.subtract(const Duration(days: 90));
        break;
      default:
        start = end.subtract(const Duration(days: 30));
    }
    final from = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final to = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    return (from, to);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final (from, to) = _dateRange();
    try {
      final usage = await NeyvoPulseApi.getBillingUsage(from: from, to: to);
      List<dynamic> calls = [];
      try {
        final res = await NeyvoPulseApi.listCalls();
        calls = res['calls'] as List? ?? [];
      } catch (_) {}
      if (mounted) {
        setState(() {
          _usage = usage;
          _callLog = calls;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _usage == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading usage…', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final totalCalls = (_usage?['total_calls'] as num?)?.toInt() ?? 0;
    final totalMinutes = (_usage?['total_minutes'] as num?)?.toDouble() ?? 0.0;
    final totalCredits = (_usage?['total_credits_used'] as num?)?.toInt() ?? 0;
    final totalDollars = (_usage?['total_dollars_spent'] as num?)?.toDouble() ?? 0.0;
    final daily = _usage?['daily_breakdown'] as List? ?? [];
    final byTier = _usage?['by_tier'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date range
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '7', label: Text('Last 7 days')),
              ButtonSegment(value: '30', label: Text('Last 30 days')),
              ButtonSegment(value: '90', label: Text('Last 90 days')),
            ],
            selected: {_range},
            onSelectionChanged: (s) {
              setState(() {
                _range = s.isNotEmpty ? s.first : '30';
                _load();
              });
            },
          ),
          const SizedBox(height: 24),
          // Summary cards
          Row(
            children: [
              Expanded(child: _summaryCard('Total calls', '$totalCalls')),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard('Minutes', totalMinutes.toStringAsFixed(1))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _summaryCard('Credits used', '$totalCredits')),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard('Spent', '\$${totalDollars.toStringAsFixed(2)}')),
            ],
          ),
          const SizedBox(height: 24),
          // Daily breakdown (simple bars)
          Text('Daily usage', style: SpeariaType.titleMedium),
          const SizedBox(height: 8),
          if (daily.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
              child: const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No usage in this range'))),
            )
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: daily.map<Widget>((d) {
                    final date = d['date'] as String? ?? '';
                    final credits = (d['credits'] as num?)?.toInt() ?? 0;
                    final calls = (d['calls'] as num?)?.toInt() ?? 0;
                    final maxCredits = daily.fold<int>(0, (m, x) => ((x['credits'] as num?)?.toInt() ?? 0) > m ? (x['credits'] as num?)?.toInt() ?? 0 : m);
                    final width = maxCredits > 0 ? (credits / maxCredits).clamp(0.0, 1.0) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(width: 90, child: Text(date, style: SpeariaType.bodySmall)),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: width,
                              backgroundColor: SpeariaAura.border,
                              valueColor: AlwaysStoppedAnimation<Color>(SpeariaAura.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$credits cr', style: SpeariaType.bodySmall),
                          const SizedBox(width: 8),
                          Text('$calls calls', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 24),
          // Tier breakdown
          Text('By tier', style: SpeariaType.titleMedium),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: byTier.isEmpty
                  ? const Center(child: Text('No tier breakdown'))
                  : Column(
                      children: (byTier.entries.map((e) {
                        final tier = e.key;
                        final data = e.value is Map ? e.value as Map<String, dynamic> : <String, dynamic>{};
                        final calls = (data['calls'] as num?)?.toInt() ?? 0;
                        final credits = (data['credits'] as num?)?.toInt() ?? 0;
                        return ListTile(
                          title: Text(tier, style: SpeariaType.bodyMedium),
                          trailing: Text('$calls calls, $credits credits', style: SpeariaType.bodySmall),
                        );
                      })).toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: SpeariaType.titleLarge.copyWith(fontWeight: FontWeight.w600)),
            Text(label, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
          ],
        ),
      ),
    );
  }
}
