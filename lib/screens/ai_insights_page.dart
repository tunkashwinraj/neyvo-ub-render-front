// lib/screens/ai_insights_page.dart
// AI Insights – call outcomes, common questions, payment barriers, recommendations

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../../theme/spearia_theme.dart';

class AiInsightsPage extends StatefulWidget {
  const AiInsightsPage({super.key});

  @override
  State<AiInsightsPage> createState() => _AiInsightsPageState();
}

class _AiInsightsPageState extends State<AiInsightsPage> {
  Map<String, dynamic>? _insights;
  List<dynamic> _calls = [];
  bool _loading = true;
  String? _error;

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
      final insightsRes = await NeyvoPulseApi.getInsights();
      final callsRes = await NeyvoPulseApi.listCalls();
      final calls = callsRes['calls'] as List? ?? [];
      if (mounted) {
        setState(() {
          _insights = insightsRes;
          _calls = calls;
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

  int _getCompletedCount() {
    return _calls.where((c) {
      final s = (c['status']?.toString() ?? '').toLowerCase();
      return s == 'completed' || s == 'success';
    }).length;
  }

  int _getFailedCount() {
    return _calls.where((c) {
      final s = (c['status']?.toString() ?? '').toLowerCase();
      return s == 'failed' || s == 'error';
    }).length;
  }

  List<String> _extractTopicsFromTranscripts() {
    final keywords = <String, int>{};
    final topicKeywords = {
      'payment plan': 'Payment plans',
      'pay': 'Payment options',
      'balance': 'Balance inquiry',
      'due date': 'Due dates',
      'late fee': 'Late fees',
      'credit': 'Credits',
      'refund': 'Refunds',
      'installment': 'Installments',
      'financial aid': 'Financial aid',
      'scholarship': 'Scholarship',
    };
    for (final call in _calls) {
      final transcript = (call['transcript']?.toString() ?? '').toLowerCase();
      final summary = (call['summary']?.toString() ?? '').toLowerCase();
      final text = '$transcript $summary';
      for (final entry in topicKeywords.entries) {
        if (text.contains(entry.key)) {
          keywords[entry.value] = (keywords[entry.value] ?? 0) + 1;
        }
      }
    }
    final list = keywords.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(8).map((e) => '${e.key} (${e.value})').toList();
  }

  List<String> _extractBarriers() {
    final barriers = <String, int>{};
    final barrierKeywords = {
      'can\'t pay': 'Unable to pay now',
      'cannot pay': 'Unable to pay now',
      'lost job': 'Job loss',
      'waiting for': 'Waiting on funds',
      'next week': 'Payment next week',
      'month end': 'End of month',
      'financial hardship': 'Financial hardship',
      'payment extension': 'Wants extension',
      'dispute': 'Dispute',
    };
    for (final call in _calls) {
      final transcript = (call['transcript']?.toString() ?? '').toLowerCase();
      final summary = (call['summary']?.toString() ?? '').toLowerCase();
      final text = '$transcript $summary';
      for (final entry in barrierKeywords.entries) {
        if (text.contains(entry.key)) {
          barriers[entry.value] = (barriers[entry.value] ?? 0) + 1;
        }
      }
    }
    final list = barriers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(6).map((e) => '${e.key} (${e.value})').toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Insights')),
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

    // Prefer backend insights when available (GET /api/pulse/insights)
    final fromApi = _insights != null && _insights!['ok'] == true;
    final totalCalls = fromApi ? ( (_insights!['total_calls'] as num?)?.toInt() ?? _calls.length ) : _calls.length;
    final completed = fromApi ? ( (_insights!['completed'] as num?)?.toInt() ?? _getCompletedCount() ) : _getCompletedCount();
    final failed = fromApi ? ( (_insights!['failed'] as num?)?.toInt() ?? _getFailedCount() ) : _getFailedCount();
    final successRate = fromApi ? ((_insights!['success_rate_pct'] as num?)?.toDouble() ?? 0.0) : (totalCalls > 0 ? (completed / totalCalls * 100) : 0.0);
    final List<String> topics = fromApi && _insights!['topics'] is List
        ? (_insights!['topics'] as List).map((e) => e is Map ? '${e['label']} (${e['count']})' : e.toString()).cast<String>().toList()
        : _extractTopicsFromTranscripts();
    final List<String> barriers = fromApi && _insights!['payment_barriers'] is List
        ? (_insights!['payment_barriers'] as List).map((e) => e is Map ? '${e['label']} (${e['count']})' : e.toString()).cast<String>().toList()
        : _extractBarriers();
    final List<String> recommendationsList = fromApi && _insights!['recommendations'] is List
        ? (_insights!['recommendations'] as List).map((e) => e.toString()).toList()
        : <String>[
            'Review call logs for failed calls and retry or update phone numbers.',
            'Add FAQ or script lines for topics students ask about most.',
            'Consider payment plans or extensions for common barriers.',
            if (successRate < 70 && totalCalls > 5) 'Try calling at different times to improve answer rate.',
          ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(SpeariaSpacing.lg),
          children: [
            Text(
              'Insights from call conversations',
              style: SpeariaType.headlineMedium,
            ),
            const SizedBox(height: SpeariaSpacing.xs),
            Text(
              'Common questions, payment barriers, and call outcomes.',
              style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
            ),
            const SizedBox(height: SpeariaSpacing.xl),

            // Call outcomes
            _SectionTitle(title: 'Call outcomes', icon: Icons.phone_in_talk),
            const SizedBox(height: SpeariaSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SpeariaSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _OutcomeChip(
                          label: 'Total calls',
                          value: '$totalCalls',
                          color: SpeariaAura.primary,
                        ),
                        _OutcomeChip(
                          label: 'Completed',
                          value: '$completed',
                          color: SpeariaAura.success,
                        ),
                        _OutcomeChip(
                          label: 'Failed',
                          value: '$failed',
                          color: SpeariaAura.error,
                        ),
                      ],
                    ),
                    const SizedBox(height: SpeariaSpacing.md),
                    LinearProgressIndicator(
                      value: successRate / 100,
                      backgroundColor: SpeariaAura.bgDark,
                      valueColor: AlwaysStoppedAnimation<Color>(SpeariaAura.success),
                    ),
                    const SizedBox(height: SpeariaSpacing.xs),
                    Text(
                      'Success rate: ${successRate.toStringAsFixed(1)}%',
                      style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SpeariaSpacing.xl),

            // Common topics (from transcripts)
            _SectionTitle(title: 'Common topics in calls', icon: Icons.topic),
            const SizedBox(height: SpeariaSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SpeariaSpacing.lg),
                child: topics.isEmpty
                    ? Text(
                        'No topics extracted yet. More call transcripts will improve insights.',
                        style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted),
                      )
                    : Wrap(
                        spacing: SpeariaSpacing.sm,
                        runSpacing: SpeariaSpacing.sm,
                        children: topics
                            .map((t) => Chip(
                                  label: Text(t, style: SpeariaType.labelSmall),
                                  backgroundColor: SpeariaAura.primary.withOpacity(0.1),
                                ))
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(height: SpeariaSpacing.xl),

            // Payment barriers
            _SectionTitle(title: 'Payment barriers mentioned', icon: Icons.warning_amber),
            const SizedBox(height: SpeariaSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SpeariaSpacing.lg),
                child: barriers.isEmpty
                    ? Text(
                        'No barriers detected yet. Data comes from call transcripts.',
                        style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted),
                      )
                    : Wrap(
                        spacing: SpeariaSpacing.sm,
                        runSpacing: SpeariaSpacing.sm,
                        children: barriers
                            .map((b) => Chip(
                                  label: Text(b, style: SpeariaType.labelSmall),
                                  backgroundColor: SpeariaAura.warning.withOpacity(0.15),
                                ))
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(height: SpeariaSpacing.xl),

            // Recommendations
            _SectionTitle(title: 'Recommendations', icon: Icons.lightbulb_outline),
            const SizedBox(height: SpeariaSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SpeariaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: recommendationsList
                      .map((text) => _RecommendationItem(
                            icon: Icons.lightbulb_outline,
                            text: text,
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: SpeariaSpacing.xl),

            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(PulseRouteNames.callHistory),
              icon: const Icon(Icons.history),
              label: const Text('View full call logs'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: SpeariaAura.primary),
        const SizedBox(width: SpeariaSpacing.sm),
        Text(title, style: SpeariaType.titleLarge),
      ],
    );
  }
}

class _OutcomeChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _OutcomeChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: SpeariaType.headlineMedium.copyWith(color: color, fontWeight: FontWeight.w700)),
        Text(label, style: SpeariaType.labelSmall.copyWith(color: SpeariaAura.textSecondary)),
      ],
    );
  }
}

class _RecommendationItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RecommendationItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpeariaSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: SpeariaAura.primary),
          const SizedBox(width: SpeariaSpacing.sm),
          Expanded(child: Text(text, style: SpeariaType.bodyMedium)),
        ],
      ),
    );
  }
}
