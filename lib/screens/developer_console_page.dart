// lib/screens/developer_console_page.dart
// Developer Console: platform overview, tier configs (admin/developer only).

import 'package:flutter/material.dart';
import '../api/spearia_api.dart';
import '../theme/spearia_theme.dart';

class DeveloperConsolePage extends StatefulWidget {
  const DeveloperConsolePage({super.key});

  @override
  State<DeveloperConsolePage> createState() => _DeveloperConsolePageState();
}

class _DeveloperConsolePageState extends State<DeveloperConsolePage> {
  Map<String, dynamic>? _overview;
  List<dynamic>? _tierConfigs;
  Map<String, dynamic>? _numbersStats;
  List<dynamic>? _warmUpNumbers;
  Map<String, dynamic>? _dailyResetLog;
  Map<String, dynamic>? _systemHealth;
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await SpeariaApi.getJsonMap('/api/admin/billing-overview', adminAuth: true);
      final configsRes = await SpeariaApi.getJsonMap('/api/admin/tier-configs', adminAuth: true);
      final configs = configsRes['tier_configs'] as List? ?? [];
      Map<String, dynamic>? numbersStats;
      List<dynamic>? warmUpNumbers;
      Map<String, dynamic>? dailyResetLog;
      try {
        numbersStats = await SpeariaApi.getJsonMap('/api/admin/numbers/stats', adminAuth: true);
        final warmRes = await SpeariaApi.getJsonMap('/api/admin/numbers/warm-up', adminAuth: true);
        warmUpNumbers = warmRes['numbers'] as List? ?? [];
        dailyResetLog = await SpeariaApi.getJsonMap('/api/admin/numbers/daily-reset', adminAuth: true);
      } catch (_) {}
      Map<String, dynamic>? systemHealth;
      try {
        systemHealth = await SpeariaApi.getJsonMap('/api/admin/system-health', adminAuth: true);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _overview = overview;
          _tierConfigs = configs;
          _numbersStats = numbersStats;
          _warmUpNumbers = warmUpNumbers;
          _dailyResetLog = dailyResetLog;
          _systemHealth = systemHealth;
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
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _overview == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading…', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
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

    final orgs = (_overview?['total_organizations'] as num?)?.toInt() ?? 0;
    final callsToday = (_overview?['total_calls_today'] as num?)?.toInt() ?? 0;
    final revenueToday = (_overview?['total_revenue_today'] as num?)?.toDouble() ?? 0.0;
    final revenueMtd = (_overview?['total_revenue_mtd'] as num?)?.toDouble() ?? 0.0;
    final costToday = (_overview?['total_cost_today'] as num?)?.toDouble() ?? 0.0;
    final marginPct = (_overview?['platform_margin_pct'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Banner(
            message: 'Changes apply immediately to all new calls.',
            location: BannerLocation.topEnd,
            color: SpeariaAura.warning,
          ),
          const SizedBox(height: 16),
          Text('Revenue Control Center', style: SpeariaType.headlineMedium),
          const SizedBox(height: 8),
          Text('Platform overview', style: SpeariaType.titleLarge),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  _stat('Organizations', '$orgs'),
                  _stat('Calls today', '$callsToday'),
                  _stat('Revenue today', '\$${revenueToday.toStringAsFixed(2)}'),
                  _stat('Revenue MTD', '\$${revenueMtd.toStringAsFixed(2)}'),
                  _stat('Cost today', '\$${costToday.toStringAsFixed(2)}'),
                  _stat('Platform margin %', '${marginPct.toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ),
          if (_systemHealth != null) ...[
            const SizedBox(height: 24),
            Text('System health', style: SpeariaType.titleLarge),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _stat('Orgs below 500 credits', '${_systemHealth!['orgs_below_500_credits'] ?? 0}'),
                        _stat('Billing errors today', '${_systemHealth!['billing_errors_today'] ?? 0}'),
                        _stat('Calls missing billing', '${_systemHealth!['calls_missing_billing_record'] ?? 0}'),
                        if (_systemHealth!['avg_assistant_request_ms_last_20'] != null)
                          _stat('Avg assistant-request ms', '${_systemHealth!['avg_assistant_request_ms_last_20']}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Environment (set/not set only)', style: SpeariaType.labelMedium.copyWith(color: SpeariaAura.textMuted)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: (_systemHealth!['env_vars'] as Map<String, dynamic>? ?? {}).entries.map((e) {
                        final set = (e.value as String?) == 'set';
                        return Chip(
                          label: Text('${e.key}: ${set ? "✓ Set" : "✗ Not set"}', style: SpeariaType.labelSmall),
                          backgroundColor: set ? SpeariaAura.success.withOpacity(0.15) : SpeariaAura.error.withOpacity(0.15),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Numbers (platform)', style: SpeariaType.titleLarge),
          const SizedBox(height: 8),
          if (_numbersStats != null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _stat('Total numbers', '${_numbersStats!['total_numbers'] ?? 0}'),
                    _stat('In warm-up', '${_numbersStats!['numbers_in_warmup'] ?? 0}'),
                    _stat('Flagged', '${_numbersStats!['numbers_flagged'] ?? 0}'),
                    _stat('Total daily capacity', '${_numbersStats!['total_daily_capacity'] ?? 0}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text('Warm-up management', style: SpeariaType.titleMedium),
          const SizedBox(height: 8),
          if (_warmUpNumbers != null && _warmUpNumbers!.isNotEmpty)
            ...(_warmUpNumbers as List).map<Widget>((n) {
              final numberId = n['number_id'] as String? ?? '';
              final phone = n['phone_number'] as String? ?? '';
              final org = n['org_id'] as String? ?? '';
              final week = n['warm_up_week'] as num? ?? 0;
              final daysInWeek = n['days_in_current_week'] as num? ?? 0;
              final nextDate = n['next_advance_date'] as String?;
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: SpeariaAura.border)),
                child: ListTile(
                  title: Text(phone),
                  subtitle: Text('Org: $org · Week $week · days in week: $daysInWeek · next: $nextDate'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _advanceWarmUp(numberId),
                        child: const Text('Advance week'),
                      ),
                      TextButton(
                        onPressed: () => _resetWarmUp(numberId),
                        child: const Text('Reset warm-up'),
                      ),
                    ],
                  ),
                ),
              );
            })
          else if (_warmUpNumbers != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text('No numbers in warm-up.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
            ),
          const SizedBox(height: 12),
          Text('Daily reset log', style: SpeariaType.titleMedium),
          const SizedBox(height: 8),
          if (_dailyResetLog != null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: SpeariaAura.border)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last reset: ${_dailyResetLog!['count_reset'] ?? 0} numbers at ${_dailyResetLog!['last_run_at'] ?? '—'}', style: SpeariaType.bodyMedium),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _triggerDailyReset,
                      child: const Text('Trigger reset now'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('Voice tier configs', style: SpeariaType.titleLarge),
          const SizedBox(height: 8),
          ...(_tierConfigs ?? []).map<Widget>((tc) {
            final tier = tc['tier'] as String? ?? '';
            final price = tc['price_per_minute'] as num? ?? 0.0;
            final credits = tc['credits_per_minute'] as num? ?? 0;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
              child: ExpansionTile(
                title: Text('$tier — \$$price/min, $credits credits/min', style: SpeariaType.titleMedium),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _jsonBlock('Voice', tc['vapi_voice_config']),
                        const SizedBox(height: 8),
                        _jsonBlock('Transcriber', tc['vapi_transcriber_config']),
                        const SizedBox(height: 8),
                        _jsonBlock('Model', tc['vapi_model_config']),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: SpeariaType.titleMedium.copyWith(fontWeight: FontWeight.w600)),
        Text(label, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
      ],
    );
  }

  Widget _jsonBlock(String title, dynamic data) {
    final str = data is Map || data is List ? _prettyJson(data) : data.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SpeariaType.labelMedium),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: SpeariaAura.bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: SpeariaAura.border)),
          child: SelectableText(str, style: SpeariaType.bodySmall.copyWith(fontFamily: 'monospace')),
        ),
      ],
    );
  }

  String _prettyJson(dynamic d) {
    try {
      if (d is Map) return _mapToJson(d);
      if (d is List) return _listToJson(d);
      return d.toString();
    } catch (_) {
      return d.toString();
    }
  }

  String _mapToJson(Map m, [int indent = 0]) {
    final pad = '  ' * indent;
    final lines = <String>['{'];
    m.forEach((k, v) {
      if (v is Map) {
        lines.add('$pad  "$k": ${_mapToJson(v, indent + 1)},');
      } else if (v is List) {
        lines.add('$pad  "$k": ${_listToJson(v, indent + 1)},');
      } else {
        lines.add('$pad  "$k": ${v is String ? '"$v"' : v},');
      }
    });
    lines.add('$pad}');
    return lines.join('\n');
  }

  String _listToJson(List l, [int indent = 0]) {
    if (l.isEmpty) return '[]';
    final pad = '  ' * indent;
    final lines = <String>['['];
    for (final e in l) {
      if (e is Map) lines.add('$pad  ${_mapToJson(e, indent + 1)},');
      else if (e is List) lines.add('$pad  ${_listToJson(e, indent + 1)},');
      else lines.add('$pad  $e,');
    }
    lines.add('$pad]');
    return lines.join('\n');
  }

  Future<void> _advanceWarmUp(String numberId) async {
    try {
      await SpeariaApi.postJsonMap('/api/admin/numbers/warm-up/$numberId/advance', body: {}, adminAuth: true);
      if (mounted) _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _resetWarmUp(String numberId) async {
    try {
      await SpeariaApi.postJsonMap('/api/admin/numbers/warm-up/$numberId/reset', body: {}, adminAuth: true);
      if (mounted) _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _triggerDailyReset() async {
    try {
      await SpeariaApi.postJsonMap('/api/admin/numbers/daily-reset/trigger', body: {}, adminAuth: true);
      if (mounted) _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
