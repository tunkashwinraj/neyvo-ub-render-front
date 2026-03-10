// lib/widgets/upgrade_nudge_widget.dart
// Reusable upgrade prompt for locked features.

import 'package:flutter/material.dart';

class UpgradeNudge extends StatelessWidget {
  final String message;
  final String? ctaLabel;
  final VoidCallback? onUpgrade;

  const UpgradeNudge({
    super.key,
    required this.message,
    this.ctaLabel,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1AFFC107),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x59FFC107)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 13,
              ),
            ),
          ),
          if (onUpgrade != null)
            TextButton(
              onPressed: onUpgrade,
              child: Text(
                ctaLabel ?? 'Upgrade',
                style: const TextStyle(color: Colors.teal),
              ),
            ),
        ],
      ),
    );
  }
}

