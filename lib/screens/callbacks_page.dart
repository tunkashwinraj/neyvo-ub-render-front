import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';
import '../utils/callback_date_format.dart';
import 'outbound_calls_page.dart';
import 'student_detail_page.dart';

class CallbacksPage extends StatefulWidget {
  const CallbacksPage({super.key});

  @override
  State<CallbacksPage> createState() => _CallbacksPageState();
}

class _CallbacksPageState extends State<CallbacksPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>> _callbacks = [];
  String _filter = 'all'; // all | overdue

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final analyticsRes = await NeyvoPulseApi.getCallbacksAnalytics();
      final listRes = await NeyvoPulseApi.listCallbacks();
      if (!mounted) return;
      if (analyticsRes['ok'] == true) {
        _analytics = analyticsRes['analytics'] as Map<String, dynamic>?;
      }
      if (listRes['ok'] == true) {
        final list = (listRes['callbacks'] as List? ?? []).cast<Map<String, dynamic>>();
        _callbacks = list;
      } else if (listRes['error'] != null) {
        _error = listRes['error']?.toString();
      }
      _loading = false;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Callbacks')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.error),
              ),
              const SizedBox(height: NeyvoSpacing.md),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final stats = _analytics ?? const {};
    final scheduled = (stats['scheduled'] as num?)?.toInt() ?? 0;
    final completed = (stats['completed'] as num?)?.toInt() ?? 0;
    final exhausted = (stats['exhausted'] as num?)?.toInt() ?? 0;
    final retryWait = (stats['retry_wait'] as num?)?.toInt() ?? 0;
    final dialing = (stats['dialing'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Callbacks & Scheduler')),
      body: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Callback status overview',
              style: NeyvoType.headlineMedium.copyWith(color: NeyvoColors.textPrimary),
            ),
            const SizedBox(height: NeyvoSpacing.sm),
            Text(
              'These numbers refresh automatically based on the backend job scheduler.',
              style: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.textSecondary),
            ),
            const SizedBox(height: NeyvoSpacing.xl),
            Wrap(
              spacing: NeyvoSpacing.lg,
              runSpacing: NeyvoSpacing.lg,
              children: [
                _statCard('Scheduled', scheduled, Icons.schedule, NeyvoColors.teal),
                _statCard('Dialing', dialing, Icons.phone_in_talk_outlined, NeyvoColors.teal),
                _statCard('Retry wait', retryWait, Icons.autorenew, NeyvoColors.warning),
                _statCard('Completed', completed, Icons.check_circle_outline, NeyvoColors.success),
                _statCard('Exhausted', exhausted, Icons.cancel_outlined, NeyvoColors.textMuted),
              ],
            ),
            const SizedBox(height: NeyvoSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                DropdownButton<String>(
                  value: _filter,
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All callbacks'),
                    ),
                    DropdownMenuItem(
                      value: 'overdue',
                      child: Text('Overdue only'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _filter = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: NeyvoSpacing.lg),
            Expanded(
              child: _filteredCallbacks().isEmpty
                  ? Center(
                      child: Text(
                        'No active callbacks (scheduled, retrying, or dialing).',
                        style: NeyvoType.bodyMedium.copyWith(color: NeyvoColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredCallbacks().length,
                      separatorBuilder: (_, __) => const SizedBox(height: NeyvoSpacing.sm),
                      itemBuilder: (context, index) {
                        final c = _filteredCallbacks()[index];
                        final name = (c['name'] ?? 'Unknown').toString();
                        final phone = (c['phone'] ?? '—').toString();
                        final status = (c['callback_status'] ?? '').toString();
                        final attempts = (c['callback_attempt_count'] as num?)?.toInt();
                        final maxAttempts = (c['callback_max_attempts'] as num?)?.toInt();
                        final atRaw = c['callback_at'];
                        final at = formatCallbackTime12h(atRaw);
                        final studentId = (c['id'] ?? '').toString();
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: studentId.isEmpty
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => StudentDetailPage(
                                          studentId: studentId,
                                          onUpdated: _load,
                                        ),
                                      ),
                                    );
                                  },
                            borderRadius: BorderRadius.circular(NeyvoRadius.lg),
                            child: Card(
                              color: NeyvoTheme.bgCard,
                              child: Padding(
                                padding: const EdgeInsets.all(NeyvoSpacing.md),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: NeyvoType.titleMedium.copyWith(color: NeyvoColors.textPrimary),
                                                ),
                                          const SizedBox(height: 2),
                                          Text(
                                            phone,
                                            style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textSecondary),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: NeyvoSpacing.sm,
                                            runSpacing: NeyvoSpacing.sm,
                                            children: [
                                              Chip(
                                                label: Text(
                                                  'Status: ${status.isEmpty ? 'unknown' : status}',
                                                  style: NeyvoType.bodySmall,
                                                ),
                                              ),
                                              if (attempts != null && maxAttempts != null)
                                                Chip(
                                                  label: Text(
                                                    'Attempts: $attempts / $maxAttempts',
                                                    style: NeyvoType.bodySmall,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (at.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              'Next: $at',
                                              style: NeyvoType.bodyMedium.copyWith(
                                                color: NeyvoColors.tealLight,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                              ),
                                            ),
                                          if (studentId.isNotEmpty)
                                            Icon(
                                              Icons.chevron_right,
                                              color: NeyvoColors.textMuted,
                                              size: 24,
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: NeyvoSpacing.md),
                                    Wrap(
                                      spacing: NeyvoSpacing.sm,
                                      children: [
                                        FilledButton.tonal(
                                          onPressed: studentId.isEmpty
                                              ? null
                                              : () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) => OutboundCallsPage(
                                                        prefillStudent: {
                                                          'id': studentId,
                                                          'name': name,
                                                          'phone': phone,
                                                        },
                                                      ),
                                                    ),
                                                  );
                                                },
                                          child: const Text('Call now'),
                                        ),
                                        OutlinedButton(
                                          onPressed: studentId.isEmpty
                                              ? null
                                              : () async {
                                                  try {
                                                    await NeyvoPulseApi.cancelStudentCallback(studentId);
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Callback cancelled')),
                                                    );
                                                    await _load();
                                                  } catch (e) {
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text(e.toString())),
                                                    );
                                                  }
                                                },
                                          child: const Text('Cancel'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, int value, IconData icon, Color color) {
    return Card(
      color: NeyvoTheme.bgCard,
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: NeyvoSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: NeyvoType.headlineMedium.copyWith(color: NeyvoColors.textPrimary),
                ),
                Text(
                  label,
                  style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filteredCallbacks() {
    if (_filter == 'overdue') {
      final now = DateTime.now().toUtc();
      return _callbacks.where((c) {
        final raw = c['callback_at'];
        if (raw == null) return false;
        try {
          final dt = DateTime.parse(raw.toString()).toUtc();
          return dt.isBefore(now);
        } catch (_) {
          return false;
        }
      }).toList();
    }
    return _callbacks;
  }

}

