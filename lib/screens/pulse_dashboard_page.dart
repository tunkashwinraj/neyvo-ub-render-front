// Voice OS Home – Voice Command Center (not a SaaS dashboard).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../theme/neyvo_theme.dart';
import '../ui/components/ai_orb/neyvo_ai_orb.dart';
import '../ui/components/glass/neyvo_glass_panel.dart';
import '../features/managed_profiles/managed_profile_api_service.dart';
import '../features/setup/setup_api_service.dart';

class PulseDashboardPage extends StatefulWidget {
  const PulseDashboardPage({super.key});

  @override
  State<PulseDashboardPage> createState() => _PulseDashboardPageState();
}

class _PulseDashboardPageState extends State<PulseDashboardPage> {
  bool _loading = true;
  String? _error;

  bool _businessConfigured = false;
  bool _agentAttached = false;
  bool _numberLive = false;
  bool _firstCallCompleted = false;
  String _ubStatus = 'missing';
  int _operatorCount = 0;

  String? _trainingNumber;
  List<Map<String, dynamic>> _recentCalls = const [];
  Map<String, dynamic>? _perf;

  static const List<String> _recommendedOperators = [
    'Admissions Operator',
    'Student Financial Services Operator',
    'Registrar Operator',
    'Housing Operator',
    'IT Help Desk Operator',
    'General Front Desk Operator',
  ];

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
        SetupStatusApiService.getStatus(),
        ManagedProfileApiService.listProfiles(),
        NeyvoPulseApi.listNumbers(),
        NeyvoPulseApi.listCalls(),
        NeyvoPulseApi.getAnalyticsOverview(),
        NeyvoPulseApi.getAccountInfo(),
        NeyvoPulseApi.getUbStatus(),
      ]);

      final setup = results[0] as Map<String, dynamic>;
      final profiles = results[1] as Map<String, dynamic>;
      final numbersRes = results[2] as Map<String, dynamic>;
      final callsRes = results[3] as Map<String, dynamic>;
      final perf = results[4] as Map<String, dynamic>;
      final account = results[5] as Map<String, dynamic>;
      final ubRes = results[6] as Map<String, dynamic>;

      final business = Map<String, dynamic>.from(setup['business'] as Map? ?? {});
      final numbers = (numbersRes['numbers'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final profList = (profiles['profiles'] as List?)?.cast<dynamic>() ?? const [];
      final ubStatus = (ubRes['status'] as String?)?.toLowerCase() ?? 'missing';

      final calls = (callsRes['calls'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final firstCallCompleted = calls.any((c) {
        final status = (c['status'] as String?)?.toLowerCase();
        if (status == 'completed' || status == 'success') return true;
        final endedAt = c['ended_at'];
        return endedAt != null && status != 'failed';
      });

      final businessConfigured =
          (business['status'] as String? ?? '').toLowerCase() == 'ready';

      final numberLive = numbers.isNotEmpty ||
          ((account['primary_phone_e164'] ?? account['primary_phone'])?.toString().trim().isNotEmpty == true);

      final attached = profList.any((p) {
        final m = Map<String, dynamic>.from(p as Map);
        return (m['attached_phone_number_id']?.toString().trim().isNotEmpty == true) ||
            (m['attached_vapi_phone_number_id']?.toString().trim().isNotEmpty == true);
      });

      final trainingNumber = (account['primary_phone_e164'] ?? account['primary_phone'])?.toString().trim();

      if (!mounted) return;
      setState(() {
        _businessConfigured = businessConfigured;
        _agentAttached = attached;
        _numberLive = numberLive;
        _firstCallCompleted = firstCallCompleted;
        _ubStatus = ubStatus;
        _operatorCount = profList.length;
        _trainingNumber = trainingNumber != null && trainingNumber.isNotEmpty ? trainingNumber : null;
        _recentCalls = calls.take(8).toList();
        _perf = perf;
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

    final ubReady = _ubStatus == 'ready';
    final showCreateFirstOperator = ubReady && _operatorCount == 0;

    if (showCreateFirstOperator) {
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        const NeyvoAIOrb(state: NeyvoAIOrbState.idle, size: 140),
                        const SizedBox(height: 20),
                        Text(
                          'Create your first Operator',
                          style: NeyvoTextStyles.title.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: NeyvoColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a department to create a voice operator. You can add more later.',
                          style: NeyvoTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        NeyvoGlassPanel(
                          glowing: true,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < _recommendedOperators.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                FilledButton(
                                  onPressed: () => Navigator.of(context, rootNavigator: true)
                                      .pushNamed(PulseRouteNames.managedProfiles),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: i == 0 ? NeyvoColors.teal : NeyvoColors.bgRaised,
                                    foregroundColor: i == 0 ? Colors.white : NeyvoColors.textPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text(
                                    i == 0 ? 'Create ${_recommendedOperators[i]}' : _recommendedOperators[i],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => Navigator.of(context, rootNavigator: true)
                                    .pushNamed(PulseRouteNames.managedProfiles),
                                child: const Text('Choose another department'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final callOk = _firstCallCompleted;
        final orbState = callOk ? NeyvoAIOrbState.idle : NeyvoAIOrbState.processing;
        const title = 'Your Voice AI is Online';
        const subtitle = 'System live. Scale confidently.';

        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Center(child: NeyvoAIOrb(state: orbState, size: 180)),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        style: NeyvoTextStyles.title.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: NeyvoTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: NeyvoGlassPanel(
                              glowing: !callOk,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.verified_outlined, color: NeyvoColors.teal),
                                      const SizedBox(width: 10),
                                      Text('System status', style: NeyvoTextStyles.heading),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: _load,
                                        icon: const Icon(Icons.refresh, size: 18),
                                        label: const Text('Refresh'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _statusRow('Business Configured', _businessConfigured),
                                  _statusRow('Operator Attached', _agentAttached),
                                  _statusRow('Number Live', _numberLive),
                                  _statusRow('First Call Completed', callOk),
                                  if (!callOk) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.testCall),
                                        style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                                        child: const Text('Make a test call'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 6,
                            child: NeyvoGlassPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.bolt_outlined, color: NeyvoColors.teal),
                                      const SizedBox(width: 10),
                                      Text('Quick actions', style: NeyvoTextStyles.heading),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _actionButton(
                                        icon: Icons.phone_in_talk_outlined,
                                        label: 'Call My AI',
                                        onTap: _showCallMyAi,
                                      ),
                                      _actionButton(
                                        icon: Icons.call_made_outlined,
                                        label: 'Start Outbound',
                                        onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.dialer),
                                      ),
                                      _actionButton(
                                        icon: Icons.smart_toy_outlined,
                                        label: 'Edit Operator',
                                        onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.agents),
                                      ),
                                      _actionButton(
                                        icon: Icons.account_balance_wallet_outlined,
                                        label: 'Add Credits',
                                        onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.billing),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (callOk) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: NeyvoGlassPanel(
                                child: _performanceSnapshot(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      NeyvoGlassPanel(
                        child: _recentCallsTable(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
  }

  Widget _performanceSnapshot() {
    final calls = (_perf?['calls_total'] as num?)?.toInt();
    final resolution = (_perf?['resolution_rate_pct'] as num?)?.toDouble() ??
        (_perf?['resolution_rate'] as num?)?.toDouble();
    final credits = (_perf?['credits_consumed'] as num?)?.toInt() ??
        (_perf?['credits_used'] as num?)?.toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_graph_outlined, color: NeyvoColors.teal),
            const SizedBox(width: 10),
            Text('Performance snapshot', style: NeyvoTextStyles.heading),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricChip('Total calls', calls?.toString() ?? '—'),
            _metricChip('Resolution', resolution == null ? '—' : '${resolution.toStringAsFixed(1)}%'),
            _metricChip('Credits used', credits?.toString() ?? '—'),
          ],
        ),
      ],
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: NeyvoTextStyles.micro),
        ],
      ),
    );
  }

  Widget _recentCallsTable() {
    if (_recentCalls.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('Recent calls', style: NeyvoTextStyles.heading),
            ],
          ),
          const SizedBox(height: 12),
          Text('No calls yet.', style: NeyvoTextStyles.body),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, color: NeyvoColors.teal),
            const SizedBox(width: 10),
            Text('Recent calls', style: NeyvoTextStyles.heading),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.calls),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentCalls.map((c) {
          final dir = (c['direction'] as String?)?.toLowerCase() ?? 'inbound';
          final status = (c['status'] as String?)?.toLowerCase() ?? '—';
          final name = (c['student_name'] ?? c['contact_name'] ?? c['caller'] ?? '—').toString();
          final phone = (c['student_phone'] ?? c['to'] ?? c['phone_number'] ?? '').toString();
          final dur = (c['duration_seconds'] as num?)?.toInt() ?? 0;
          final durLabel = dur <= 0 ? '—' : '${dur}s';
          final ok = status == 'completed' || status == 'success';
          final badgeColor = ok ? NeyvoColors.success : NeyvoColors.warning;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: NeyvoColors.bgRaised.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NeyvoColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: badgeColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: NeyvoTextStyles.bodyPrimary),
                        const SizedBox(height: 2),
                        Text(
                          '${dir == 'inbound' ? 'Inbound' : 'Outbound'} · $phone',
                          style: NeyvoTextStyles.micro,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(durLabel, style: NeyvoTextStyles.micro),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _statusRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18, color: ok ? NeyvoColors.success : NeyvoColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: NeyvoTextStyles.bodyPrimary),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 220,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: NeyvoColors.textPrimary,
          side: const BorderSide(color: NeyvoColors.borderDefault),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }

  void _showCallMyAi() {
    final number = (_trainingNumber ?? '').trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No training number yet. Connect a number in Numbers Hub.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeyvoColors.bgBase,
        title: const Text('Call My AI'),
        content: Text(
          'Call this number now:\n\n$number',
          style: NeyvoTextStyles.bodyPrimary,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: number));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
            },
            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
            child: const Text('Copy number'),
          ),
        ],
      ),
    );
  }
}
