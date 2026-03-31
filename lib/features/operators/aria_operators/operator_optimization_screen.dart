import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'operator_optimization_api_service.dart';
import 'operator_optimization_providers.dart';

/// Route: /operators/{operatorId}/optimization
class OperatorOptimizationScreen extends ConsumerStatefulWidget {
  final String operatorId;
  const OperatorOptimizationScreen({required this.operatorId, super.key});

  @override
  ConsumerState<OperatorOptimizationScreen> createState() => _OperatorOptimizationScreenState();
}

class _OperatorOptimizationScreenState extends ConsumerState<OperatorOptimizationScreen> {
  double? _thresholdDraft;
  bool? _enabledDraft;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(optimizationStatusProvider(widget.operatorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Operator optimization')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data['ok'] != true) {
            return Center(child: Text(data.toString()));
          }
          final threshold = (data['threshold'] as num?)?.toDouble() ?? 6.0;
          final enabled = data['optimization_enabled'] != false;
          _thresholdDraft ??= threshold;
          _enabledDraft ??= enabled;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(optimizationStatusProvider(widget.operatorId));
              ref.invalidate(optimizationIterationsProvider(widget.operatorId));
              ref.invalidate(optimizationFlaggedCallsProvider(widget.operatorId));
              ref.invalidate(optimizationPerformanceProvider(widget.operatorId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Operator ${widget.operatorId}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Iterations: ${data['iteration_count'] ?? 0}'),
                Text('Current iteration: ${data['current_iteration'] ?? 0}'),
                Text('Core goal doc: ${data['core_goal_present'] == true ? "yes" : "no"}'),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Optimization enabled'),
                  value: _enabledDraft ?? enabled,
                  onChanged: (v) => setState(() => _enabledDraft = v),
                ),
                Text('Threshold: ${_thresholdDraft?.toStringAsFixed(1) ?? threshold.toStringAsFixed(1)}'),
                Slider(
                  min: 3,
                  max: 9,
                  divisions: 60,
                  value: (_thresholdDraft ?? threshold).clamp(3.0, 9.0),
                  label: (_thresholdDraft ?? threshold).toStringAsFixed(1),
                  onChanged: (v) => setState(() => _thresholdDraft = v),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await OperatorOptimizationApiService.updateSettings(
                        widget.operatorId,
                        threshold: _thresholdDraft,
                        optimizationEnabled: _enabledDraft,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Settings saved')),
                        );
                      }
                      ref.invalidate(optimizationStatusProvider(widget.operatorId));
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Save failed: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save settings'),
                ),
                const Divider(height: 32),
                const Text('Recent iterations', style: TextStyle(fontWeight: FontWeight.bold)),
                _IterationsSection(operatorId: widget.operatorId),
                const Divider(height: 32),
                const Text('Flagged / analyzed calls', style: TextStyle(fontWeight: FontWeight.bold)),
                _FlaggedSection(operatorId: widget.operatorId),
                const Divider(height: 32),
                const Text('Performance (measured)', style: TextStyle(fontWeight: FontWeight.bold)),
                _PerformanceSection(operatorId: widget.operatorId),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IterationsSection extends ConsumerWidget {
  final String operatorId;
  const _IterationsSection({required this.operatorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(optimizationIterationsProvider(operatorId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
      error: (e, _) => Text('Iterations: $e'),
      data: (data) {
        final list = (data['iterations'] as List?) ?? [];
        if (list.isEmpty) return const Text('No iterations yet.');
        return Column(
          children: list.take(10).map((raw) {
            final it = raw as Map;
            final w = (it['what_was_improved'] ?? '').toString().replaceAll('\n', ' ');
            return ListTile(
              dense: true,
              title: Text('Iteration ${it['iteration_number'] ?? "?"}'),
              subtitle: Text(w.length > 120 ? '${w.substring(0, 120)}…' : w),
            );
          }).toList(),
        );
      },
    );
  }
}

class _FlaggedSection extends ConsumerWidget {
  final String operatorId;
  const _FlaggedSection({required this.operatorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(optimizationFlaggedCallsProvider(operatorId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('Flagged: $e'),
      data: (data) {
        final list = (data['calls'] as List?) ?? [];
        if (list.isEmpty) return const Text('No flagged pipeline calls in Firestore yet.');
        return Column(
          children: list.take(15).map((raw) {
            final c = raw as Map;
            return ListTile(
              dense: true,
              title: Text((c['optimization_status'] ?? c['id'] ?? '').toString()),
              subtitle: Text('score: ${c['score'] ?? c['final_score'] ?? "-"}'),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PerformanceSection extends ConsumerWidget {
  final String operatorId;
  const _PerformanceSection({required this.operatorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(optimizationPerformanceProvider(operatorId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('Performance: $e'),
      data: (data) {
        final list = (data['iterations'] as List?) ?? [];
        if (list.isEmpty) return const Text('No score_before/score_after data yet.');
        return Column(
          children: list.map((raw) {
            final it = raw as Map;
            return ListTile(
              dense: true,
              title: Text('Iteration ${it['iteration_number']}'),
              subtitle: Text(
                'before: ${it['score_before'] ?? "-"}  after: ${it['score_after'] ?? "-"}  regression: ${it['regression_detected']}',
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
