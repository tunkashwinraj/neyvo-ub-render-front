import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../foundation/tokens/neyvo_tokens.dart';
import '../../../theme/neyvo_theme.dart';

/// Glowing audio-like waveform used for Voice OS surfaces.
///
/// Initially driven by an internal animation; can later be wired to real
/// microphone levels by exposing a value notifier.
class NeyvoVoiceWave extends StatefulWidget {
  const NeyvoVoiceWave({super.key});

  @override
  State<NeyvoVoiceWave> createState() => _NeyvoVoiceWaveState();
}

class _NeyvoVoiceWaveState extends State<NeyvoVoiceWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: const Size(double.infinity, 140),
            painter: _VoiceWavePainter(_controller.value),
          );
        },
      ),
    );
  }
}

class _VoiceWavePainter extends CustomPainter {
  final double t;

  _VoiceWavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int layer = 0; layer < 3; layer++) {
      final opacity = 0.18 + layer * 0.24;
      final color = layer == 0
          ? NeyvoAccent.primary
          : layer == 1
              ? NeyvoColors.tealLight
              : NeyvoColors.info;
      final paint = basePaint
        ..color = color.withOpacity(opacity)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, (layer + 1) * 2.0 + 1.0);

      final path = Path();
      final freq = 1.0 + layer * 0.3;
      final amp = 18.0 + layer * 6.0;

      for (double x = 0; x <= size.width; x += 4) {
        final progress = x / size.width;
        final primary = math.sin((progress * 2 * math.pi * freq) + t * 2 * math.pi);
        final secondary =
            math.sin((progress * math.pi * 0.8) - t * math.pi * 1.2);
        final envelope =
            math.sin(progress * math.pi); // fade at edges for soft feel.
        final y = centerY +
            (primary * amp * envelope) +
            (secondary * 4.0 * envelope);

        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWavePainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

