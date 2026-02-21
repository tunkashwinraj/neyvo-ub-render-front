// lib/screens/voice_tier_page.dart
// Voice tier selector: Neutral Human, Natural Human (Most Popular), Ultra Real Human.
// No provider names in UI. Exact feature copy per spec.

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import 'pulse_shell.dart';
import '../theme/spearia_theme.dart';

class VoiceTierPage extends StatefulWidget {
  const VoiceTierPage({super.key});

  @override
  State<VoiceTierPage> createState() => _VoiceTierPageState();
}

class _VoiceTierPageState extends State<VoiceTierPage> {
  Map<String, dynamic>? _wallet;
  bool _loading = true;
  String? _error;
  String? _updating;

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
      final w = await NeyvoPulseApi.getBillingWallet();
      if (mounted) setState(() {
        _wallet = w;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectTier(String tier) async {
    if (_updating != null) return;
    setState(() => _updating = tier);
    try {
      await NeyvoPulseApi.setBillingTier(tier);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice tier updated to ${_tierDisplay(tier)}')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _updating = null);
    }
  }

  String _tierDisplay(String tier) {
    switch (tier) {
      case 'neutral': return 'Neutral Human';
      case 'natural': return 'Natural Human';
      case 'ultra': return 'Ultra Real Human';
      default: return tier;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _wallet == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading…', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final currentTier = (_wallet?['tier'] as String?) ?? 'natural';
    final subTier = (_wallet?['subscription_tier'] as String?)?.toLowerCase() ?? 'free';
    final isFree = subTier == 'free';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isFree)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SpeariaAura.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SpeariaAura.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: SpeariaAura.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Natural Human and Ultra Real Human require Pro or Business. Upgrade to unlock all voice tiers.',
                      style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textPrimary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.subscriptionPlan))),
                    child: const Text('Upgrade — \$29/mo'),
                  ),
                ],
              ),
            ),
          Text(
            'Choose your voice quality',
            style: SpeariaType.headlineMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Pay only for what you use. Billed per minute. No subscriptions.',
            style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _tierCard('neutral', currentTier, 0.25, 25, 'Neutral Human', _neutralBullets(), '🎙️')),
                        const SizedBox(width: 16),
                        Expanded(child: _tierCard('natural', currentTier, 0.35, 35, 'Natural Human', _naturalBullets(), '🎤', popular: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _tierCard('ultra', currentTier, 0.49, 49, 'Ultra Real Human', _ultraBullets(), '✨')),
                      ],
                    )
                  : Column(
                      children: [
                        _tierCard('neutral', currentTier, 0.25, 25, 'Neutral Human', _neutralBullets(), '🎙️'),
                        const SizedBox(height: 16),
                        _tierCard('natural', currentTier, 0.35, 35, 'Natural Human', _naturalBullets(), '🎤', popular: true),
                        const SizedBox(height: 16),
                        _tierCard('ultra', currentTier, 0.49, 49, 'Ultra Real Human', _ultraBullets(), '✨'),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  List<String> _neutralBullets() => [
    'Professional, clear voice that commands attention on every call',
    'Built for speed — launches campaigns of hundreds of calls without delay',
    'Consistently low response time keeps conversations flowing naturally',
    'Every AI capability fully unlocked — reminders, queries, resolutions',
  ];

  List<String> _naturalBullets() => [
    'Warm, conversational tone that feels like a real team member calling',
    'Natural pauses, rhythm, and cadence that put contacts at ease',
    'Optimized for real-time interaction — responds the moment someone speaks',
    'Ideal for finance conversations, student queries, and sensitive outreach',
  ];

  List<String> _ultraBullets() => [
    'Full emotional range — empathy, warmth, and nuance in every sentence',
    'Handles complex, sensitive conversations with the depth of a trained agent',
    'Most advanced AI reasoning for multi-step queries and unexpected responses',
    'The highest quality voice experience available in any AI calling platform',
  ];

  Widget _tierCard(String tier, String currentTier, double price, int creditsPerMin, String name, List<String> bullets, String emoji, {bool popular = false}) {
    final isSelected = currentTier == tier;
    final isUpdating = _updating == tier;
    final avg3min = (price * 3).toStringAsFixed(2);

    return Card(
      elevation: popular ? 4 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? SpeariaAura.primary : SpeariaAura.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (popular)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: SpeariaAura.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Most Popular', style: SpeariaType.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            if (popular) const SizedBox(height: 12),
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(name, style: SpeariaType.titleLarge.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('\$${price.toStringAsFixed(2)}', style: SpeariaType.headlineMedium.copyWith(fontWeight: FontWeight.w800, color: SpeariaAura.primary)),
                Text(' / min', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
              ],
            ),
            Text('$creditsPerMin credits per minute', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: SpeariaAura.bgDark, borderRadius: BorderRadius.circular(8)),
              child: Text('Avg 3-min call ≈ \$$avg3min', style: SpeariaType.bodySmall),
            ),
            const SizedBox(height: 16),
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: SpeariaAura.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(b, style: SpeariaType.bodySmall)),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isUpdating ? null : () => _selectTier(tier),
                style: FilledButton.styleFrom(
                  backgroundColor: isSelected ? SpeariaAura.primary : SpeariaAura.primary.withOpacity(0.12),
                  foregroundColor: isSelected ? Colors.white : SpeariaAura.primary,
                ),
                child: isUpdating ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(isSelected ? 'Current tier' : 'Select $name'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
