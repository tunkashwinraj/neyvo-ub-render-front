// lib/screens/billing_tab_content.dart
// Settings → Billing: 4 sub-tabs (Plan, Wallet, Voice Tier, Add-ons).
// Single billing area; no standalone Voice Tier or Add-ons in sidebar.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/spearia_api.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../theme/neyvo_theme.dart';
import '../widgets/add_credits_modal.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';

class BillingTabContent extends StatefulWidget {
  const BillingTabContent({super.key});

  @override
  State<BillingTabContent> createState() => _BillingTabContentState();
}

class _BillingTabContentState extends State<BillingTabContent>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _transactions;
  Map<String, dynamic>? _numbers;
  bool _loading = true;
  String? _error;
  String? _updatingTier;
  String? _playingTier;
  String? _updatingAddon;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        NeyvoPulseApi.getBillingWallet(),
        NeyvoPulseApi.getBillingTransactions(limit: 20, offset: 0),
        NeyvoPulseApi.listNumbers(),
        SubscriptionService.getCurrentPlan(),
      ]);
      if (mounted) {
        setState(() {
          _wallet = results[0] as Map<String, dynamic>?;
          _transactions = results[1] as Map<String, dynamic>?;
          _numbers = results[2] as Map<String, dynamic>?;
          _subscriptionPlan = results[3] as SubscriptionPlan;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String get _subTier =>
      (_wallet?['subscription_tier'] as String?)?.toLowerCase() ?? 'free';
  String get _currentVoiceTier =>
      (_wallet?['voice_tier'] as String?)?.toLowerCase() ?? 'neutral';
  List<String> get _unlockedTiers =>
      List<String>.from(_wallet?['unlocked_tiers'] as List? ?? ['neutral']);
  List<dynamic> get _numberList => _numbers?['numbers'] as List? ?? [];
  List<String> get _shieldNumberIds =>
      List<String>.from(_wallet?['addon_shield_numbers'] as List? ?? []);
  bool get _hipaaEnabled => _wallet?['addon_hipaa'] == true;

  int get _includedNumbers {
    if (_subTier == 'business') return 10;
    if (_subTier == 'pro') return 3;
    return 1;
  }

  int get _monthlyCreditsExtraNumbers =>
      (_numberList.length > _includedNumbers
          ? _numberList.length - _includedNumbers
          : 0) *
      115;
  int get _monthlyCreditsShield => _shieldNumberIds.length * 50;
  int get _monthlyCreditsHipaa => _subTier == 'business'
      ? 0
      : (_subTier == 'pro' && _hipaaEnabled ? 4900 : 0);
  int get _monthlyCreditsTotal =>
      _monthlyCreditsExtraNumbers + _monthlyCreditsShield + _monthlyCreditsHipaa;

  bool _changingPlan = false;
  SubscriptionPlan? _subscriptionPlan;

  void _showAddCreditsModal() {
    final origin = Uri.base.origin;
    showAddCreditsModal(
      context,
      wallet: _wallet,
      successUrl: '$origin/pulse/settings?payment=success',
      cancelUrl: '$origin/pulse/settings?payment=cancelled',
      onSuccess: _load,
    );
  }

  String _formatCredits(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  SubscriptionPlan? get _plan => _subscriptionPlan;

  Future<void> _setTier(String tier) async {
    if (_updatingTier != null) return;
    if (!_unlockedTiers.contains(tier)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Natural Human and Ultra Real Human require Pro or Business. Upgrade in Plan tab.')));
      return;
    }
    setState(() => _updatingTier = tier);
    try {
      await NeyvoPulseApi.setBillingTier(tier);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Voice tier set to ${_tierDisplay(tier)}')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        final err = e is ApiException ? e : null;
        final code = err?.statusCode;
        final payload = err?.payload;
        if (code == 403 &&
            payload is Map &&
            payload['error'] == 'voice_tier_locked') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  payload['message']?.toString() ?? 'Upgrade to Pro or Business to use this tier.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed: $e')));
        }
      }
    } finally {
      if (mounted) setState(() => _updatingTier = null);
    }
  }

  Future<void> _playTierSample(String tier) async {
    if (_playingTier != null) return;
    // Default sample voices (matches seeded library)
    final voice = switch (tier) {
      'neutral' => ('alloy', 'openai'),
      'natural' => ('rachel', 'elevenlabs'),
      'ultra' => ('rachel-ultra', 'elevenlabs'),
      _ => ('alloy', 'openai'),
    };
    setState(() => _playingTier = tier);
    try {
      final res = await NeyvoPulseApi.postVoicePreview(
        voiceId: voice.$1,
        provider: voice.$2,
        text: 'Hi! This is Neyvo. How can I help you today?',
      );
      if (!mounted) return;
      final url = res['audio_url'] as String?;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preview generated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _playingTier = null);
    }
  }

  String _tierDisplay(String tier) {
    switch (tier) {
      case 'neutral':
        return 'Neutral Human';
      case 'natural':
        return 'Natural Human';
      case 'ultra':
        return 'Ultra Real Human';
      default:
        return tier;
    }
  }

  Future<void> _toggleShield(String numberId, bool enabled) async {
    if (_updatingAddon != null) return;
    setState(() => _updatingAddon = numberId);
    try {
      await NeyvoPulseApi.setAddonShield(numberId: numberId, enabled: enabled);
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _updatingAddon = null);
    }
  }

  Future<void> _toggleHipaa(bool enabled) async {
    if (_updatingAddon != null || _subTier == 'free') return;
    setState(() => _updatingAddon = 'hipaa');
    try {
      await NeyvoPulseApi.setAddonHipaa(enabled: enabled);
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _updatingAddon = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _wallet == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!,
                style: NeyvoType.bodySmall
                    .copyWith(color: NeyvoTheme.error),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          labelColor: NeyvoTheme.teal,
          unselectedLabelColor: NeyvoTheme.textSecondary,
          indicatorColor: NeyvoTheme.teal,
          tabs: const [
            Tab(text: 'Plan'),
            Tab(text: 'Wallet'),
            Tab(text: 'Voice Tier'),
            Tab(text: 'Add-ons'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPlanTab(),
              _buildWalletTab(),
              _buildVoiceTierTab(),
              _buildAddonsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanTab() {
    final current = _subTier;
    return ListView(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      children: [
        Text('Subscription Plan',
            style: NeyvoType.headlineLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Unlock voice tiers and credit bonus. Billed monthly.',
          style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final cards = [
              _planCard('free', 'Free', '\$0/mo', const [
                '1 phone number',
                'Neutral Human voice only',
                'Pay-as-you-go credits',
              ], current == 'free', false),
              _planCard('pro', 'Pro', '\$29/mo', const [
                '3 phone numbers',
                'All voice tiers (Neutral, Natural, Ultra)',
                '10% credit bonus on top-up',
                'HIPAA add-on available',
              ], current == 'pro', true),
              _planCard('business', 'Business', '\$99/mo', const [
                '10 phone numbers',
                'All voice tiers',
                '20% credit bonus',
                'HIPAA included',
              ], current == 'business', false),
            ];
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: NeyvoSpacing.lg),
                  Expanded(child: cards[1]),
                  const SizedBox(width: NeyvoSpacing.lg),
                  Expanded(child: cards[2]),
                ],
              );
            }
            return Column(
              children: [
                cards[0],
                const SizedBox(height: NeyvoSpacing.lg),
                cards[1],
                const SizedBox(height: NeyvoSpacing.lg),
                cards[2],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _planCard(
      String key, String name, String price, List<String> features, bool current, bool popular) {
    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        side: BorderSide(
            color: current ? NeyvoTheme.teal : NeyvoTheme.border,
            width: current ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (popular)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NeyvoTheme.teal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('Most Popular',
                      style: NeyvoType.labelSmall.copyWith(
                          color: NeyvoTheme.teal, fontWeight: FontWeight.w600)),
                ),
              ),
            Text(name, style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(price, style: NeyvoType.headlineMedium.copyWith(color: NeyvoTheme.teal)),
            const SizedBox(height: 4),
            Text(
              key == 'free'
                  ? 'Pay-as-you-go credits at standard rate.'
                  : key == 'pro'
                      ? 'Includes credit bonus on every top-up (≈10% more credits).'
                      : 'Includes highest credit bonus on every top-up (≈20% more credits).',
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 18, color: NeyvoTheme.teal),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(f,
                              style: NeyvoType.bodySmall
                                  .copyWith(color: NeyvoTheme.textPrimary))),
                    ],
                  ),
                )),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: current
                  ? OutlinedButton(
                      onPressed: null,
                      child: const Text('Current plan'),
                    )
                  : FilledButton(
                      onPressed: _changingPlan ? null : () => _changePlan(key, name),
                      style: FilledButton.styleFrom(backgroundColor: NeyvoTheme.teal),
                      child: Text('Upgrade to $name'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePlan(String planKey, String displayName) async {
    if (_changingPlan) return;
    final current = _subTier;
    if (planKey == current) return;
    setState(() => _changingPlan = true);
    try {
      if (planKey == 'free') {
        await NeyvoPulseApi.cancelSubscription();
      } else if (current == 'free') {
        await NeyvoPulseApi.subscribe(planKey);
      } else {
        await NeyvoPulseApi.upgradeSubscription(planKey);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan updated to ${displayName}')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _changingPlan = false);
    }
  }

  Widget _buildWalletTab() {
    final credits = (_wallet?['wallet_credits'] as num?)?.toInt() ??
        (_wallet?['credits'] as num?)?.toInt() ??
        0;
    final cpm = (_wallet?['credits_per_minute'] as num?)?.toInt() ?? 25;
    final estMin = cpm > 0 ? credits ~/ cpm : 0;
    final plan = _plan;
    final tierLabel = _tierDisplay(_currentVoiceTier);
    final lowBalance = credits < 500;

    return ListView(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      children: [
        if (lowBalance)
          Container(
            margin: const EdgeInsets.only(bottom: NeyvoSpacing.lg),
            padding: const EdgeInsets.all(NeyvoSpacing.md),
            decoration: BoxDecoration(
              color: NeyvoTheme.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(NeyvoRadius.md),
              border: Border.all(color: NeyvoTheme.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: NeyvoTheme.warning, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Low balance — $credits credits left. Add credits to keep calling.',
                    style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.warning),
                  ),
                ),
                TextButton(
                    onPressed: _showAddCreditsModal, child: const Text('Add Credits')),
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
                Text(
                  _formatCredits(credits),
                  style: NeyvoType.displayLarge.copyWith(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: NeyvoTheme.textPrimary),
                ),
                Text(
                  'credits · ≈ $estMin min at $tierLabel',
                  style: NeyvoType.bodyMedium
                      .copyWith(color: NeyvoTheme.textSecondary),
                ),
                if (plan != null && plan.creditBonusPct > 0) ...[
                  const SizedBox(height: NeyvoSpacing.xs),
                  Text(
                    plan.isBusiness
                        ? '+20% bonus credits on every top-up'
                        : '+10% bonus credits on every top-up',
                    style: NeyvoType.bodySmall
                        .copyWith(color: NeyvoTheme.success),
                  ),
                ],
                const SizedBox(height: NeyvoSpacing.lg),
                FilledButton.icon(
                  onPressed: _showAddCreditsModal,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Credits'),
                  style: FilledButton.styleFrom(
                      backgroundColor: NeyvoTheme.teal,
                      minimumSize: const Size(0, 40)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        Text('Recent transactions',
            style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.sm),
        _buildTransactionList(5),
      ],
    );
  }

  Widget _buildTransactionList(int maxItems) {
    final list = _transactions?['transactions'] as List? ?? [];
    final show = list.take(maxItems).toList();
    if (show.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        decoration: BoxDecoration(
          color: NeyvoTheme.bgCard,
          borderRadius: BorderRadius.circular(NeyvoRadius.md),
          border: Border.all(color: NeyvoTheme.border),
        ),
        child: Text('No transactions yet',
            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textTertiary)),
      );
    }
    return Card(
      color: NeyvoTheme.bgCard,
      child: Column(
        children: [
          ...show.asMap().entries.map((e) {
            final t = e.value as Map<String, dynamic>;
            final type = t['type'] as String? ?? '';
            final creditsVal = (t['credits'] as num?)?.toInt() ?? 0;
            final date = t['created_at']?.toString() ?? '';
            final desc = t['description']?.toString() ?? type;
            final campaignName = t['campaign_name']?.toString();
            final isDebit = type == 'debit' || creditsVal < 0;
            return ListTile(
              leading: Icon(
                  isDebit ? Icons.call_made : Icons.add_circle_outline,
                  color: isDebit ? NeyvoTheme.coral : NeyvoTheme.teal,
                  size: 22),
              title: Text(desc,
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary)),
              subtitle: Text(
                  campaignName != null && campaignName.isNotEmpty ? '$campaignName · $date' : date,
                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textTertiary)),
              trailing: Text(
                  '${creditsVal >= 0 ? '+' : ''}$creditsVal',
                  style: NeyvoType.bodyMedium.copyWith(
                      color: isDebit ? NeyvoTheme.coral : NeyvoTheme.teal)),
            );
          }),
          if (list.length > maxItems)
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, PulseRouteNames.wallet),
              icon: const Icon(Icons.list),
              label: const Text('View all'),
            ),
        ],
      ),
    );
  }

  bool get _allowPerAgentVoiceTier =>
      _wallet?['allow_per_agent_voice_tier'] == true;
  bool get _isBusiness => _subTier == 'business';

  Future<void> _setPerAgentVoiceTierEnabled(bool enabled) async {
    if (!_isBusiness) return;
    setState(() => _updatingAddon = 'per_agent_voice');
    try {
      final updated = await NeyvoPulseApi.setBillingPerAgentVoiceTier(enabled);
      if (mounted) setState(() {
        _wallet = updated;
        _updatingAddon = null;
      });
    } catch (e) {
      if (mounted) setState(() => _updatingAddon = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: NeyvoTheme.error),
        );
      }
    }
  }

  Widget _buildVoiceTierTab() {
    final current = _currentVoiceTier;
    final isFree = _subTier == 'free';
    final unlocked = _unlockedTiers;

    return ListView(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      children: [
        if (isFree)
          Container(
            margin: const EdgeInsets.only(bottom: NeyvoSpacing.lg),
            padding: const EdgeInsets.all(NeyvoSpacing.md),
            decoration: BoxDecoration(
              color: NeyvoTheme.teal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(NeyvoRadius.md),
              border: Border.all(color: NeyvoTheme.teal.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: NeyvoTheme.teal, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Natural Human and Ultra Real Human require Pro or Business. Upgrade in Plan tab.',
                    style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                  ),
                ),
                TextButton(
                  onPressed: () => _tabController.animateTo(0),
                  child: const Text('Upgrade'),
                ),
              ],
            ),
          ),
        // Per-agent voice tier toggle (Business only)
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isBusiness ? Icons.tune : Icons.lock_outline,
                      size: 20,
                      color: _isBusiness ? NeyvoTheme.teal : NeyvoTheme.textTertiary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Different voice tier per agent',
                      style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                    ),
                    const Spacer(),
                    if (_isBusiness)
                      Switch(
                        value: _allowPerAgentVoiceTier,
                        onChanged: _updatingAddon == 'per_agent_voice'
                            ? null
                            : (v) => _setPerAgentVoiceTierEnabled(v),
                        activeColor: NeyvoTheme.teal,
                      )
                    else
                      Tooltip(
                        message: 'Available on Business plan',
                        child: Icon(Icons.lock, size: 20, color: NeyvoTheme.textTertiary),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isBusiness
                      ? 'When enabled, you can set a custom voice quality for each agent in the agent\'s configuration. Otherwise all agents use your account default above.'
                      : 'Only available on Business plan. Upgrade to set a different voice tier per agent.',
                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        Text('Voice quality',
            style: NeyvoType.headlineLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Pay per minute. No extra subscription. Set your account default below.',
          style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        _voiceTierCard('neutral', 25, 'Neutral Human', current, unlocked),
        const SizedBox(height: NeyvoSpacing.md),
        _voiceTierCard('natural', 35, 'Natural Human (Most Popular)', current, unlocked),
        const SizedBox(height: NeyvoSpacing.md),
        _voiceTierCard('ultra', 49, 'Ultra Real Human', current, unlocked),
      ],
    );
  }

  Widget _voiceTierCard(
      String tier, int creditsPerMin, String label, String current, List<String> unlocked) {
    final isSelected = current == tier;
    final isLocked = !unlocked.contains(tier);
    final isUpdating = _updatingTier == tier;

    return Card(
      color: NeyvoTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeyvoRadius.lg),
        side: BorderSide(
            color: isSelected ? NeyvoTheme.teal : NeyvoTheme.border,
            width: isSelected ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: NeyvoType.titleLarge
                          .copyWith(color: NeyvoTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text('$creditsPerMin credits/min',
                      style: NeyvoType.bodySmall
                          .copyWith(color: NeyvoTheme.textSecondary)),
                ],
              ),
            ),
            if (isLocked)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Upgrade to unlock',
                    style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textTertiary)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Play sample',
                    onPressed: (_playingTier == tier) ? null : () => _playTierSample(tier),
                    icon: _playingTier == tier
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_circle_outline),
                  ),
                  FilledButton(
                    onPressed: isUpdating ? null : () => _setTier(tier),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isSelected ? NeyvoTheme.teal : NeyvoTheme.teal.withOpacity(0.2),
                      foregroundColor: isSelected ? Colors.white : NeyvoTheme.teal,
                    ),
                    child: isUpdating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(isSelected ? 'Current default' : 'Set as Default'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddonsTab() {
    return ListView(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      children: [
        Text('Extra phone numbers',
            style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: 8),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Included: $_includedNumbers number${_includedNumbers == 1 ? '' : 's'} on your plan. Extra numbers: 115 credits/month each.',
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, PulseRouteNames.phoneNumbers),
                  icon: const Icon(Icons.add),
                  label: const Text('Manage numbers'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        Text('Neyvo Shield (Spam Protection)',
            style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: 8),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('50 credits/month per number. Spam flag monitoring.',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                if (_numberList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Add a phone number first.',
                        style: NeyvoType.bodySmall
                            .copyWith(color: NeyvoTheme.textTertiary)),
                  )
                else
                  ..._numberList.map<Widget>((n) {
                    final id = n['id'] as String? ?? n['number_id']?.toString() ?? '';
                    final phone = n['phone_number'] as String? ?? n['friendly_name']?.toString() ?? id;
                    final enabled = _shieldNumberIds.contains(id);
                    return SwitchListTile(
                      title: Text(phone,
                          style: NeyvoType.bodyMedium
                              .copyWith(color: NeyvoTheme.textPrimary)),
                      subtitle: const Text('50 credits/month per number'),
                      value: enabled,
                      onChanged: _updatingAddon != null
                          ? null
                          : (v) => _toggleShield(id, v),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        Text('HIPAA Compliance',
            style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: 8),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Required for healthcare and sensitive data.',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                const SizedBox(height: 12),
                if (_subTier == 'free')
                  ListTile(
                    title: const Text('Upgrade to Pro or Business to enable HIPAA'),
                    leading: Icon(Icons.lock_outline, color: NeyvoTheme.textTertiary),
                  )
                else if (_subTier == 'business')
                  const ListTile(
                    title: Text('Included in your Business plan'),
                    leading: Icon(Icons.check_circle_outline, color: NeyvoTheme.success),
                  )
                else
                  SwitchListTile(
                    title: const Text('Enable HIPAA Compliance'),
                    subtitle: const Text('4,900 credits/month (\$49.00)'),
                    value: _hipaaEnabled,
                    onChanged: _updatingAddon != null
                        ? null
                        : (v) => _toggleHipaa(v),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        Text('Monthly add-ons summary',
            style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: 8),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated add-ons: $_monthlyCreditsTotal credits (\$${(_monthlyCreditsTotal / 100).toStringAsFixed(2)})',
                  style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_monthlyCreditsExtraNumbers extra numbers + $_monthlyCreditsShield Shield + $_monthlyCreditsHipaa HIPAA',
                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
