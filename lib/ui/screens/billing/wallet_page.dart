// lib/ui/screens/billing/wallet_page.dart
// Wallet: balance overview and transactions list with optional link to call detail.

import 'package:flutter/material.dart';

import '../../../neyvo_pulse_api.dart';
import '../../../pulse_route_names.dart';
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

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _transactions = [];
  int _offset = 0;
  static const int _pageSize = 30;
  String _typeFilter = 'all'; // all | credit | debit
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
          if (mounted) _load();
        });
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
    });
    try {
      final results = await Future.wait([
        NeyvoPulseApi.getBillingWallet(),
        NeyvoPulseApi.getBillingTransactions(limit: _pageSize, offset: 0, type: _typeFilter),
      ]);
      if (!mounted) return;
      final txRes = results[1] as Map<String, dynamic>;
      final list = txRes['transactions'] as List<dynamic>?;
      setState(() {
        _wallet = results[0] as Map<String, dynamic>;
        _transactions = list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _transactions.length < _offset + _pageSize) return;
    setState(() => _loadingMore = true);
    try {
      final nextOffset = _offset + _pageSize;
      final res = await NeyvoPulseApi.getBillingTransactions(limit: _pageSize, offset: nextOffset, type: _typeFilter);
      final list = (res['transactions'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      if (!mounted) return;
      setState(() {
        _transactions.addAll(list);
        _offset = nextOffset;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _onTypeFilterChanged(String type) async {
    if (_typeFilter == type) return;
    setState(() {
      _typeFilter = type;
      _loading = true;
      _offset = 0;
    });
    try {
      final res = await NeyvoPulseApi.getBillingTransactions(limit: _pageSize, offset: 0, type: type);
      final list = (res['transactions'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      if (!mounted) return;
      setState(() {
        _transactions = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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
      if (mounted) _load();
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
    if (_loading && _wallet == null) {
      return const Center(child: CircularProgressIndicator(color: NeyvoColors.teal));
    }
    if (_error != null && _wallet == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final credits = (_wallet?['credits'] as num?)?.toInt() ?? (_wallet?['wallet_credits'] as num?)?.toInt() ?? 0;

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
                            Icon(Icons.record_voice_over_outlined, size: 18, color: NeyvoColors.teal),
                            const SizedBox(width: 6),
                            Text('View voice tiers', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.teal)),
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
                            Icon(Icons.card_membership_outlined, size: 18, color: NeyvoColors.teal),
                            const SizedBox(width: 6),
                            Text('View plans', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.teal)),
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
                      onPressed: _load,
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
                          onPressed: () => showAddCreditsModal(context, wallet: _wallet, onSuccess: _load),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Add credits'),
                          style: FilledButton.styleFrom(
                            backgroundColor: NeyvoColors.teal,
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
                  child: _loading && _transactions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator(color: NeyvoColors.teal)),
                        )
                      : _transactions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('No transactions yet.', style: NeyvoTextStyles.body),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _tableHeader(),
                                ..._transactions.map((t) => _transactionRow(t)),
                                if (_loadingMore)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.teal))),
                                  ),
                                if (!_loadingMore && _transactions.length >= _pageSize)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: TextButton(
                                      onPressed: _loadMore,
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
    final selected = _typeFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _onTypeFilterChanged(value),
      selectedColor: NeyvoColors.teal.withOpacity(0.3),
      checkmarkColor: NeyvoColors.teal,
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
          const SizedBox(width: 90),
        ],
      ),
    );
  }

  void _openBilling() async {
    await Navigator.of(context).pushNamed(PulseRouteNames.billing);
    if (mounted) _load();
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

  Widget _transactionRow(Map<String, dynamic> t) {
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
