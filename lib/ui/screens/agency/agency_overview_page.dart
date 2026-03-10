import 'package:flutter/material.dart';

import '../../../theme/neyvo_theme.dart';
import '../../components/ai_orb/neyvo_ai_orb.dart';
import '../../components/glass/neyvo_glass_panel.dart';

class AgencyOverviewPage extends StatelessWidget {
  const AgencyOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const NeyvoAIOrb(state: NeyvoAIOrbState.idle, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Agency overview', style: NeyvoTextStyles.title.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(
                            'Multi-org rollups, billing aggregation, and template propagation.',
                            style: NeyvoTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                NeyvoGlassPanel(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      _Metric(label: 'Client orgs', value: '—'),
                      _Metric(label: 'Total calls (30d)', value: '—'),
                      _Metric(label: 'Total spend (30d)', value: '—'),
                      _Metric(label: 'Templates', value: '—'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                NeyvoGlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Clients', style: NeyvoTextStyles.heading),
                      const SizedBox(height: 8),
                      Text(
                        'This page is scaffolded. Wire it to `memberships[]` / agency data once the backend returns org lists.',
                        style: NeyvoTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: NeyvoTextStyles.micro),
        ],
      ),
    );
  }
}

