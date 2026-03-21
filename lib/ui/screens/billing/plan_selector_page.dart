import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/plan_selector_page_provider.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/billing/credits_info_icon.dart';

class PlanSelectorPage extends ConsumerStatefulWidget {
  const PlanSelectorPage({super.key});

  @override
  ConsumerState<PlanSelectorPage> createState() => _PlanSelectorPageState();
}

class _PlanSelectorPageState extends ConsumerState<PlanSelectorPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(planSelectorPageCtrlProvider.notifier).load();
    });
  }

  Future<void> _changePlan(String target) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final changed = await ref.read(planSelectorPageCtrlProvider.notifier).changePlan(target);
      if (!mounted) return;
      if (changed) {
        messenger.showSnackBar(
          SnackBar(content: Text('Subscription updated to ${target[0].toUpperCase()}${target.substring(1)}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update plan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(planSelectorPageCtrlProvider);
    if (s.loading && s.subscription == null) {
      return const Center(child: CircularProgressIndicator(color: NeyvoColors.teal));
    }
    if (s.error != null && s.subscription == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s.error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(planSelectorPageCtrlProvider.notifier).load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final tier = (s.subscription?['tier'] ?? s.subscription?['subscription_tier'] ?? 'free').toString().toLowerCase();

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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Subscription plans', style: NeyvoTextStyles.title.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    const CreditsInfoIcon(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the right plan for University of Bridgeport. Plans debit credits monthly from your wallet.',
                  style: NeyvoTextStyles.body,
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    final children = <Widget>[
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: isWide ? 16 : 0, bottom: isWide ? 0 : 16),
                          child: _planCard(
                            id: 'free',
                            name: 'Free',
                            creditsPerMonth: 0,
                            dollarsDisplay: '\$0',
                            tagline: 'Start experimenting with Neyvo.',
                            benefits: const [
                              '1 included line',
                              'Neutral Human voice only',
                              'Basic analytics',
                            ],
                            currentTier: tier,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: isWide ? 16 : 0, bottom: isWide ? 0 : 16),
                          child: _planCard(
                            id: 'pro',
                            name: 'Pro',
                            creditsPerMonth: 2900,
                            dollarsDisplay: '\$29 / mo',
                            tagline: 'Grow with more lines and better routing.',
                            benefits: const [
                              '3 included lines',
                              'Neutral & Natural Human tiers',
                              'Priority support',
                            ],
                            currentTier: tier,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _planCard(
                          id: 'business',
                          name: 'Business',
                          creditsPerMonth: 7900,
                          dollarsDisplay: '\$79 / mo',
                          tagline: 'Designed for UB-scale deployment.',
                          benefits: const [
                            '10 included lines',
                            'All voice tiers including Ultra Real Human',
                            'Per-operator voice tier control',
                            '20% credit bonus on top-ups',
                          ],
                          currentTier: tier,
                          highlighted: true,
                        ),
                      ),
                    ];
                    if (isWide) {
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
                    }
                    return Column(children: children);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _planCard({
    required String id,
    required String name,
    required int creditsPerMonth,
    required String dollarsDisplay,
    required String tagline,
    required List<String> benefits,
    required String currentTier,
    bool highlighted = false,
  }) {
    final st = ref.watch(planSelectorPageCtrlProvider);
    final isCurrent = currentTier == id;
    final isUpdating = st.updatingTo == id;
    final creditsLine = creditsPerMonth == 0
        ? '0 credits / mo'
        : '${formatCredits(creditsPerMonth)} credits / mo';

    return Card(
      color: highlighted ? NeyvoColors.bgRaised : NeyvoColors.bgBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCurrent ? NeyvoColors.teal : NeyvoColors.borderSubtle,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(name, style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                if (highlighted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: NeyvoColors.teal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Recommended', style: NeyvoTextStyles.label),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(creditsLine, style: NeyvoTextStyles.display.copyWith(color: NeyvoColors.teal)),
            const SizedBox(height: 4),
            Text(dollarsDisplay, style: NeyvoTextStyles.body),
            const SizedBox(height: 4),
            Text(tagline, style: NeyvoTextStyles.body),
            const SizedBox(height: 12),
            ...benefits.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: NeyvoColors.teal),
                    const SizedBox(width: 6),
                    Expanded(child: Text(b, style: NeyvoTextStyles.body)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isCurrent || isUpdating ? null : () => _changePlan(id),
                style: FilledButton.styleFrom(
                  backgroundColor: isCurrent ? NeyvoColors.teal : Colors.transparent,
                  foregroundColor: isCurrent ? Colors.white : NeyvoColors.teal,
                  side: BorderSide(color: NeyvoColors.teal),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: isUpdating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isCurrent ? 'Current plan' : 'Select $name'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

