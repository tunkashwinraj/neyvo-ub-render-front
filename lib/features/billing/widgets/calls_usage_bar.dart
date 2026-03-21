import 'package:flutter/material.dart';

import '../../../theme/neyvo_theme.dart';

class CallsUsageBar extends StatelessWidget {
  final int used;
  final int limit;

  const CallsUsageBar({
    required this.used,
    required this.limit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = limit <= 0 ? 0.0 : used / limit;
    final progress = ratio.clamp(0.0, 1.0);

    final Color barColor;
    if (ratio < 0.7) {
      barColor = NeyvoColors.success; // green
    } else if (ratio < 0.9) {
      barColor = NeyvoColors.warning; // amber
    } else {
      barColor = NeyvoColors.error; // red
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised,
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$used of $limit calls used this month',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            color: barColor,
            backgroundColor: NeyvoColors.borderSubtle,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}

