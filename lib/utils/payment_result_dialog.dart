// Show a popup after returning from Stripe: success or declined/cancelled.
import 'package:flutter/material.dart';
import '../theme/neyvo_theme.dart';
import 'clear_payment_query.dart';

/// Optional details from sessionStorage (web) for success message: pack label, amount, or credits.
/// Keys: pack (String), amountDollars (num), credits (int).
typedef PaymentDetails = Map<String, dynamic>;

/// Shows an AlertDialog for payment result and clears ?payment= from URL (web).
/// [result] is the value of the `payment` query param: success, declined, cancelled, or null/other.
/// [paymentDetails] optional: when result is success, show "Your X payment (Y credits) has been added to your wallet."
Future<void> showPaymentResultDialogIfNeeded(
  BuildContext context,
  String? result, {
  Map<String, dynamic>? paymentDetails,
}) async {
  if (result == null || result.isEmpty) return;
  final normalized = result.toLowerCase();
  if (normalized != 'success' && normalized != 'declined' && normalized != 'cancelled' && normalized != 'canceled') return;

  if (!context.mounted) return;
  final title = normalized == 'success'
      ? 'Payment successful'
      : (normalized == 'cancelled' || normalized == 'canceled')
          ? 'Payment cancelled'
          : 'Payment declined';
  String message;
  if (normalized == 'success') {
    if (paymentDetails != null && paymentDetails.isNotEmpty) {
      final amountDollars = paymentDetails['amountDollars'];
      final pack = paymentDetails['pack'] as String?;
      final credits = paymentDetails['credits'];
      final x = amountDollars != null
          ? '\$${amountDollars is int ? amountDollars : (amountDollars as num).toStringAsFixed(0)}'
          : (pack ?? '');
      final y = credits != null ? '$credits credits' : 'credits';
      message = 'Your $x payment ($y) has been added to your wallet.';
    } else {
      message = 'Your credits have been added to your account.';
    }
  } else {
    message = (normalized == 'cancelled' || normalized == 'canceled')
        ? 'No credits were added. You can try again when ready.'
        : 'Payment was declined. No credits were added. Please try again or use a different payment method.';
  }
  final icon = normalized == 'success' ? Icons.check_circle_outline : Icons.info_outline;
  final color = normalized == 'success' ? NeyvoTheme.success : NeyvoTheme.warning;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 20)),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  clearPaymentQueryFromUrl();
}
