import 'dart:ui';

import 'package:flutter/material.dart';

import '../../foundation/tokens/neyvo_tokens.dart';
import '../../../theme/neyvo_theme.dart';

/// NeyvoGlassPanel
///
/// Reusable glassmorphism container used across Voice OS surfaces:
/// - Home AI Command Center
/// - Launch wizard steps
/// - Live call overlays
class NeyvoGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final bool glowing;

  const NeyvoGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NeyvoSpacing.lg),
    this.borderRadius = const BorderRadius.all(Radius.circular(NeyvoRadius.lg)),
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: padding,
          decoration: BoxDecoration(
            color: NeyvoLayer.glass,
            borderRadius: borderRadius,
            border: Border.fromBorderSide(
              glowing ? NeyvoBorderTokens.glow : NeyvoBorderTokens.normal,
            ),
            boxShadow: glowing
                ? [
                    BoxShadow(
                      color: NeyvoAccent.primaryGlow,
                      blurRadius: 24,
                      spreadRadius: 0,
                    )
                  ]
                : const [],
          ),
          child: child,
        ),
      ),
    );
  }
}

