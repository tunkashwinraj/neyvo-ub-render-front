import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/voice_tier_page_provider.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/billing/credits_info_icon.dart';
import '../../components/glass/neyvo_glass_panel.dart';
import 'plan_selector_page.dart';

class VoiceTierPage extends ConsumerStatefulWidget {
  const VoiceTierPage({super.key});

  @override
  ConsumerState<VoiceTierPage> createState() => _VoiceTierPageState();
}

class _VoiceTierPageState extends ConsumerState<VoiceTierPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceTierPageCtrlProvider.notifier).load();
    });
  }

  Future<void> _selectTier(String tier) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(voiceTierPageCtrlProvider.notifier).selectTier(tier);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Voice tier updated to ${_tierLabel(tier)}')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update tier: $e')),
      );
    }
  }

  String _tierLabel(String tier) {
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

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(voiceTierPageCtrlProvider);
    if (s.loading && s.wallet == null) {
      return const Center(child: CircularProgressIndicator(color: NeyvoColors.teal));
    }
    if (s.error != null && s.wallet == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s.error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(voiceTierPageCtrlProvider.notifier).load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final wallet = s.wallet ?? const <String, dynamic>{};
    final subscriptionTier = (wallet['subscription_tier'] ?? 'free').toString().toLowerCase();
    final currentTier = (wallet['voice_tier'] ?? wallet['tier'] ?? 'ultra').toString().toLowerCase();
    final unlocked = (wallet['unlocked_tiers'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        const ['neutral', 'natural', 'ultra'];
    final isFree = subscriptionTier == 'free';

    final tiers = const [
      {'id': 'neutral', 'name': 'Neutral Human', 'cpm': 25, 'usd': 0.25},
      {'id': 'natural', 'name': 'Natural Human', 'cpm': 35, 'usd': 0.35},
      {'id': 'ultra', 'name': 'Ultra Real Human', 'cpm': 49, 'usd': 0.49},
    ];

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
                    Text('Voice tier', style: NeyvoTextStyles.title.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    const CreditsInfoIcon(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the voice quality for all operators. Billed per minute from your wallet.',
                  style: NeyvoTextStyles.body,
                ),
                const SizedBox(height: 20),
                if (isFree)
                  NeyvoGlassPanel(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: NeyvoColors.teal, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upgrade to Business to unlock Natural and Ultra Real Human tiers.',
                                style: NeyvoTextStyles.bodyPrimary,
                              ),
                              const SizedBox(height: 6),
                              TextButton(
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
                                child: const Text('View plans'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    final children = tiers
                        .map(
                          (t) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: isWide && t['id'] != 'ultra' ? 16 : 0, bottom: isWide ? 0 : 16),
                              child: _tierCard(
                                id: t['id'] as String,
                                name: t['name'] as String,
                                cpm: t['cpm'] as int,
                                usdPerMin: t['usd'] as double,
                                isCurrent: currentTier == t['id'],
                                isUnlocked: unlocked.contains(t['id']),
                              ),
                            ),
                          ),
                        )
                        .toList();
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

  Widget _tierCard({
    required String id,
    required String name,
    required int cpm,
    required double usdPerMin,
    required bool isCurrent,
    required bool isUnlocked,
  }) {
    final s = ref.watch(voiceTierPageCtrlProvider);
    final isUpdating = s.updatingTier == id;
    final avg3Credits = cpm * 3;
    final avg3Dollars = (usdPerMin * 3).toStringAsFixed(2);

    return Card(
      color: NeyvoColors.bgRaised,
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
            Text(name, style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              '$cpm credits / min',
              style: NeyvoTextStyles.display.copyWith(color: NeyvoColors.teal),
            ),
            const SizedBox(height: 4),
            Text('\$${usdPerMin.toStringAsFixed(2)} / min', style: NeyvoTextStyles.body),
            const SizedBox(height: 4),
            Text('Avg 3-min call ≈ $avg3Credits credits (\$$avg3Dollars)', style: NeyvoTextStyles.label),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: !isUnlocked || isCurrent || isUpdating ? null : () => _selectTier(id),
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
                    : Text(isCurrent ? 'Current tier' : isUnlocked ? 'Select $name' : 'Locked'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

