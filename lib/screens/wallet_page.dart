// lib/screens/wallet_page.dart
// Wallet: balance, ≈ X min at tier, low warning, Add Credits, last 5 transactions, links to Billing & Voice tier.

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../theme/neyvo_theme.dart';
import '../utils/payment_result_dialog.dart';
import '../widgets/neyvo_empty_state.dart';
import '../widgets/add_credits_modal.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _transactions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _checkPaymentResult();
  }

  void _checkPaymentResult() {
    try {
      final q = Uri.base.queryParameters;
      final payment = q['payment'];
      if (payment == null || payment.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showPaymentResultDialogIfNeeded(context, payment);
        if (mounted) _load();
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        NeyvoPulseApi.getBillingWallet(),
        NeyvoPulseApi.getBillingTransactions(limit: 10, offset: 0),
      ]);
      if (mounted) {
        setState(() {
          _wallet = results[0] as Map<String, dynamic>?;
          _transactions = results[1] as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _showPurchaseModal() {
    showAddCreditsModal(context, wallet: _wallet, onSuccess: _load);
  }

  String _tierDisplay(String tier) {
    switch (tier) {
      case 'neutral': return 'Neutral Human';
      case 'natural': return 'Natural Human';
      case 'ultra': return 'Ultra Real Human';
      default: return tier;
    }
  }

  static (Color, IconData) _txnStyle(String type) {
    switch (type) {
      case 'purchase': return (NeyvoTheme.success, Icons.account_balance_wallet_outlined);
      case 'debit': return (NeyvoTheme.error, Icons.phone_outlined);
      case 'bonus': return (NeyvoTheme.teal, Icons.star_outline);
      case 'addon_deduction': return (NeyvoTheme.warning, Icons.toggle_on_outlined);
      case 'manual_adjustment': return (NeyvoTheme.textTertiary, Icons.admin_panel_settings_outlined);
      case 'refund': return (NeyvoTheme.info, Icons.replay_outlined);
      default: return (NeyvoTheme.textSecondary, Icons.receipt_long_outlined);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _wallet == null) {
      return buildNeyvoLoadingState();
    }
    if (_error != null) {
      return buildNeyvoErrorState(onRetry: _load);
    }

    final credits = (_wallet?['wallet_credits'] as num?)?.toInt() ?? (_wallet?['credits'] as num?)?.toInt() ?? 0;
    final cpm = (_wallet?['credits_per_minute'] as num?)?.toInt() ?? 25;
    final voiceTier = (_wallet?['voice_tier'] as String?)?.toLowerCase() ?? 'neutral';
    final tierLabel = _tierDisplay(voiceTier);
    final estMin = cpm > 0 ? credits ~/ cpm : 0;
    final lowBalance = credits < 500;
    final criticalBalance = credits < 200;
    String fmt(int n) => n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    final list = _transactions?['transactions'] as List? ?? [];
    final lastFive = list.take(5).toList();

    return ListView(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      children: [
        if (lowBalance)
          Container(
            margin: const EdgeInsets.only(bottom: NeyvoSpacing.lg),
            padding: const EdgeInsets.all(NeyvoSpacing.md),
            decoration: BoxDecoration(
              color: criticalBalance ? NeyvoTheme.error.withOpacity(0.15) : NeyvoTheme.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(NeyvoRadius.md),
              border: Border.all(color: criticalBalance ? NeyvoTheme.error : NeyvoTheme.warning),
            ),
            child: Row(
              children: [
                Icon(criticalBalance ? Icons.warning_amber_rounded : Icons.info_outline, color: criticalBalance ? NeyvoTheme.error : NeyvoTheme.warning, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Low credits — $credits remaining. Top up to keep calling.',
                    style: NeyvoType.bodyMedium.copyWith(color: criticalBalance ? NeyvoTheme.error : NeyvoTheme.warning),
                  ),
                ),
                TextButton(onPressed: _showPurchaseModal, child: const Text('Add Credits')),
              ],
            ),
          ),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmt(credits), style: NeyvoType.displayLarge.copyWith(fontSize: 40, fontWeight: FontWeight.w700, color: NeyvoTheme.textPrimary)),
                Text('≈ $estMin min at $tierLabel', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary)),
                const SizedBox(height: NeyvoSpacing.lg),
                FilledButton.icon(
                  onPressed: _showPurchaseModal,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Credits'),
                  style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.teal, minimumSize: const Size(0, 40)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        Text('Recent transactions', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.sm),
        if (lastFive.isEmpty)
          Card(
            color: NeyvoTheme.bgCard,
            child: Padding(
              padding: const EdgeInsets.all(NeyvoSpacing.xl),
              child: Text('No transactions yet', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textTertiary)),
            ),
          )
        else
          Card(
            color: NeyvoTheme.bgCard,
            child: Column(
              children: [
                ...lastFive.map<Widget>((t) {
                  final type = t['type'] as String? ?? '';
                  final creditsVal = (t['credits'] as num?)?.toInt() ?? 0;
                  final (color, icon) = _txnStyle(type);
                  final date = t['created_at']?.toString() ?? '';
                  final desc = t['description']?.toString() ?? type;
                  final isDebit = type == 'debit' || creditsVal < 0;
                  return ListTile(
                    leading: Icon(isDebit ? Icons.call_made : Icons.add_circle_outline, color: isDebit ? NeyvoTheme.coral : NeyvoTheme.teal, size: 22),
                    title: Text(desc, style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary)),
                    subtitle: Text(date, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textTertiary)),
                    trailing: Text('${creditsVal >= 0 ? '+' : ''}$creditsVal', style: NeyvoType.bodyMedium.copyWith(color: color)),
                  );
                }),
                if (list.length > 5)
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, PulseRouteNames.settings),
                    icon: const Icon(Icons.settings),
                    label: const Text('View all in Settings → Billing'),
                  ),
              ],
            ),
          ),
        const SizedBox(height: NeyvoSpacing.xl),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(
            context,
            PulseRouteNames.settings,
            arguments: const {'tab': 'billing'},
          ),
          icon: const Icon(Icons.payment),
          label: const Text('Manage plan & billing'),
        ),
        const SizedBox(height: NeyvoSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(
            context,
            PulseRouteNames.settings,
            arguments: const {'tab': 'billing'},
          ),
          icon: const Icon(Icons.record_voice_over_outlined),
          label: const Text('Change voice tier (Settings → Billing)'),
        ),
      ],
    );
  }

}
