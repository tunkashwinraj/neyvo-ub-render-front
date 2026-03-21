// UB Model Overview – "receipt" screen after initialization. Shows stats, departments, recommended operators; Continue → Dashboard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ub_model_overview_provider.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/ai_orb/neyvo_ai_orb.dart';
import '../../components/backgrounds/neyvo_neural_background.dart';
import '../../components/glass/neyvo_glass_panel.dart';

class UbModelOverviewPage extends ConsumerStatefulWidget {
  const UbModelOverviewPage({super.key});

  @override
  ConsumerState<UbModelOverviewPage> createState() => _UbModelOverviewPageState();
}

class _UbModelOverviewPageState extends ConsumerState<UbModelOverviewPage> {
  static const List<String> _recommendedOperators = [
    'Admissions Operator',
    'Student Financial Services Operator',
    'Registrar Operator',
    'Housing Operator',
    'IT Help Desk Operator',
    'General Front Desk Operator',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ubModelOverviewCtrlProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(ubModelOverviewCtrlProvider);

    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      body: Stack(
        children: [
          const Positioned.fill(child: NeyvoNeuralBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ui.loading && ui.status == 'building'
                      ? _buildBuildingState(ui)
                      : ui.status == 'ready'
                          ? _buildReadyState(ui)
                          : ui.status == 'error'
                              ? _buildErrorState(ui)
                              : _buildBuildingState(ui),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingState(UbModelOverviewUiState ui) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const NeyvoAIOrb(state: NeyvoAIOrbState.processing, size: 120),
        const SizedBox(height: 24),
        Text(
          'Building your University Model…',
          style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We are analyzing ${ui.websiteUrl}. This may take a minute.',
          style: NeyvoTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.teal),
        ),
      ],
    );
  }

  Widget _buildErrorState(UbModelOverviewUiState ui) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'UB Voice OS',
            style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          NeyvoGlassPanel(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: NeyvoColors.error, size: 28),
                    const SizedBox(width: 12),
                    Text('Analysis encountered an issue', style: NeyvoTextStyles.heading),
                  ],
                ),
                const SizedBox(height: 12),
                Text(ui.error ?? 'Unknown error', style: NeyvoTextStyles.body),
                const SizedBox(height: 20),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () => ref.read(ubModelOverviewCtrlProvider.notifier).rerunAnalysis(),
                      style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                      child: const Text('Re-run analysis'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyState(UbModelOverviewUiState ui) {
    final summary = ui.summary ?? {};
    final deptCount = summary['departmentsCount'] is int ? summary['departmentsCount'] as int : ui.departments.length;
    final faqCount = summary['faqCount'] is int ? summary['faqCount'] as int : ui.faqTopics.length;
    final contactsFound = summary['contactsFound'] is int ? summary['contactsFound'] as int : 0;
    final hoursFound = (summary['hoursFound'] as String?) ?? 'No';

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Text(
          'UB Voice OS initialized',
          style: NeyvoTextStyles.title.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: NeyvoColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'We analyzed ${ui.websiteUrl} and built your University Model.',
          style: NeyvoTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _statCard('Departments detected', '$deptCount')),
            const SizedBox(width: 12),
            Expanded(child: _statCard('FAQs extracted', '$faqCount')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Contacts found', '$contactsFound')),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Hours found', hoursFound)),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Department preview',
          style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 12),
        ...(ui.departments.take(10).map((d) {
          final m = d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
          final name = m['name']?.toString() ?? 'Department';
          final handles = m['handles']?.toString() ?? '';
          final phone = m['phone']?.toString();
          final email = m['email']?.toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NeyvoGlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
                  if (handles.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(handles, style: NeyvoTextStyles.body),
                  ],
                  if (phone != null && phone.isNotEmpty || email != null && email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [if (phone != null && phone.isNotEmpty) phone, if (email != null && email.isNotEmpty) email]
                          .join(' • '),
                      style: NeyvoTextStyles.micro,
                    ),
                  ],
                ],
              ),
            ),
          );
        })),
        const SizedBox(height: 24),
        Text(
          'Recommended Operators',
          style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'We recommend starting with: ${_recommendedOperators.take(4).join(', ')}…',
          style: NeyvoTextStyles.body,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => ref.read(ubModelOverviewCtrlProvider.notifier).completeAndGoToDashboard(context),
          style: FilledButton.styleFrom(
            backgroundColor: NeyvoColors.teal,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Continue → Dashboard'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => ref.read(ubModelOverviewCtrlProvider.notifier).rerunAnalysis(),
          child: const Text('Re-run analysis'),
        ),
        if (ui.error != null) ...[
          const SizedBox(height: 12),
          Text(ui.error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
        ],
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return NeyvoGlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.teal)),
          const SizedBox(height: 4),
          Text(label, style: NeyvoTextStyles.micro),
        ],
      ),
    );
  }
}
