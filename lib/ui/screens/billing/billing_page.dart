import 'package:flutter/material.dart';

import '../../../neyvo_pulse_api.dart';
import '../../../pulse_route_names.dart';
import '../../../screens/pulse_shell.dart';
import '../../../theme/neyvo_theme.dart';
import '../../../tenant/tenant_brand.dart';
import '../../../utils/payment_result_dialog.dart';
import '../../../utils/payment_pending_storage.dart';
import '../../components/billing/credits_info_icon.dart';
import '../../components/glass/neyvo_glass_panel.dart';
import '../../../widgets/add_credits_modal.dart';
import 'plan_selector_page.dart';
import 'voice_tier_page.dart';
import 'wallet_page.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _usage;
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _numbers;

  @override
  void initState() {
    super.initState();
    _load();
    _maybeShowPaymentResult();
  }

  void _maybeShowPaymentResult() {
    final payment = Uri.base.queryParameters['payment'];
    if (payment == null || payment.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
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
      await showPaymentResultDialogIfNeeded(context, payment, paymentDetails: paymentDetails);
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      final fromStr =
          '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
      final toStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final results = await Future.wait([
        NeyvoPulseApi.getBillingWallet(),
        NeyvoPulseApi.getBillingUsage(from: fromStr, to: toStr),
        NeyvoPulseApi.getSubscription(),
        NeyvoPulseApi.listNumbers(),
      ]);
      if (!mounted) return;
      setState(() {
        _wallet = results[0] as Map<String, dynamic>;
        _usage = results[1] as Map<String, dynamic>;
        _subscription = results[2] as Map<String, dynamic>;
        _numbers = results[3] as Map<String, dynamic>;
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

  void _addCredits() {
    showAddCreditsModal(context, wallet: _wallet, onSuccess: _load);
  }

  @override
  Widget build(BuildContext context) {
    final primary = TenantBrand.primary(context);
    if (_loading && _wallet == null) {
      return Center(child: CircularProgressIndicator(color: primary));
    }
    if (_error != null) {
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

    final credits = (_wallet?['credits'] as num?)?.toInt() ??
        (_wallet?['wallet_credits'] as num?)?.toInt() ??
        0;
    final cpm = (_wallet?['credits_per_minute'] as num?)?.toInt() ?? 25;
    final estMin = cpm > 0 ? credits ~/ cpm : 0;
    final burn = (_usage?['total_dollars_spent'] as num?)?.toDouble();
    final tier = (_wallet?['subscription_tier'] ?? _subscription?['tier'] ?? 'free')
        .toString()
        .toLowerCase();

    final numbers = (_numbers?['numbers'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final totalNumbers = (_numbers?['total_numbers'] as num?)?.toInt() ?? numbers.length;
    final monthlyCost = (_numbers?['monthly_number_cost'] ?? _numbers?['monthly_cost'])
            ?.toString() ??
        '\$0.00';
    final perNumber = numbers.isEmpty ? '—' : '115 credits/mo (\$1.15)';

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
                      child: Text('Billing', style: NeyvoTextStyles.title.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _sectionTitle('Credits available'),
                    const SizedBox(width: 8),
                    const CreditsInfoIcon(),
                  ],
                ),
                const SizedBox(height: 10),
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
                              Text('credits', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary)),
                              const SizedBox(height: 12),
                              Text(
                                '≈ $estMin min at current tier',
                                style: NeyvoTextStyles.body.copyWith(
                                  color: NeyvoColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              if (burn != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Burn rate (MTD): \$${burn.toStringAsFixed(2)}',
                                  style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 200,
                              child: FilledButton.icon(
                                onPressed: _addCredits,
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text('Add credits'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 200,
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => Scaffold(
                                      appBar: AppBar(
                                        title: const Text('Transactions'),
                                        backgroundColor: NeyvoColors.bgBase,
                                        foregroundColor: NeyvoColors.textPrimary,
                                        leading: IconButton(
                                          icon: const Icon(Icons.arrow_back),
                                          onPressed: () => Navigator.of(context).pop(),
                                        ),
                                      ),
                                      body: const WalletPage(),
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                                label: const Text('View transactions'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primary,
                                  side: BorderSide(color: primary),
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Subscription'),
                const SizedBox(height: 10),
                NeyvoGlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tier == 'business' ? 'Business' : tier == 'pro' ? 'Pro' : 'Free',
                                  style: NeyvoTextStyles.heading.copyWith(fontSize: 18),
                                ),
                                const SizedBox(height: 6),
                                if (tier == 'business') ...[
                                  Text('• All voice tiers (Neutral, Natural, Ultra)', style: NeyvoTextStyles.body),
                                  Text('• 10 included numbers', style: NeyvoTextStyles.body),
                                  Text('• 20% credit bonus on purchases', style: NeyvoTextStyles.body),
                                  Text('• Per-operator voice tier', style: NeyvoTextStyles.body),
                                ] else if (tier == 'pro') ...[
                                  Text('• All voice tiers', style: NeyvoTextStyles.body),
                                  Text('• 3 included numbers', style: NeyvoTextStyles.body),
                                  Text('• 10% credit bonus on purchases', style: NeyvoTextStyles.body),
                                ] else
                                  Text(
                                    'Tier unlocks voice quality, outbound features, and credit bonuses.',
                                    style: NeyvoTextStyles.body,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 160,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).push(
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
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primary,
                                side: BorderSide(color: primary),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('View plans'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _sectionTitle('Voice tier'),
                    const SizedBox(width: 8),
                    const CreditsInfoIcon(),
                  ],
                ),
                const SizedBox(height: 10),
                NeyvoGlassPanel(
                  child: _VoiceTierBlock(
                    wallet: _wallet,
                    onTierChanged: _load,
                    onViewTiers: () => Navigator.of(context).push(
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
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Numbers'),
                const SizedBox(height: 10),
                NeyvoGlassPanel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (numbers.isEmpty) ...[
                              Text('No numbers yet', style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                              const SizedBox(height: 4),
                              Text('Add a number to get started. Manage numbers on the Lines page.', style: NeyvoTextStyles.body),
                            ] else ...[
                              Text('You have ${totalNumbers} number${totalNumbers == 1 ? '' : 's'}', style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                              const SizedBox(height: 4),
                              Text('Cost per number: $perNumber', style: NeyvoTextStyles.body),
                              const SizedBox(height: 2),
                              Text('Monthly total: $monthlyCost', style: NeyvoTextStyles.body),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 220,
                        child: FilledButton(
                          onPressed: () => PulseShellController.navigatePulse(context, PulseRouteNames.phoneNumbers),
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(numbers.isEmpty ? 'Add number' : 'Manage numbers'),
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

  Widget _sectionTitle(String text) {
    return Text(text, style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary));
  }
}

class _VoiceTierBlock extends StatelessWidget {
  final Map<String, dynamic>? wallet;
  final VoidCallback onTierChanged;
  final VoidCallback? onViewTiers;

  const _VoiceTierBlock({this.wallet, required this.onTierChanged, this.onViewTiers});

  static const Map<String, String> _tierLabels = {
    'neutral': 'Neutral Human',
    'natural': 'Natural Human',
    'ultra': 'Ultra Real Human',
  };

  @override
  Widget build(BuildContext context) {
    final currentTier = (wallet?['voice_tier'] ?? wallet?['tier'] ?? 'ultra').toString().toLowerCase();
    final tierDisplay = (wallet?['tier_display'] ?? _tierLabels[currentTier] ?? 'Ultra Real Human').toString();
    final cpm = (wallet?['credits_per_minute'] as num?)?.toInt() ?? 49;
    final unlocked = (wallet?['unlocked_tiers'] as List<dynamic>?)?.map((e) => e.toString().toLowerCase()).toList();
    final canChange = unlocked != null && unlocked.length > 1;
    final effectiveUnlocked = unlocked ?? ['neutral', 'natural', 'ultra'];

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tierDisplay, style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
              const SizedBox(height: 4),
              Text('$cpm credits/min', style: NeyvoTextStyles.body),
            ],
          ),
        ),
        if (onViewTiers != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: onViewTiers,
              child: const Text('View voice tiers'),
            ),
          ),
        if (canChange)
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              value: _tierLabels.containsKey(currentTier) ? currentTier : 'ultra',
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              dropdownColor: NeyvoColors.bgOverlay,
              items: [
                if (effectiveUnlocked.contains('neutral'))
                  DropdownMenuItem(value: 'neutral', child: Text(_tierLabels['neutral']!, style: NeyvoTextStyles.body)),
                if (effectiveUnlocked.contains('natural'))
                  DropdownMenuItem(value: 'natural', child: Text(_tierLabels['natural']!, style: NeyvoTextStyles.body)),
                if (effectiveUnlocked.contains('ultra'))
                  DropdownMenuItem(value: 'ultra', child: Text(_tierLabels['ultra']!, style: NeyvoTextStyles.body)),
              ],
              onChanged: (String? value) async {
                if (value == null || value == currentTier) return;
                try {
                  await NeyvoPulseApi.setBillingTier(value);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voice tier set to ${_tierLabels[value] ?? value}')));
                    onTierChanged();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
            ),
          ),
      ],
    );
  }
}

