import 'package:flutter/material.dart';

import '../../../neyvo_pulse_api.dart';
import '../../../pulse_route_names.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/glass/neyvo_glass_panel.dart';
import '../../../widgets/add_credits_modal.dart';

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
    if (_loading && _wallet == null) {
      return const Center(child: CircularProgressIndicator(color: NeyvoColors.teal));
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
    final monthlyCost = (_numbers?['monthly_number_cost'] ?? _numbers?['monthly_cost'])
            ?.toString() ??
        '\$0.00';
    final perNumber = numbers.isEmpty ? '—' : '\$1.15/mo';

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
                _sectionTitle('Wallet'),
                const SizedBox(height: 10),
                NeyvoGlassPanel(
                  glowing: credits < 500,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$credits credits', style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                            const SizedBox(height: 4),
                            Text('≈ $estMin minutes at current tier', style: NeyvoTextStyles.body),
                            if (burn != null) ...[
                              const SizedBox(height: 4),
                              Text('Burn rate (month to date): \$$burn', style: NeyvoTextStyles.micro),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 220,
                        child: FilledButton(
                          onPressed: _addCredits,
                          style: FilledButton.styleFrom(
                            backgroundColor: NeyvoColors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Add credits'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(PulseRouteNames.wallet),
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('View transactions'),
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
                                ] else
                                  Text(
                                    'Tier unlocks voice quality, outbound features, and credits bonuses.',
                                    style: NeyvoTextStyles.body,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 220,
                            child: FilledButton(
                              onPressed: () async {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Plan management is available in the backend subscription flow.')),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: NeyvoColors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Upgrade'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Voice tier'),
                const SizedBox(height: 10),
                NeyvoGlassPanel(
                  child: _VoiceTierBlock(
                    wallet: _wallet,
                    onTierChanged: _load,
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Numbers cost'),
                const SizedBox(height: 10),
                NeyvoGlassPanel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cost per number: $perNumber', style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                            const SizedBox(height: 4),
                            Text('Monthly total: $monthlyCost', style: NeyvoTextStyles.body),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 220,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed('/pulse/phone-numbers'),
                          style: FilledButton.styleFrom(
                            backgroundColor: NeyvoColors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Manage numbers'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Add-ons'),
                const SizedBox(height: 10),
                NeyvoGlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _addonTile(
                        title: 'HIPAA',
                        subtitle: 'Compliance-grade handling for covered workflows.',
                        comingSoon: true,
                      ),
                      const SizedBox(height: 10),
                      _addonTile(
                        title: 'Shield',
                        subtitle: 'Spam and fraud protection for numbers.',
                        comingSoon: true,
                      ),
                      const SizedBox(height: 10),
                      _addonTile(
                        title: 'Concurrency',
                        subtitle: 'Increase simultaneous call capacity.',
                        comingSoon: true,
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

  Widget _addonTile({
    required String title,
    required String subtitle,
    required bool comingSoon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    if (comingSoon)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: NeyvoColors.borderSubtle,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('Coming soon', style: NeyvoTextStyles.micro),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: NeyvoTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceTierBlock extends StatelessWidget {
  final Map<String, dynamic>? wallet;
  final VoidCallback onTierChanged;

  const _VoiceTierBlock({this.wallet, required this.onTierChanged});

  static const Map<String, String> _tierLabels = {
    'neutral': 'Neutral Human',
    'natural': 'Natural Human',
    'ultra': 'Ultra Real Human',
  };

  @override
  Widget build(BuildContext context) {
    final currentTier = (wallet?['voice_tier'] ?? wallet?['tier'] ?? 'neutral').toString().toLowerCase();
    final tierDisplay = (wallet?['tier_display'] ?? _tierLabels[currentTier] ?? 'Neutral Human').toString();
    final cpm = (wallet?['credits_per_minute'] as num?)?.toInt() ?? 25;
    final unlocked = (wallet?['unlocked_tiers'] as List<dynamic>?)?.map((e) => e.toString().toLowerCase()).toList() ?? ['neutral'];
    final canChange = unlocked.length > 1;

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
        if (canChange)
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              value: _tierLabels.containsKey(currentTier) ? currentTier : 'neutral',
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              dropdownColor: NeyvoColors.bgOverlay,
              items: [
                if (unlocked.contains('neutral'))
                  DropdownMenuItem(value: 'neutral', child: Text(_tierLabels['neutral']!, style: NeyvoTextStyles.body)),
                if (unlocked.contains('natural'))
                  DropdownMenuItem(value: 'natural', child: Text(_tierLabels['natural']!, style: NeyvoTextStyles.body)),
                if (unlocked.contains('ultra'))
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

