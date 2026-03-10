import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../foundation/tokens/neyvo_tokens.dart';
import '../../../theme/neyvo_theme.dart';

/// Animated "neural field" background for Voice OS surfaces.
///
/// Lightweight CustomPainter instead of heavy shaders, but designed to feel like
/// a living gradient field behind the OS.
class NeyvoNeuralBackground extends StatefulWidget {
  const NeyvoNeuralBackground({super.key});

  @override
  State<NeyvoNeuralBackground> createState() => _NeyvoNeuralBackgroundState();
}

class _NeyvoNeuralBackgroundState extends State<NeyvoNeuralBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
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
            painter: _NeuralFieldPainter(_controller.value),
          );
        },
      ),
    );
  }
}

class _NeuralFieldPainter extends CustomPainter {
  final double t;

  _NeuralFieldPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base deep gradient.
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          NeyvoLayer.voidLayer,
          NeyvoColors.bgBase,
          NeyvoColors.bgRaised,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    // Soft moving "neural" blobs.
    final blobs = <_Blob>[
      _Blob(
        center: Offset(
          size.width * (0.2 + 0.1 * math.sin(t * 2 * math.pi)),
          size.height * (0.3 + 0.05 * math.cos(t * 2 * math.pi)),
        ),
        radius: size.shortestSide * 0.35,
        color: NeyvoAccent.primary.withOpacity(0.28),
      ),
      _Blob(
        center: Offset(
          size.width * (0.8 + 0.1 * math.cos(t * 2 * math.pi)),
          size.height * (0.7 + 0.05 * math.sin(t * 2 * math.pi)),
        ),
        radius: size.shortestSide * 0.4,
        color: NeyvoColors.tealLight.withOpacity(0.20),
      ),
      _Blob(
        center: Offset(
          size.width * 0.5,
          size.height * (0.2 + 0.08 * math.sin(t * 2 * math.pi)),
        ),
        radius: size.shortestSide * 0.25,
        color: NeyvoColors.coral.withOpacity(0.12),
      ),
    ];

    for (final blob in blobs) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            blob.color,
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: blob.center, radius: blob.radius),
        );
      canvas.drawCircle(blob.center, blob.radius, paint);
    }

    // Very subtle diagonal lines to hint at depth.
    final linePaint = Paint()
      ..color = NeyvoColors.borderSubtle.withOpacity(0.25)
      ..strokeWidth = 1;
    const spacing = 42.0;
    for (double d = -size.height; d < size.width + size.height; d += spacing) {
      final start = Offset(d, 0);
      final end = Offset(d - size.height, size.height);
      canvas.drawLine(start, end, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeuralFieldPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

class _Blob {
  final Offset center;
  final double radius;
  final Color color;

  _Blob({
    required this.center,
    required this.radius,
    required this.color,
  });
}

