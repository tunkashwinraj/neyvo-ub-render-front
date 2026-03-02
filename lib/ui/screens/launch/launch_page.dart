import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../neyvo_pulse_api.dart';
import '../../../pulse_route_names.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/ai_orb/neyvo_ai_orb.dart';
import '../../components/glass/neyvo_glass_panel.dart';
import '../../../features/managed_profiles/managed_profile_api_service.dart';
import '../../../features/setup/setup_api_service.dart';

class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  bool _loading = true;
  String? _error;

  int _credits = 0;
  bool _businessReady = false;
  int _agentsCount = 0;
  int _numbersCount = 0;
  bool _hasFirstCompletedCall = false;
  String? _trainingNumberE164;

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
      final results = await Future.wait([
        NeyvoPulseApi.getBillingWallet(),
        SetupStatusApiService.getStatus(),
        ManagedProfileApiService.listProfiles(),
        NeyvoPulseApi.listNumbers(),
        NeyvoPulseApi.listCalls(),
        NeyvoPulseApi.getAccountInfo(),
      ]);

      final wallet = results[0] as Map<String, dynamic>;
      final setup = results[1] as Map<String, dynamic>;
      final profiles = results[2] as Map<String, dynamic>;
      final numbers = results[3] as Map<String, dynamic>;
      final calls = results[4] as Map<String, dynamic>;
      final account = results[5] as Map<String, dynamic>;

      final credits = (wallet['credits'] as num?)?.toInt() ??
          (wallet['wallet_credits'] as num?)?.toInt() ??
          0;

      final business = Map<String, dynamic>.from(setup['business'] as Map? ?? {});
      final agents = Map<String, dynamic>.from(setup['agents'] as Map? ?? {});
      final nums = Map<String, dynamic>.from(setup['numbers'] as Map? ?? {});
      final businessReady =
          (business['status'] as String? ?? '').toLowerCase() == 'ready';
      final agentsCount = (agents['count'] as num?)?.toInt() ??
          ((profiles['profiles'] as List?)?.length ?? 0);
      final numbersCount =
          (nums['count'] as num?)?.toInt() ??
              ((numbers['numbers'] as List?)?.length ?? 0);

      final callsList =
          (calls['calls'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final hasCompleted = callsList.any((c) {
        final status = (c['status'] as String?)?.toLowerCase();
        if (status == 'completed' || status == 'success') return true;
        final endedAt = c['ended_at'];
        return endedAt != null && status != 'failed';
      });

      String? trainingNumber;
      final primary =
          (account['primary_phone_e164'] ?? account['primary_phone'])?.toString();
      if (primary != null && primary.trim().isNotEmpty) {
        trainingNumber = primary.trim();
      } else {
        final list = (numbers['numbers'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        final primaryNum = list.firstWhere(
          (n) => (n['role']?.toString().toLowerCase() ?? '') == 'primary',
          orElse: () => const {},
        );
        trainingNumber = (primaryNum['phone_number_e164'] ?? primaryNum['phone_number'])?.toString();
      }

      if (!mounted) return;
      setState(() {
        _credits = credits;
        _businessReady = businessReady;
        _agentsCount = agentsCount;
        _numbersCount = numbersCount;
        _hasFirstCompletedCall = hasCompleted;
        _trainingNumberE164 = trainingNumber;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: NeyvoColors.teal),
      );
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

    if (_hasFirstCompletedCall) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  NeyvoGlassPanel(
                    glowing: true,
                    child: Row(
                      children: [
                        const NeyvoAIOrb(state: NeyvoAIOrbState.idle, size: 72),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Launch completed', style: NeyvoTextStyles.heading.copyWith(fontSize: 20)),
                              const SizedBox(height: 6),
                              Text(
                                'Your system is live on real calls.',
                                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 220,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.dashboard),
                            style: FilledButton.styleFrom(
                              backgroundColor: NeyvoColors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Go to Home'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.calls),
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('View calls'),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh status'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final steps = <_LaunchStep>[
      _LaunchStep(
        title: 'Billing setup',
        subtitle: 'Add credits so Neyvo can place and receive calls.',
        complete: _credits > 0,
        primaryLabel: _credits > 0 ? 'Billing is ready' : 'Add credits',
        onPrimary: () => _openBilling(context),
      ),
      _LaunchStep(
        title: 'Business info',
        subtitle: 'Set business basics so your agent behaves correctly.',
        complete: _businessReady,
        primaryLabel: _businessReady ? 'Business configured' : 'Open settings',
        onPrimary: () => _openSettings(context),
      ),
      _LaunchStep(
        title: 'Create agent',
        subtitle: 'Create your first agent (personality + prompt + voice).',
        complete: _agentsCount > 0,
        primaryLabel: _agentsCount > 0 ? 'Agent created' : 'Create agent',
        onPrimary: () => _openAgents(context),
      ),
      _LaunchStep(
        title: 'Connect phone number',
        subtitle: 'Get a training number and at least one production number.',
        complete: _numbersCount > 0,
        primaryLabel: _numbersCount > 0 ? 'Number connected' : 'Open Numbers Hub',
        onPrimary: () => _openNumbers(context),
      ),
      _LaunchStep(
        title: 'Test call',
        subtitle: 'Call your training number and verify the full flow.',
        complete: _hasFirstCompletedCall,
        primaryLabel: _hasFirstCompletedCall ? 'Test completed' : 'Call this number',
        onPrimary: () => _showCallNow(context),
      ),
    ];

    final next = steps.firstWhere((s) => !s.complete, orElse: () => steps.last);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Launch', style: NeyvoTextStyles.title.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Get your AI agent live on real calls — fast.',
                  style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                ),
                const SizedBox(height: 24),
                NeyvoGlassPanel(
                  glowing: !next.complete,
                  child: Row(
                    children: [
                      NeyvoAIOrb(
                        state: next.complete ? NeyvoAIOrbState.idle : NeyvoAIOrbState.processing,
                        size: 64,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Next step', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
                            const SizedBox(height: 4),
                            Text(next.title, style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                            const SizedBox(height: 4),
                            Text(next.subtitle, style: NeyvoTextStyles.body),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 220,
                        child: FilledButton(
                          onPressed: next.onPrimary,
                          style: FilledButton.styleFrom(
                            backgroundColor: NeyvoColors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(next.primaryLabel),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...steps.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: NeyvoGlassPanel(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              s.complete ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: s.complete ? NeyvoColors.success : NeyvoColors.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.title, style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
                                  const SizedBox(height: 4),
                                  Text(s.subtitle, style: NeyvoTextStyles.body),
                                  if (s.title == 'Test call' && (_trainingNumberE164 ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: NeyvoColors.bgRaised.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: NeyvoColors.borderSubtle),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _trainingNumberE164!,
                                              style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => _copy(context, _trainingNumberE164!),
                                            icon: const Icon(Icons.copy, size: 16),
                                            label: const Text('Copy'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 220,
                              child: FilledButton(
                                onPressed: s.onPrimary,
                                style: FilledButton.styleFrom(
                                  backgroundColor: NeyvoColors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(s.primaryLabel),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh status'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  void _openBilling(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.billing);
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.settings);
  }

  void _openAgents(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.agents);
  }

  void _openNumbers(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.phoneNumbers);
  }

  void _showCallNow(BuildContext context) {
    final number = (_trainingNumberE164 ?? '').trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No training number yet. Connect a number first.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeyvoColors.bgBase,
        title: const Text('Call your AI'),
        content: Text(
          'Call this number now to complete Launch:\n\n$number\n\nAfter the call ends, click “Refresh status”.',
          style: NeyvoTextStyles.bodyPrimary,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _copy(context, number);
            },
            child: const Text('Copy number'),
          ),
        ],
      ),
    );
  }
}

class _LaunchStep {
  final String title;
  final String subtitle;
  final bool complete;
  final String primaryLabel;
  final VoidCallback onPrimary;

  _LaunchStep({
    required this.title,
    required this.subtitle,
    required this.complete,
    required this.primaryLabel,
    required this.onPrimary,
  });
}

