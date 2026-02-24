// lib/screens/plan_selector_page.dart
// Subscription plan selector: Free / Pro ($29/mo) / Business ($79/mo).
// Accessible from Settings → Subscription Plan and Upgrade CTAs. Calls POST/GET/PUT billing subscription APIs.

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../theme/neyvo_theme.dart';

class PlanSelectorPage extends StatefulWidget {
  const PlanSelectorPage({super.key});

  @override
  State<PlanSelectorPage> createState() => _PlanSelectorPageState();
}

class _PlanSelectorPageState extends State<PlanSelectorPage> {
  Map<String, dynamic>? _subscription;
  bool _loading = true;
  String? _error;
  String? _actionPlan;

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
      final sub = await NeyvoPulseApi.getSubscription();
      if (mounted) setState(() {
        _subscription = sub;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String get _currentTier {
    final t = (_subscription?['tier'] as String?)?.toLowerCase() ?? 'free';
    return t == 'pro' || t == 'business' ? t : 'free';
  }

  Future<void> _selectPlan(String plan) async {
    if (_actionPlan != null) return;
    setState(() => _actionPlan = plan);
    try {
      if (plan == 'free') {
        final end = _subscription?['end'] as String?;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Downgrade to Free'),
            content: Text(
              end != null
                  ? 'Your current plan features remain active until $end. After that you will be on the Free plan.'
                  : 'Your current plan will cancel at the end of the billing period. You will then be on the Free plan.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
            ],
          ),
        );
        if (ok != true || !mounted) {
          setState(() => _actionPlan = null);
          return;
        }
        await NeyvoPulseApi.cancelSubscription();
      } else if (_currentTier == 'free') {
        await NeyvoPulseApi.subscribe(plan);
      } else {
        await NeyvoPulseApi.upgradeSubscription(plan);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Plan updated to ${plan == 'free' ? 'Free' : plan == 'pro' ? 'Pro' : 'Business'}')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _actionPlan = null);
    }
  }

  static const List<String> _freeFeatures = [
    'Basic logs only',
    '1 phone number',
    'Neutral Human voice only',
  ];
  static const List<String> _proFeatures = [
    'All 3 voice tiers',
    'Up to 3 phone numbers',
    'Outcome analytics',
    'Call memory',
    'Campaign scheduling',
    'API access',
    '+10% credit bonus on every top-up',
  ];
  static const List<String> _businessFeatures = [
    'Everything in Pro',
    'Up to 10 phone numbers',
    'HIPAA included',
    'White-label',
    'Slack support',
    'Multi-org',
    '+20% credit bonus on every top-up',
  ];

  @override
  Widget build(BuildContext context) {
    if (_loading && _subscription == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading plans…', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textMuted)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: NeyvoTheme.bgPrimary,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choose your plan', style: NeyvoType.headlineLarge.copyWith(color: NeyvoTheme.textPrimary)),
            const SizedBox(height: NeyvoSpacing.sm),
            Text(
              'Only wallet top-ups and monthly subscription charge your card. Everything else uses your credit wallet.',
              style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
            ),
            const SizedBox(height: NeyvoSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _planCard('free', 'Free', '\$0', 'No credit bonus', _freeFeatures, null, false)),
              const SizedBox(width: 16),
              Expanded(child: _planCard('pro', 'Pro', '\$29/mo', 'Get 10% more credits on every top-up. On the Growth pack (\$149), you get 18,150 credits instead of 16,500 — \$16.50 extra value free.', _proFeatures, 'Most Popular', true)),
              const SizedBox(width: 16),
              Expanded(child: _planCard('business', 'Business', '\$79/mo', 'Get 20% more credits on every top-up. On the Growth pack (\$149), you get 19,800 credits instead of 16,500 — \$33 extra value free.', _businessFeatures, null, false)),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _planCard(String planKey, String title, String price, String bonusText, List<String> features, String? badge, bool isPopular) {
    final isCurrent = _currentTier == planKey;
    final isPro = planKey == 'pro';
    final isBusiness = planKey == 'business';
    final showBonus = isPro || isBusiness;

    return Card(
      color: NeyvoTheme.bgCard,
      elevation: isCurrent ? 4 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCurrent ? NeyvoTheme.teal : NeyvoTheme.border,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (badge != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: NeyvoTheme.teal.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge, style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.teal, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            Text(title, style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(price, style: NeyvoType.headlineMedium.copyWith(color: NeyvoTheme.teal)),
            if (showBonus) ...[
              const SizedBox(height: 12),
              Text(bonusText, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
            ],
            const SizedBox(height: 20),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20, color: NeyvoTheme.success),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f, style: NeyvoType.bodySmall)),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _actionPlan != null ? null : () => _selectPlan(planKey),
              style: FilledButton.styleFrom(
                backgroundColor: isCurrent ? NeyvoTheme.textMuted : (isPopular ? NeyvoTheme.teal : null),
              ),
              child: Text(
                _actionPlan == planKey ? 'Updating…' : isCurrent ? 'Current plan' : planKey == 'free' ? 'Downgrade' : 'Select plan',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
