import 'package:flutter/material.dart';

import '../../theme/neyvo_theme.dart';
import '../../screens/pulse_shell.dart';
import '../../pulse_route_names.dart';
import '../../ui/components/ai_orb/neyvo_ai_orb.dart';
import '../../ui/components/glass/neyvo_glass_panel.dart';
import 'create_agent_wizard.dart';

const List<String> kRecommendedOperators = [
  'Admissions Operator',
  'Student Financial Services Operator',
  'Registrar Operator',
  'Housing Operator',
  'IT Help Desk Operator',
  'General Front Desk Operator',
];

String? departmentIdForLabel(String label) {
  const map = {
    'Admissions Operator': 'admissions',
    'Student Financial Services Operator': 'student_financial_services',
    'Registrar Operator': 'registrar',
    'Housing Operator': 'residential_life_and_housing',
    'IT Help Desk Operator': 'information_technology_help_desk',
    'General Front Desk Operator': null,
  };
  return map[label];
}

class CreateFirstOperatorPanel extends StatelessWidget {
  const CreateFirstOperatorPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const NeyvoAIOrb(state: NeyvoAIOrbState.idle, size: 140),
            const SizedBox(height: 20),
            Text(
              'No operators yet',
              style: NeyvoTextStyles.title.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: NeyvoColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'To begin, use the “Create operator test” button in the top right to create a universal operator.',
              style: NeyvoTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            NeyvoGlassPanel(
              glowing: true,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < kRecommendedOperators.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () async {
                        final deptId = departmentIdForLabel(kRecommendedOperators[i]);
                        if (deptId != null) {
                          final created = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => CreateAgentWizard(initialDepartmentId: deptId),
                          );
                          if (created == true && context.mounted) {
                            PulseShellController.navigatePulse(context, PulseRouteNames.agents);
                          }
                        } else {
                          PulseShellController.navigatePulse(context, PulseRouteNames.agents);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: i == 0 ? Theme.of(context).colorScheme.primary : NeyvoColors.bgRaised,
                        foregroundColor: i == 0 ? NeyvoColors.white : NeyvoColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        i == 0 ? 'Create ${kRecommendedOperators[i]}' : kRecommendedOperators[i],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => PulseShellController.navigatePulse(context, PulseRouteNames.agents),
                    child: const Text('Choose another department'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

