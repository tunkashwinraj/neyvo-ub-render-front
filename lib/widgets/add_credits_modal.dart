// lib/widgets/add_credits_modal.dart
// Reusable Add Credits bottom sheet: packs + custom amount. Used by Wallet page and Settings → Billing.

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../utils/payment_pending_storage.dart';
import '../utils/stripe_launcher.dart';
import '../theme/neyvo_theme.dart';
import '../ui/components/billing/credits_info_icon.dart';

/// Shows the Add Credits modal. [wallet] is the billing/wallet map for bonus display.
/// [successUrl] and [cancelUrl] override redirect URLs (e.g. for Wallet vs Settings).
/// [onSuccess] is called after a successful purchase (e.g. to refresh data).
void showAddCreditsModal(
  BuildContext context, {
  Map<String, dynamic>? wallet,
  String? successUrl,
  String? cancelUrl,
  VoidCallback? onSuccess,
}) {
  final origin = Uri.base.origin;
  final success = successUrl ?? '$origin/pulse/wallet?payment=success';
  final cancel = cancelUrl ?? '$origin/pulse/wallet?payment=cancelled';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: NeyvoTheme.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _AddCreditsSheet(
      wallet: wallet,
      successUrl: success,
      cancelUrl: cancel,
      onSuccess: onSuccess,
    ),
  );
}

class _AddCreditsSheet extends StatefulWidget {
  const _AddCreditsSheet({
    required this.successUrl,
    required this.cancelUrl,
    this.wallet,
    this.onSuccess,
  });

  final Map<String, dynamic>? wallet;
  final String successUrl;
  final String cancelUrl;
  final VoidCallback? onSuccess;

  @override
  State<_AddCreditsSheet> createState() => _AddCreditsSheetState();
}

class _AddCreditsSheetState extends State<_AddCreditsSheet> {
  bool _purchaseInProgress = false;

  int _bonused(int baseCredits) {
    final pct = (widget.wallet?['credit_bonus_pct'] as num?)?.toDouble() ?? 0.0;
    return (baseCredits * (1 + pct)).floor();
  }

  Future<void> _purchase(String pack, {double? amountDollars}) async {
    setState(() => _purchaseInProgress = true);
    try {
      final res = await NeyvoPulseApi.createCheckoutSession(
        pack,
        successUrl: widget.successUrl,
        cancelUrl: widget.cancelUrl,
        amountDollars: amountDollars,
      );
      final url = res['url'] as String?;
      if (url != null && url.isNotEmpty) {
        setPaymentPending(pack: pack, amountDollars: amountDollars);
        await openStripeUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Opening Stripe Checkout. Complete payment there; credits will appear when you return.',
              ),
            ),
          );
        }
      } else {
        try {
          await NeyvoPulseApi.purchaseCredits(pack);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Credits added.')),
            );
            widget.onSuccess?.call();
          }
        } catch (e2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Purchase failed: $e2')),
            );
          }
        }
      }
    } catch (e) {
      final err = e.toString();
      if (mounted) {
        if (err.contains('Stripe') || err.contains('STRIPE')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stripe is not configured. Contact support to add credits.'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Purchase failed: $e')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _purchaseInProgress = false);
    }
  }

  String _formatCredits(int n) => n
      .toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final cpm = (widget.wallet?['credits_per_minute'] as num?)?.toInt() ?? 25;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scroll) => SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Add credits',
                  style: NeyvoType.headlineMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
                const SizedBox(width: 8),
                const CreditsInfoIcon(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll be redirected to Stripe to pay securely. Credits are applied with your plan bonus after payment.',
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            _packRow('Starter', 49, 5000, cpm, 'starter'),
            const SizedBox(height: 12),
            _packRow('Growth', 149, 16500, cpm, 'growth'),
            const SizedBox(height: 12),
            _packRow('Scale', 399, 50000, cpm, 'scale'),
            const SizedBox(height: 24),
            const Divider(color: NeyvoTheme.border),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Custom amount (\$20 – \$100,000)',
                  style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
                const SizedBox(width: 8),
                const CreditsInfoIcon(),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '\$1 = 100 credits.',
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            _CustomAmountRow(
              purchaseInProgress: _purchaseInProgress,
              onPurchase: (amount) => _purchase('starter', amountDollars: amount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _packRow(String name, int price, int baseCredits, int cpm, String packKey) {
    final totalCredits = _bonused(baseCredits);
    final bonusCredits = totalCredits - baseCredits;
    final approxMin = totalCredits ~/ cpm;
    final isGrowth = packKey == 'growth';
    return Container(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      decoration: BoxDecoration(
        color: NeyvoTheme.bgSurface,
        borderRadius: BorderRadius.circular(NeyvoRadius.md),
        border: Border.all(color: NeyvoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isGrowth)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: NeyvoTheme.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Most Popular',
                  style: NeyvoType.labelSmall.copyWith(
                    color: NeyvoTheme.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bonusCredits > 0
                          ? '${_formatCredits(totalCredits)} credits '
                              '(${_formatCredits(baseCredits)} base + ${_formatCredits(bonusCredits)} bonus)'
                          : '${_formatCredits(totalCredits)} credits',
                      style: NeyvoType.titleMedium.copyWith(
                        color: NeyvoTheme.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '~$approxMin min',
                      style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'One-time cost: \$$price',
                      style: NeyvoType.labelLarge.copyWith(
                        color: NeyvoTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _purchaseInProgress ? null : () => _purchase(packKey),
                style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.teal),
                child: Text('Purchase \$$price'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomAmountRow extends StatefulWidget {
  final bool purchaseInProgress;
  final void Function(double amountDollars) onPurchase;

  const _CustomAmountRow({
    required this.purchaseInProgress,
    required this.onPurchase,
  });

  @override
  State<_CustomAmountRow> createState() => _CustomAmountRowState();
}

class _CustomAmountRowState extends State<_CustomAmountRow> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _buttonLabel() {
    final v = double.tryParse(_controller.text.trim());
    if (v != null && v >= 20 && v <= 100000) {
      final int dollars = v.truncate();
      return dollars == v ? 'Purchase \$$dollars' : 'Purchase \$${v.toStringAsFixed(0)}';
    }
    return 'Purchase';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'e.g. 100',
              labelText: 'Amount (\$)',
              errorText: _error,
              filled: true,
              fillColor: NeyvoTheme.bgCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NeyvoRadius.md),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: NeyvoTheme.border),
                borderRadius: BorderRadius.circular(NeyvoRadius.md),
              ),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: widget.purchaseInProgress
              ? null
              : () {
                  final v = double.tryParse(_controller.text.trim());
                  if (v == null || v < 20 || v > 100000) {
                    setState(() => _error = 'Enter \$20 – \$100,000');
                    return;
                  }
                  widget.onPurchase(v);
                },
          style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.teal),
          child: Text(_buttonLabel()),
        ),
      ],
    );
  }
}
