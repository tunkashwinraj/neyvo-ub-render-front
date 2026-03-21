import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../theme/neyvo_theme.dart';

/// Simple skeleton card used while billing providers are loading.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised,
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        border: Border.all(color: NeyvoColors.ubLightBlue.withOpacity(0.25)),
      ),
      child: Shimmer.fromColors(
        baseColor: NeyvoColors.borderSubtle,
        highlightColor: NeyvoColors.ubLightBlue.withOpacity(0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SizedBox(height: 6),
            _ShimmerLine(height: 28),
            SizedBox(height: 12),
            _ShimmerLine(height: 14, width: 220),
            SizedBox(height: 10),
            _ShimmerLine(height: 14, width: 160),
          ],
        ),
      ),
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double height;
  final double? width;

  const _ShimmerLine({required this.height, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: NeyvoColors.borderSubtle,
        borderRadius: BorderRadius.circular(NeyvoRadius.sm),
      ),
    );
  }
}

