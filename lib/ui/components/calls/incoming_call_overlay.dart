import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../theme/neyvo_theme.dart';
import '../ai_orb/neyvo_ai_orb.dart';
import '../glass/neyvo_glass_panel.dart';

class IncomingCallOverlay extends StatelessWidget {
  const IncomingCallOverlay({
    super.key,
    required this.agentName,
    this.fromNumber,
    required this.onViewLive,
    required this.onDismiss,
  });

  final String agentName;
  final String? fromNumber;
  final VoidCallback onViewLive;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: onDismiss,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: NeyvoColors.bgVoid.withOpacity(0.55),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                final y = lerpDouble(-40, 16, t)!;
                return Transform.translate(
                  offset: Offset(0, y),
                  child: Opacity(opacity: t, child: child),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: NeyvoGlassPanel(
                    glowing: true,
                    child: Row(
                      children: [
                        const NeyvoAIOrb(state: NeyvoAIOrbState.listening, size: 56),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Incoming call', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
                              const SizedBox(height: 4),
                              Text('Neyvo is answering…', style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (agentName.trim().isNotEmpty) 'Agent: $agentName',
                                  if ((fromNumber ?? '').trim().isNotEmpty) 'From: $fromNumber',
                                ].join(' · '),
                                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: onDismiss,
                          child: const Text('Dismiss'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: onViewLive,
                          style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: Colors.white),
                          child: const Text('View live'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

