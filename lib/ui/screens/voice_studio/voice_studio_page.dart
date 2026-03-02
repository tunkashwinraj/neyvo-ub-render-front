import 'package:flutter/material.dart';

import '../../../theme/neyvo_theme.dart';
import '../../components/ai_orb/neyvo_ai_orb.dart';
import '../../components/glass/neyvo_glass_panel.dart';

class VoiceStudioPage extends StatelessWidget {
  const VoiceStudioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: NeyvoGlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const NeyvoAIOrb(state: NeyvoAIOrbState.idle, size: 64),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Voice Studio', style: NeyvoTextStyles.title.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(
                              'Advanced voice tuning, testing, and live monitoring.',
                              style: NeyvoTextStyles.body,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'This surface becomes available once your system is live or enabled in Settings.',
                    style: NeyvoTextStyles.micro,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

