import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/neyvo_theme.dart';

class CreditBalanceCard extends StatelessWidget {
  final double balance;
  final String planName;

  const CreditBalanceCard({
    required this.balance,
    required this.planName,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final accent = NeyvoColors.ubLightBlue;
    final currency = NumberFormat.simpleCurrency().format(balance);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised,
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        border: Border.all(color: accent.withOpacity(0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currency,
            style: NeyvoTextStyles.display.copyWith(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: NeyvoTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Current plan: $planName',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

