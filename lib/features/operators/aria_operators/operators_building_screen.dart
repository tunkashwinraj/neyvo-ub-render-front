import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pulse_route_names.dart';
import 'aria_operator_models.dart';
import 'aria_operator_providers.dart';

class OperatorsBuildingScreen extends ConsumerStatefulWidget {
  final String operatorId;
  const OperatorsBuildingScreen({required this.operatorId, super.key});

  @override
  ConsumerState<OperatorsBuildingScreen> createState() => _OperatorsBuildingScreenState();
}

class _OperatorsBuildingScreenState extends ConsumerState<OperatorsBuildingScreen> {
  ProviderSubscription<AsyncValue<AriaOperatorStatus>>? _buildStatusSub;

  @override
  void initState() {
    super.initState();
    _buildStatusSub = ref.listenManual<AsyncValue<AriaOperatorStatus>>(
      ariaOperatorBuildStatusProvider(widget.operatorId),
      (prev, next) {
        if (next is AsyncData<AriaOperatorStatus>) {
          if (next.value.status == 'live') {
            Navigator.pushReplacementNamed(
              context,
              '${PulseRouteNames.operatorsRoot}/${widget.operatorId}',
            );
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _buildStatusSub?.close();
    _buildStatusSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(ariaOperatorBuildStatusProvider(widget.operatorId));
    return Scaffold(
      appBar: AppBar(title: const Text('Building your operator')),
      body: statusAsync.when(
        loading: () => _buildBody(context, const AriaOperatorStatus(status: 'building', currentStep: 0, errorMessage: ''), isLoading: true),
        error: (e, st) => _buildError(context, e.toString()),
        data: (status) {
          if (status.status == 'error') {
            return _buildError(context, status.errorMessage);
          }
          return _buildBody(context, status, isLoading: false);
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, String err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 52, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            const Text(
              'We hit an issue while building your operator.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              err,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, PulseRouteNames.operatorsNew);
              },
              child: const Text('Retry with a new ARIA session'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AriaOperatorStatus status, {required bool isLoading}) {
    final currentStep = status.currentStep;
    final stage = _stageIndexFromPipelineStep(currentStep);
    final stages = [
      'Analyzing your conversation…',
      'Understanding your business…',
      'Designing the conversation flow…',
      'Optimizing for voice…',
      'Creating your operator…',
      'Going live…',
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Building your operator…',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              const Text(
                'This usually takes 30-60 seconds.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              _StageList(stages: stages, activeIndex: stage),
              const SizedBox(height: 22),
              if (isLoading)
                const CircularProgressIndicator()
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  int _stageIndexFromPipelineStep(int currentStep) {
    if (currentStep <= 2) return 0;
    if (currentStep == 3) return 1;
    if (currentStep == 4) return 2;
    if (currentStep == 5) return 3;
    if (currentStep == 6 || currentStep == 7) return 4;
    if (currentStep >= 8) return 5;
    return 0;
  }
}

class _StageList extends StatelessWidget {
  final List<String> stages;
  final int activeIndex;

  const _StageList({required this.stages, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(stages.length, (i) {
        final done = i < activeIndex;
        final active = i == activeIndex;
        final color = done ? const Color(0xFF22C55E) : (active ? const Color(0xFFA5B4FC) : const Color(0xFF64748B));

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
            color: Colors.white.withOpacity(active ? 0.03 : 0.02),
          ),
          child: Row(
            children: [
              Icon(done ? Icons.check_circle : (active ? Icons.hourglass_top : Icons.radio_button_unchecked), color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stages[i],
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

