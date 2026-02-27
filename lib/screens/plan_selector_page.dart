// lib/screens/plan_selector_page.dart
// Subscription plan selector: Free / Pro ($29/mo) / Business ($79/mo).
// Accessible from Settings → Subscription Plan and upgrade CTAs.

import 'package:flutter/material.dart';

import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import '../theme/neyvo_theme.dart';

class PlanSelectorPage extends StatefulWidget {
  const PlanSelectorPage({super.key});

  @override
  State<PlanSelectorPage> createState() => _PlanSelectorPageState();
}

class _PlanSelectorPageState extends State<PlanSelectorPage> {
  SubscriptionPlan? _plan;
  bool _loading = true;
  String? _error;
  bool _updating = false;

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
      final p = await SubscriptionService.getCurrentPlan();
      if (!mounted) return;
      setState(() {
        _plan = p;
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

  Future<void> _changePlan(String tier) async {
    if (_plan?.tier == tier) return;
    setState(() => _updating = true);
    try {
      await SubscriptionService.upgradePlan(tier);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan updated to ${tier.toUpperCase()}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update plan: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscription')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Unable to load plan.',
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final plan = _plan!;
    final children = [
      _PlanCard.free(
        currentTier: plan.tier,
        onSelect: () => _changePlan('free'),
        updating: _updating,
      ),
      _PlanCard.pro(
        currentTier: plan.tier,
        onSelect: () => _changePlan('pro'),
        updating: _updating,
      ),
      _PlanCard.business(
        currentTier: plan.tier,
        onSelect: () => _changePlan('business'),
        updating: _updating,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your plan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 800;
            if (isNarrow) {
              return ListView(
                children: [
                  for (final c in children) ...[
                    c,
                    const SizedBox(height: 16),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: 16),
                Expanded(child: children[1]),
                const SizedBox(width: 16),
                Expanded(child: children[2]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String tier;
  final String price;
  final String description;
  final List<String> bullets;
  final String currentTier;
  final VoidCallback onSelect;
  final bool highlight;
  final bool updating;

  const _PlanCard({
    required this.name,
    required this.tier,
    required this.price,
    required this.description,
    required this.bullets,
    required this.currentTier,
    required this.onSelect,
    required this.highlight,
    required this.updating,
  });

  factory _PlanCard.free({
    required String currentTier,
    required VoidCallback onSelect,
    required bool updating,
  }) {
    return _PlanCard(
      name: 'Free',
      tier: 'free',
      price: '\$0 / month',
      description: 'Start with 1 voice profile and 1 number.',
      bullets: const [
        '1 managed voice profile',
        '1 phone number',
        'Neutral Human voice',
        'Inbound calls',
        'Basic call logs',
        'Locked: Natural & Ultra voices',
        'Locked: Outbound calls',
        'Locked: AI Studio',
      ],
      currentTier: currentTier,
      onSelect: onSelect,
      highlight: false,
      updating: updating,
    );
  }

  factory _PlanCard.pro({
    required String currentTier,
    required VoidCallback onSelect,
    required bool updating,
  }) {
    return _PlanCard(
      name: 'Pro',
      tier: 'pro',
      price: '\$29 / month',
      description: 'Most popular — richer voices and more profiles.',
      bullets: const [
        'Up to 5 voice profiles',
        'Up to 3 phone numbers',
        'Neutral, Natural & Ultra Human voices',
        'Inbound + outbound calls',
        'AI Studio',
        'Campaign scheduling',
        'Full call analytics',
        '+10% bonus credits on every top-up',
      ],
      currentTier: currentTier,
      onSelect: onSelect,
      highlight: true,
      updating: updating,
    );
  }

  factory _PlanCard.business({
    required String currentTier,
    required VoidCallback onSelect,
    required bool updating,
  }) {
    return _PlanCard(
      name: 'Business',
      tier: 'business',
      price: '\$79 / month',
      description: 'Scale with HIPAA, white-label, and more seats.',
      bullets: const [
        'Up to 20 voice profiles',
        'Up to 10 phone numbers',
        'All 3 voice tiers',
        'Everything in Pro',
        'HIPAA mode included',
        'White-label & agency access',
        '+20% bonus credits on every top-up',
      ],
      currentTier: currentTier,
      onSelect: onSelect,
      highlight: false,
      updating: updating,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = currentTier == tier;
    final borderColor =
        isCurrent ? NeyvoTheme.primary : NeyvoTheme.border;
    final bgColor = NeyvoTheme.bgCard;
    return Card(
      elevation: highlight ? 4 : 1,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: NeyvoType.titleLarge
                      .copyWith(color: NeyvoTheme.textPrimary),
                ),
                if (highlight) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: NeyvoTheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Most Popular',
                      style: NeyvoType.bodySmall.copyWith(
                        color: NeyvoTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: NeyvoType.titleLarge
                  .copyWith(color: NeyvoTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: NeyvoType.bodySmall
                  .copyWith(color: NeyvoTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final b in bullets) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(color: NeyvoTheme.textPrimary)),
                  Expanded(
                    child: Text(
                      b,
                      style: NeyvoType.bodySmall
                          .copyWith(color: NeyvoTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isCurrent || updating ? null : onSelect,
                child: updating && !isCurrent
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isCurrent ? 'Current plan' : 'Switch to $name',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
