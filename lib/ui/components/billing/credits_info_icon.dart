// lib/ui/components/billing/credits_info_icon.dart
// Reusable info icon explaining $1 = 100 credits. Use on Wallet, Billing, Plan Selector, Voice Tier, Add Credits.

import 'package:flutter/material.dart';

import '../../../theme/neyvo_theme.dart';

/// Conversion: $1 = 100 credits. Use for formatting and display.
const int creditsPerDollar = 100;

/// Tooltip message shown when user hovers over the credits info icon.
const String creditsInfoTooltip = r'$1 = 100 credits. All billing is in credits.';

/// Formats an integer credit amount with comma thousands (e.g. 2900 -> "2,900").
String formatCredits(int credits) {
  return credits
      .toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

/// Converts credits to dollars for display (credits / 100).
String creditsToDollarsDisplay(int credits) {
  final dollars = credits / creditsPerDollar;
  if (dollars >= 1 && dollars == dollars.roundToDouble()) {
    return '\$${dollars.toInt()}';
  }
  return '\$${dollars.toStringAsFixed(2)}';
}

/// Small info icon with tooltip: "$1 = 100 credits. All billing is in credits."
/// Place next to section titles or balance/price headings on Wallet, Billing, Plan Selector, Voice Tier, Add Credits.
class CreditsInfoIcon extends StatelessWidget {
  const CreditsInfoIcon({
    super.key,
    this.size = 18,
    this.iconColor,
  });

  final double size;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: creditsInfoTooltip,
      child: Icon(
        Icons.info_outline,
        size: size,
        color: iconColor ?? NeyvoColors.textSecondary,
      ),
    );
  }
}
