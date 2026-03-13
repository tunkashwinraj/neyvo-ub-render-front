import 'package:flutter/material.dart';

import '../theme/neyvo_theme.dart';
import '../tenant/tenant_brand.dart';

class NeyvoLoadingScreen extends StatelessWidget {
  const NeyvoLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: NeyvoColors.bgLight,
      body: Center(
        child: NeyvoPurpleCirclesLoader(),
      ),
    );
  }
}

class NeyvoPurpleCirclesLoader extends StatefulWidget {
  final int circleCount;
  final double circleSize;
  final double spacing;
  final Duration duration;

  const NeyvoPurpleCirclesLoader({
    super.key,
    this.circleCount = 3,
    this.circleSize = 14,
    this.spacing = 10,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<NeyvoPurpleCirclesLoader> createState() => _NeyvoPurpleCirclesLoaderState();
}

class _NeyvoPurpleCirclesLoaderState extends State<NeyvoPurpleCirclesLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = TenantBrand.primary(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.circleCount, (index) {
            final phase = (_controller.value + (index / widget.circleCount)) % 1.0;
            final pulse = 1.0 - ((phase - 0.5).abs() * 2.0);
            final scale = 0.68 + (pulse * 0.42);
            final opacity = 0.45 + (pulse * 0.55);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.circleSize,
                    height: widget.circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
