// lib/ui/activation/activation_dock.dart
// Persistent Activation Mode dock shown on all PulseShell pages until LIVE.

import 'package:flutter/material.dart';

import '../../theme/neyvo_theme.dart';
import '../components/glass/neyvo_glass_panel.dart';
import 'activation_service.dart';

class ActivationDock extends StatelessWidget {
  final ActivationService service;
  final void Function(String route) onNavigateRoute;
  final VoidCallback onOpenActivationHome;

  const ActivationDock({
    super.key,
    required this.service,
    required this.onNavigateRoute,
    required this.onOpenActivationHome,
  });

  @override
  Widget build(BuildContext context) {
    final status = service.status;

    if (service.isLoading && status == null) {
      // Lightweight loading stub.
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: NeyvoGlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.teal),
              ),
              const SizedBox(width: 10),
              Text('Checking activation status…', style: NeyvoTextStyles.body),
            ],
          ),
        ),
      );
    }

    if (status == null || service.isLive) {
      return const SizedBox.shrink();
    }

    final stage = status.stage;
    final pct = (service.progress01 * 100).round();
    final mainLabel = switch (stage) {
      ActivationStage.intro => 'Start with the Voice OS intro.',
      ActivationStage.business => 'Model your business so agents have context.',
      ActivationStage.agents => 'Create at least one AI agent.',
      ActivationStage.numbers => 'Connect a phone number for calls.',
      ActivationStage.testCall => 'Make your first call to go live.',
      ActivationStage.live => 'Live',
    };

    if (service.isCollapsed) {
      final stepsCompleted = [
        status.businessModelReady,
        status.agentsCreated,
        status.numberConnected,
        status.firstCallCompleted,
      ].where((b) => b).length;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () => service.setCollapsed(false),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: NeyvoColors.bgRaised,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: NeyvoColors.teal.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NeyvoColors.teal,
                      boxShadow: [
                        BoxShadow(
                          color: NeyvoColors.teal.withOpacity(0.6),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Activation: $stepsCompleted/4',
                    style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Continue setup',
                    style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.teal, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final next = service.nextAction;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: NeyvoGlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        glowing: true,
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NeyvoColors.teal.withOpacity(0.15),
                border: Border.all(color: NeyvoColors.teal.withOpacity(0.4)),
              ),
              child: const Icon(Icons.rocket_launch_outlined, size: 16, color: NeyvoColors.teal),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activation Mode',
                    style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mainLabel,
                    style: NeyvoTextStyles.body,
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: service.progress01.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: NeyvoColors.borderSubtle,
                      valueColor: const AlwaysStoppedAnimation<Color>(NeyvoColors.teal),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$pct% complete · Business • Agents • Number • First call',
                    style: NeyvoTextStyles.micro,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (next != null)
              FilledButton(
                onPressed: () => onNavigateRoute(next.route),
                style: FilledButton.styleFrom(
                  backgroundColor: NeyvoColors.teal,
                  minimumSize: const Size(0, 36),
                ),
                child: Text(
                  next.label.isNotEmpty ? next.label : 'Continue setup',
                ),
              ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => onOpenActivationHome(),
              child: const Text('View checklist'),
            ),
            IconButton(
              tooltip: 'Hide activation panel',
              onPressed: () => service.setCollapsed(true),
              icon: const Icon(Icons.expand_less, size: 18, color: NeyvoColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

