import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../foundation/tokens/neyvo_tokens.dart';
import '../../../theme/neyvo_theme.dart';

enum NeyvoAIOrbState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

/// Core visual identity for Voice OS – animated AI orb.
class NeyvoAIOrb extends StatefulWidget {
  final NeyvoAIOrbState state;
  final double size;

  const NeyvoAIOrb({
    super.key,
    required this.state,
    this.size = 120,
  });

  @override
  State<NeyvoAIOrb> createState() => _NeyvoAIOrbState();
}

class _NeyvoAIOrbState extends State<NeyvoAIOrb>
    with TickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return AnimatedBuilder(
      animation: Listenable.merge([_breathCtrl, _pulseCtrl, _rotateCtrl]),
      builder: (context, _) {
        final breath = 0.9 + 0.1 * math.sin(_breathCtrl.value * 2 * math.pi);
        final pulse = 0.7 + 0.3 * math.sin(_pulseCtrl.value * 2 * math.pi);
        final rotation = _rotateCtrl.value * 2 * math.pi;

        final isError = widget.state == NeyvoAIOrbState.error;
        final isSpeaking = widget.state == NeyvoAIOrbState.speaking;
        final isProcessing = widget.state == NeyvoAIOrbState.processing;
        final isListening = widget.state == NeyvoAIOrbState.listening;

        final baseColor = isError
            ? NeyvoAccent.error
            : isProcessing
                ? NeyvoAccent.processing
                : NeyvoAccent.primary;

        final glowOpacity = switch (widget.state) {
          NeyvoAIOrbState.idle => 0.25,
          NeyvoAIOrbState.listening => 0.4,
          NeyvoAIOrbState.processing => 0.5,
          NeyvoAIOrbState.speaking => 0.55,
          NeyvoAIOrbState.error => 0.6,
        };

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer breathing glow
              Container(
                width: size * breath,
                height: size * breath,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      baseColor.withOpacity(glowOpacity),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Rotating gradient ring for processing / speaking
              if (isProcessing || isSpeaking)
                Transform.rotate(
                  angle: rotation,
                  child: CustomPaint(
                    size: Size.square(size * 0.9),
                    painter: _RingPainter(
                      color: baseColor.withOpacity(isSpeaking ? 0.9 : 0.6),
                      thickness: 4,
                      dash: isSpeaking,
                    ),
                  ),
                ),
              // Core orb
              Container(
                width: size * 0.55,
                height: size * 0.55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      baseColor,
                      NeyvoColors.tealLight,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Simple inner pulse for listening / speaking.
                    if (isListening || isSpeaking)
                      Container(
                        width: size * 0.3 * pulse,
                        height: size * 0.3 * pulse,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                    Icon(
                      isError
                          ? Icons.error_outline
                          : isListening
                              ? Icons.hearing
                              : isSpeaking
                                  ? Icons.graphic_eq
                                  : isProcessing
                                      ? Icons.sync
                                      : Icons.bubble_chart_outlined,
                      size: size * 0.23,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool dash;

  _RingPainter({
    required this.color,
    required this.thickness,
    this.dash = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(0.0),
          color,
          color.withOpacity(0.0),
        ],
      ).createShader(rect);

    if (!dash) {
      canvas.drawArc(rect.deflate(thickness / 2), 0, 2 * math.pi, false, paint);
      return;
    }

    // Simple dashed arc effect for speaking waveform ring.
    const segments = 24;
    const gapFactor = 0.45;
    final sweep = 2 * math.pi / segments;
    for (int i = 0; i < segments; i++) {
      final start = i * sweep;
      canvas.drawArc(
        rect.deflate(thickness / 2),
        start,
        sweep * (1 - gapFactor),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.thickness != thickness ||
        oldDelegate.dash != dash;
  }
}

