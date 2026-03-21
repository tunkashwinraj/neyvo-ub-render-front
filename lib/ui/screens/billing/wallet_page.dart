// lib/ui/screens/billing/wallet_page.dart
// Wallet: balance overview and transactions list with optional link to call detail.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/wallet_page_provider.dart';
import '../../../neyvo_pulse_api.dart';
import '../../../pulse_route_names.dart';
import '../../../screens/pulse_shell.dart';
import '../../../services/user_timezone_service.dart';
import '../../../theme/neyvo_theme.dart';
import '../../../utils/export_csv.dart';
import '../../../utils/payment_result_dialog.dart';
import '../../../utils/payment_pending_storage.dart';
import '../../components/billing/credits_info_icon.dart';
import '../../components/glass/neyvo_glass_panel.dart';
import '../../../screens/call_detail_page.dart';
import '../../../widgets/add_credits_modal.dart';
import 'plan_selector_page.dart';
import 'voice_tier_page.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletPageCtrlProvider.notifier).load();
      final payment = Uri.base.queryParameters['payment'];
      if (payment != null && payment.isNotEmpty) {
        Map<String, dynamic>? paymentDetails;
        if (payment.toLowerCase() == 'success') {
          paymentDetails = getPaymentPending();
          if (paymentDetails != null) {
            final amountDollars = paymentDetails['amountDollars'];
            if (amountDollars != null) {
              final dollars = amountDollars is int ? amountDollars.toDouble() : (amountDollars as num).toDouble();
              paymentDetails = Map<String, dynamic>.from(paymentDetails)..['credits'] = (dollars * 100).round();
            }
          }
          removePaymentPending();
        }
        showPaymentResultDialogIfNeeded(context, payment, paymentDetails: paymentDetails).then((_) {
          if (mounted) ref.read(walletPageCtrlProvider.notifier).load();
        });
      }
    });
  }

  void _openCallDetail(String callId) async {
    try {
      final res = await NeyvoPulseApi.getCallById(callId);
      if (!mounted) return;
      if (res['ok'] != true || res['call'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error']?.toString() ?? 'Call not found')),
        );
        return;
      }
      final call = Map<String, dynamic>.from(res['call'] as Map);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CallDetailPage(call: call),
        ),
      );
      if (mounted) ref.read(walletPageCtrlProvider.notifier).load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load call: $e')),
      );
    }
  }

  static String _formatDate(dynamic v) => UserTimezoneService.format(v);

  Future<void> _downloadTransactionsReport() async {
    try {
      final res = await NeyvoPulseApi.getBillingTransactions(limit: 2000, offset: 0, type: 'all');
      final list = (res['transactions'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final sb = StringBuffer();
      sb.writeln('Date,Type,Amount (credits),Amount (\$),Description,Call ID,Transaction type');
      for (final t in list) {
        final credits = (t['credits'] as num?)?.toInt() ?? 0;
        final dollarsVal = (t['dollars'] as num?)?.toDouble();
        final desc = (t['description'] ?? '').toString().replaceAll('"', '""');
        final type = (t['type'] ?? '').toString();
        final callId = (t['call_id'] ?? '').toString();
        final txnType = (t['transaction_type'] ?? type).toString();
        final dollars = dollarsVal != null && dollarsVal != 0
            ? dollarsVal.abs().toStringAsFixed(2)
            : (credits.abs() <= 0 ? '' : creditsToDollarsDisplay(credits.abs()));
        sb.writeln('${_formatDate(t['created_at'])},$type,$credits,"$dollars","$desc","$callId","$txnType"');
      }
      final date = DateTime.now().toIso8601String().substring(0, 10);
      if (!mounted) return;
      await downloadCsv('wallet_transactions_$date.csv', '\uFEFF${sb.toString()}', context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(walletPageCtrlProvider);
    final primary = Theme.of(context).colorScheme.primary;
    if (s.loading && s.wallet == null) {
      return Center(child: CircularProgressIndicator(color: primary));
    }
    if (s.error != null && s.wallet == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s.error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(walletPageCtrlProvider.notifier).load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final credits = (s.wallet?['credits'] as num?)?.toInt() ?? (s.wallet?['wallet_credits'] as num?)?.toInt() ?? 0;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('Wallet', style: NeyvoTextStyles.title.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          const CreditsInfoIcon(),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Voice tier'),
                              backgroundColor: NeyvoColors.bgBase,
                              foregroundColor: NeyvoColors.textPrimary,
                              leading: IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            body: const VoiceTierPage(),
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.record_voice_over_outlined, size: 18, color: primary),
                            const SizedBox(width: 6),
                            Text('View voice tiers', style: NeyvoTextStyles.label.copyWith(color: primary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Subscription plans'),
                              backgroundColor: NeyvoColors.bgBase,
                              foregroundColor: NeyvoColors.textPrimary,
                              leading: IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            body: const PlanSelectorPage(),
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.card_membership_outlined, size: 18, color: primary),
                            const SizedBox(width: 6),
                            Text('View plans', style: NeyvoTextStyles.label.copyWith(color: primary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _downloadTransactionsReport,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Download report'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => ref.read(walletPageCtrlProvider.notifier).load(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                NeyvoGlassPanel(
                  glowing: credits < 500,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$credits',
                                style: NeyvoTextStyles.heading.copyWith(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: NeyvoColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text('credits · Current balance', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => showAddCreditsModal(
                            context,
                            wallet: s.wallet,
                            onSuccess: () => ref.read(walletPageCtrlProvider.notifier).load(),
                          ),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Add credits'),
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Transactions', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _filterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _filterChip('Credits', 'credit'),
                    const SizedBox(width: 8),
                    _filterChip('Debits', 'debit'),
                  ],
                ),
                const SizedBox(height: 12),
                NeyvoGlassPanel(
                  child: s.loading && s.transactions.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator(color: primary)),
                        )
                      : s.transactions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('No transactions yet.', style: NeyvoTextStyles.body),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _tableHeader(),
                                ...s.transactions.asMap().entries.map((e) => _transactionRow(e.value, e.key, s)),
                                if (s.loadingMore)
                                  Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: primary))),
                                  ),
                                if (!s.loadingMore && s.transactions.length >= WalletPageUiState.pageSize)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: TextButton(
                                      onPressed: () => ref.read(walletPageCtrlProvider.notifier).loadMore(),
                                      child: const Text('Load more'),
                                    ),
                                  ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final s = ref.watch(walletPageCtrlProvider);
    final selected = s.typeFilter == value;
    final primary = Theme.of(context).colorScheme.primary;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => ref.read(walletPageCtrlProvider.notifier).setTypeFilter(value),
      selectedColor: primary.withOpacity(0.3),
      checkmarkColor: primary,
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text('Date', style: NeyvoTextStyles.label)),
          SizedBox(width: 72, child: Text('Type', style: NeyvoTextStyles.label)),
          SizedBox(width: 100, child: Text('Amount', style: NeyvoTextStyles.label)),
          Expanded(child: Text('Reason', style: NeyvoTextStyles.label)),
          SizedBox(width: 90, child: Text('Last balance', style: NeyvoTextStyles.label)),
          const SizedBox(width: 90),
        ],
      ),
    );
  }

  /// Balance after this transaction (running balance). Uses API balance_after when present, else computed from current balance and list order (newest first).
  int _balanceAfterTransaction(int index, Map<String, dynamic> t, WalletPageUiState s) {
    final fromApi = t['balance_after'];
    if (fromApi != null) {
      if (fromApi is int) return fromApi;
      if (fromApi is num) return fromApi.toInt();
    }
    final currentCredits = (s.wallet != null
            ? (s.wallet!['credits'] as num?)?.toInt() ?? (s.wallet!['wallet_credits'] as num?)?.toInt()
            : null) ??
        0;
    int sumAbove = 0;
    for (int i = 0; i < index; i++) {
      final c = s.transactions[i]['credits'] as num?;
      sumAbove += (c?.toInt() ?? 0);
    }
    return currentCredits - sumAbove;
  }

  /// Last balance = balance before this transaction (before its credit/debit was applied). Not the current balance.
  int _balanceBeforeTransaction(int index, Map<String, dynamic> t, WalletPageUiState s) {
    final after = _balanceAfterTransaction(index, t, s);
    final credits = (t['credits'] as num?)?.toInt() ?? (t['amount'] as num?)?.toInt() ?? 0;
    return after - credits;
  }

  void _openBilling() {
    PulseShellController.navigatePulse(context, PulseRouteNames.billing);
    if (mounted) ref.read(walletPageCtrlProvider.notifier).load();
  }

  static String _typeDisplay(String type) {
    switch (type) {
      case 'purchase':
        return 'Credit';
      case 'bonus':
      case 'welcome_bonus':
        return 'Bonus';
      case 'subscription_plan':
        return 'Plan';
      case 'addon_deduction':
        return 'Add-on';
      case 'debit':
        return 'Debit';
      case 'manual_adjustment':
        return 'Adjustment';
      default:
        return type.isEmpty ? '—' : type;
    }
  }

  static String _defaultDescription(String type, Map<String, dynamic> t) {
    switch (type) {
      case 'purchase':
        final pack = (t['pack_name'] ?? '').toString();
        return pack.isNotEmpty ? 'Wallet credit purchase ($pack)' : 'Wallet credit purchase';
      case 'subscription_plan':
        return 'Subscription plan';
      case 'addon_deduction':
        return 'Add-on deduction';
      case 'bonus':
      case 'welcome_bonus':
        return 'Bonus credits';
      case 'manual_adjustment':
        return 'Manual adjustment';
      default:
        return '—';
    }
  }

  Widget _transactionRow(Map<String, dynamic> t, int index, WalletPageUiState s) {
    final type = (t['type'] ?? '').toString().toLowerCase();
    final creditsVal = (t['credits'] as num?)?.toInt() ?? (t['amount'] as num?)?.toInt() ?? 0;
    final isCredit = creditsVal >= 0;
    final callId = (t['call_id'] ?? '').toString().trim();
    final durationMinutes = (t['duration_minutes'] as num?)?.toDouble();
    final creditsCharged = (t['credits_charged'] as num?)?.toInt();
    final hasCallDetail = callId.isNotEmpty && durationMinutes != null && creditsCharged != null;
    final rawDesc = (t['description'] ?? '').toString().trim();
    final desc = hasCallDetail
        ? 'Call · ${durationMinutes.toStringAsFixed(1)} min · $creditsCharged credits'
        : (rawDesc.isNotEmpty ? rawDesc : _defaultDescription(type, t));
    final createdAt = t['created_at'];

    final bool isCallDebit = callId.isNotEmpty;
    final bool isSubscription = type == 'subscription_plan' || desc.toLowerCase().contains('plan');
    final bool canGoToBilling = !isCallDebit &&
        (type == 'credit' ||
            type == 'debit' ||
            type == 'purchase' ||
            type == 'welcome_bonus' ||
            type == 'addon_deduction' ||
            isSubscription ||
            type.isEmpty);

    return InkWell(
      onTap: isCallDebit
          ? () => _openCallDetail(callId)
          : canGoToBilling
              ? _openBilling
              : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: NeyvoColors.borderSubtle)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 100, child: Text(_formatDate(createdAt), style: NeyvoTextStyles.micro)),
            SizedBox(
              width: 72,
              child: Text(
                _typeDisplay(type),
                style: NeyvoTextStyles.body.copyWith(
                  color: isCredit ? NeyvoColors.success : NeyvoColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${isCredit ? '+' : ''}$creditsVal credits',
                    style: NeyvoTextStyles.body.copyWith(
                      color: isCredit ? NeyvoColors.success : NeyvoColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '(${creditsToDollarsDisplay(creditsVal.abs())})',
                    style: NeyvoTextStyles.micro.copyWith(
                      color: NeyvoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(desc, style: NeyvoTextStyles.body, overflow: TextOverflow.ellipsis, maxLines: 2),
            ),
            SizedBox(
              width: 90,
              child: Text(
                '${_balanceBeforeTransaction(index, t, s)} credits',
                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
              ),
            ),
            SizedBox(
              width: 90,
              child: isCallDebit
                  ? TextButton(
                      onPressed: () => _openCallDetail(callId),
                      child: const Text('View call'),
                    )
                  : canGoToBilling
                      ? TextButton(
                          onPressed: _openBilling,
                          child: Text(isSubscription ? 'View plan' : 'View in Billing'),
                        )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
