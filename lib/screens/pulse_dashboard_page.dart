// Voice OS Home – Voice Command Center (not a SaaS dashboard).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../theme/neyvo_theme.dart';
import '../ui/components/ai_orb/neyvo_ai_orb.dart';
import '../ui/components/glass/neyvo_glass_panel.dart';
import '../features/agents/create_agent_wizard.dart';
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
  Map<String, dynamic>? _ubModel;

  String _timeRange = '7d';

  static const List<String> _recommendedOperators = [
    'Admissions Operator',
    'Student Financial Services Operator',
    'Registrar Operator',
    'Housing Operator',
    'IT Help Desk Operator',
    'General Front Desk Operator',
  ];

  /// Map dashboard label to UB department id for wizard deep-link.
  static String? _departmentIdForLabel(String label) {
    const map = {
      'Admissions Operator': 'admissions',
      'Student Financial Services Operator': 'student_financial_services',
      'Registrar Operator': 'registrar',
      'Housing Operator': 'residential_life_and_housing',
      'IT Help Desk Operator': 'information_technology_help_desk',
      'General Front Desk Operator': null,
    };
    return map[label];
  }

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
        _ubModel = ubRes is Map ? Map<String, dynamic>.from(ubRes as Map) : null;
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

    // Keep the dedicated "create first operator" experience for empty state.
    if (showCreateFirstOperator) {
      return ClipRect(
        child: RefreshIndicator(
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
                                  onPressed: () async {
                                    final deptId = _departmentIdForLabel(_recommendedOperators[i]);
                                    if (deptId != null) {
                                      final created = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => CreateAgentWizard(initialDepartmentId: deptId),
                                      );
                                      if (created == true && mounted) {
                                        Navigator.of(context, rootNavigator: true)
                                            .pushNamed(PulseRouteNames.managedProfiles);
                                      }
                                    } else {
                                      Navigator.of(context, rootNavigator: true)
                                          .pushNamed(PulseRouteNames.managedProfiles);
                                    }
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: i == 0 ? NeyvoColors.teal : NeyvoColors.bgRaised,
                                    foregroundColor: i == 0 ? NeyvoColors.white : NeyvoColors.textPrimary,
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
          ),
    );
    }

    final callOk = _firstCallCompleted;
    final orbState = callOk ? NeyvoAIOrbState.idle : NeyvoAIOrbState.processing;

    return ClipRect(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeroSection(orbState, callOk, contentWidth),
                        const SizedBox(height: 24),
                        _buildInsightsSection(),
                        const SizedBox(height: 24),
                        _buildOperationsSection(callOk),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(NeyvoAIOrbState orbState, bool callOk, double contentWidth) {
    final callsTotal = (_perf?['calls_total'] as num?)?.toInt() ?? _recentCalls.length;
    final resolutionPct = (_perf?['resolution_rate_pct'] as num?)?.toDouble() ??
        (_perf?['resolution_rate'] as num?)?.toDouble();
    final studentsReached = _computeUniqueStudentsReached();
    final timeSavedHours = (_perf?['time_saved_hours'] as num?)?.toDouble();

    final totalCoreDepartments = _recommendedOperators.length;
    final coveredDepartments = _operatorCount.clamp(0, totalCoreDepartments);

    final ubModelStatus = _ubStatus;
    final envLabel = 'Prod';

    final heroCard = _SimpleCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'University of Bridgeport Voice OS',
                style: NeyvoTextStyles.heading.copyWith(fontSize: 18),
              ),
              const Spacer(),
              _TimeRangeSelector(
                value: _timeRange,
                onChanged: (v) => setState(() {
                  _timeRange = v;
                  _load();
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: 'Voice OS',
                value: callOk ? 'Healthy' : 'Needs attention',
                color: callOk ? NeyvoColors.success : NeyvoColors.warning,
              ),
              _StatusChip(
                label: 'Coverage',
                value: '$coveredDepartments / $totalCoreDepartments departments',
              ),
              _StatusChip(
                label: 'UB model',
                value: ubModelStatus == 'ready'
                    ? 'Ready'
                    : ubModelStatus == 'building'
                        ? 'Building'
                        : 'Missing',
                color: ubModelStatus == 'ready'
                    ? NeyvoColors.success
                    : ubModelStatus == 'building'
                        ? NeyvoColors.info
                        : NeyvoColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _metricChip('Calls handled', callsTotal > 0 ? callsTotal.toString() : '—'),
              _metricChip(
                'AI answer rate',
                resolutionPct == null ? '—' : '${resolutionPct.toStringAsFixed(1)}%',
              ),
              _metricChip(
                'Students reached',
                studentsReached > 0 ? studentsReached.toString() : '—',
              ),
              _metricChip(
                'Time saved',
                timeSavedHours == null
                    ? '—'
                    : '≈ ${timeSavedHours.toStringAsFixed(1)} h',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Last updated just now · $envLabel',
            style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
          ),
        ],
      ),
    );

    final nextActionsCard = _SimpleCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next best actions', style: NeyvoTextStyles.heading),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              if (w < 600) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _NextActionCompact(icon: Icons.person_add_alt_1_outlined, label: 'Add operator', onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.managedProfiles)),
                      const SizedBox(width: 8),
                      _NextActionCompact(icon: Icons.campaign_outlined, label: 'Campaigns', onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.campaigns)),
                      const SizedBox(width: 8),
                      _NextActionCompact(icon: Icons.school_outlined, label: 'UB model', onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.ubModelOverview)),
                      const SizedBox(width: 8),
                      _NextActionCompact(icon: Icons.analytics_outlined, label: 'Analytics', onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.analytics)),
                    ],
                  ),
                );
              }
              return Row(
                children: [
                  Expanded(child: _NextActionCompact(icon: Icons.person_add_alt_1_outlined, label: 'Add operator', onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.managedProfiles))),
                  const SizedBox(width: 8),
                  Expanded(child: _NextActionCompact(icon: Icons.campaign_outlined, label: 'Campaigns', onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.campaigns))),
                  const SizedBox(width: 8),
                  Expanded(child: _NextActionCompact(icon: Icons.school_outlined, label: 'UB model', onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.ubModelOverview))),
                  const SizedBox(width: 8),
                  Expanded(child: _NextActionCompact(icon: Icons.analytics_outlined, label: 'Analytics', onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.analytics))),
                ],
              );
            },
          ),
        ],
      ),
    );

    if (contentWidth < 800) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heroCard,
          const SizedBox(height: 16),
          nextActionsCard,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: heroCard),
        const SizedBox(width: 16),
        Expanded(flex: 5, child: nextActionsCard),
      ],
    );
  }

  Widget _buildInsightsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        if (isNarrow) {
          return Column(
            children: [
              _VoiceCoverageCard(operatorCount: _operatorCount, totalCoreDepartments: _recommendedOperators.length),
              const SizedBox(height: 16),
              _CallsPerformanceCard(perf: _perf),
              const SizedBox(height: 16),
              _StudentFinancialImpactCard(perf: _perf),
              const SizedBox(height: 16),
              _UbModelCard(ubModel: _ubModel, status: _ubStatus),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _VoiceCoverageCard(
                    operatorCount: _operatorCount,
                    totalCoreDepartments: _recommendedOperators.length,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _CallsPerformanceCard(perf: _perf)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _StudentFinancialImpactCard(perf: _perf)),
                const SizedBox(width: 16),
                Expanded(child: _UbModelCard(ubModel: _ubModel, status: _ubStatus)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildOperationsSection(bool callOk) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: _SimpleCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign_outlined, color: NeyvoColors.teal),
                    const SizedBox(width: 10),
                    Text('Active operations', style: NeyvoTextStyles.heading),
                  ],
                ),
                const SizedBox(height: 12),
                if (!callOk) ...[
                  Text(
                    'Make a quick test call to finalize setup, then launch campaigns for students.',
                    style: NeyvoTextStyles.body,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.testCall),
                      style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                      child: const Text('Make a test call'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _recentCallsTable(),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 5,
          child: _SimpleCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_toggle_off, color: NeyvoColors.teal),
                    const SizedBox(width: 10),
                    Text('Live activity', style: NeyvoTextStyles.heading),
                  ],
                ),
                const SizedBox(height: 12),
                if (_recentCalls.isEmpty)
                  Text(
                    'No recent activity yet. As students call or receive outbound calls, activity will appear here.',
                    style: NeyvoTextStyles.body,
                  )
                else
                  Column(
                    children: _recentCalls.take(5).map((c) {
                      final dir = (c['direction'] as String?)?.toLowerCase() ?? 'inbound';
                      final status = (c['status'] as String?)?.toLowerCase() ?? '—';
                      final name =
                          (c['student_name'] ?? c['contact_name'] ?? c['caller'] ?? '—').toString();
                      final dur = (c['duration_seconds'] as num?)?.toInt() ?? 0;
                      final ok = status == 'completed' || status == 'success';
                      final timeLabel = dur <= 0 ? '' : ' · ${dur}s';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              dir == 'inbound' ? Icons.call_received : Icons.call_made,
                              size: 18,
                              color: ok ? NeyvoColors.success : NeyvoColors.warning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$name · ${dir == 'inbound' ? 'Inbound' : 'Outbound'}$timeLabel',
                                style: NeyvoTextStyles.body,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
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
                      label: 'Start outbound',
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.dialer),
                    ),
                    _actionButton(
                      icon: Icons.smart_toy_outlined,
                      label: 'Edit operator',
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.agents),
                    ),
                    _actionButton(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Add credits',
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.billing),
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

  int _computeUniqueStudentsReached() {
    final phones = <String>{};
    for (final c in _recentCalls) {
      final phone =
          (c['student_phone'] ?? c['to'] ?? c['phone_number'] ?? '').toString().trim();
      if (phone.isNotEmpty) phones.add(phone);
    }
    return phones.length;
  }
}

class _TimeRangeSelector extends StatelessWidget {
  const _TimeRangeSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
      ),
      segments: const [
        ButtonSegment(value: '1d', label: Text('Today')),
        ButtonSegment(value: '7d', label: Text('7d')),
        ButtonSegment(value: '30d', label: Text('30d')),
      ],
      selected: {value},
      onSelectionChanged: (v) {
        if (v.isNotEmpty) onChanged(v.first);
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? NeyvoColors.borderDefault;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
          ),
          Text(
            value,
            style: NeyvoTextStyles.micro.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  const _SimpleCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeyvoColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NextActionCompact extends StatelessWidget {
  const _NextActionCompact({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 100),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: NeyvoColors.textPrimary,
          side: const BorderSide(color: NeyvoColors.borderDefault),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: NeyvoColors.teal),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: NeyvoTextStyles.label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: NeyvoGlassPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: NeyvoColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: NeyvoTextStyles.micro,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: NeyvoColors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCoverageCard extends StatelessWidget {
  const _VoiceCoverageCard({
    required this.operatorCount,
    required this.totalCoreDepartments,
  });

  final int operatorCount;
  final int totalCoreDepartments;

  @override
  Widget build(BuildContext context) {
    final covered = operatorCount.clamp(0, totalCoreDepartments);
    final uncovered = (totalCoreDepartments - covered).clamp(0, totalCoreDepartments);
    final sections = <PieChartSectionData>[
      PieChartSectionData(
        value: covered.toDouble(),
        color: NeyvoColors.teal,
        title: '',
        radius: 40,
      ),
      PieChartSectionData(
        value: uncovered.toDouble(),
        color: NeyvoColors.borderSubtle,
        title: '',
        radius: 32,
      ),
    ];

    return _SimpleCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('Voice coverage by department', style: NeyvoTextStyles.heading),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$covered of $totalCoreDepartments core UB departments have at least one operator.',
                      style: NeyvoTextStyles.body,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Admissions, Student Financial Services, Registrar, Housing, IT Help Desk, Front Desk.',
                      style: NeyvoTextStyles.micro,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context, rootNavigator: true)
                          .pushNamed(PulseRouteNames.managedProfiles),
                      icon: const Icon(Icons.add),
                      label: const Text('Create operator'),
                      style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallsPerformanceCard extends StatelessWidget {
  const _CallsPerformanceCard({required this.perf});

  final Map<String, dynamic>? perf;

  @override
  Widget build(BuildContext context) {
    final seriesDynamic = (perf?['daily_calls'] as List?) ?? const [];
    final series = <FlSpot>[];
    for (var i = 0; i < seriesDynamic.length; i++) {
      final m = Map<String, dynamic>.from(seriesDynamic[i] as Map);
      final total = (m['total'] as num?)?.toDouble() ?? 0;
      series.add(FlSpot(i.toDouble(), total));
    }

    return _SimpleCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('Calls & performance', style: NeyvoTextStyles.heading),
            ],
          ),
          const SizedBox(height: 12),
          if (series.isEmpty)
            Text(
              'Call volume charts will appear here once you have more activity.',
              style: NeyvoTextStyles.body,
            )
          else
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: NeyvoColors.borderSubtle, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) =>
                            Text(v.toInt().toString(), style: NeyvoTextStyles.micro),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        getTitlesWidget: (v, _) =>
                            Text('D${v.toInt() + 1}', style: NeyvoTextStyles.micro),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: series.isEmpty ? 1 : series.last.x,
                  minY: 0,
                  maxY: series.isEmpty
                      ? 1
                      : (series.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 2),
                  lineBarsData: [
                    LineChartBarData(
                      spots: series,
                      isCurved: true,
                      color: NeyvoColors.teal,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            NeyvoColors.tealGlow,
                            NeyvoColors.tealGlow.withValues(alpha: 0),
                          ],
                        ),
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
}

class _StudentFinancialImpactCard extends StatelessWidget {
  const _StudentFinancialImpactCard({required this.perf});

  final Map<String, dynamic>? perf;

  @override
  Widget build(BuildContext context) {
    final impact = perf?['student_financial_impact'] as Map<String, dynamic>? ?? {};
    final collected = (impact['collected'] as num?)?.toDouble() ?? 0;
    final promised = (impact['promised'] as num?)?.toDouble() ?? 0;
    final atRisk = (impact['at_risk'] as num?)?.toDouble() ?? 0;
    final total = collected + promised + atRisk;

    return _SimpleCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_money_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('Student financial impact', style: NeyvoTextStyles.heading),
            ],
          ),
          const SizedBox(height: 12),
          if (total <= 0)
            Text(
              'Connect billing and run campaigns to see financial impact here.',
              style: NeyvoTextStyles.body,
            )
          else ...[
            Text(
              '\$${(collected + promised).toStringAsFixed(0)} collected / promised this week',
              style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _impactBar('Collected', collected, total, NeyvoColors.success),
                const SizedBox(width: 8),
                _impactBar('Promised', promised, total, NeyvoColors.info),
                const SizedBox(width: 8),
                _impactBar('At risk', atRisk, total, NeyvoColors.warning),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _impactBar(String label, double value, double total, Color color) {
    final fraction = total <= 0 ? 0.0 : value / total;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: color.withOpacity(0.18),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: NeyvoTextStyles.micro),
        ],
      ),
    );
  }
}

class _UbModelCard extends StatelessWidget {
  const _UbModelCard({required this.ubModel, required this.status});

  final Map<String, dynamic>? ubModel;
  final String status;

  @override
  Widget build(BuildContext context) {
    final model = ubModel ?? {};
    final sourceUrl = (model['source_url'] ?? 'https://www.bridgeport.edu').toString();
    final departmentsCount = (model['departmentsDiscovered'] as num?)?.toInt() ??
        (model['departments_count'] as num?)?.toInt() ??
        0;
    final faqCount =
        (model['faqTopicsCount'] as num?)?.toInt() ?? (model['faq_count'] as num?)?.toInt() ?? 0;

    return _SimpleCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('UB model & knowledge', style: NeyvoTextStyles.heading),
            ],
          ),
          const SizedBox(height: 12),
          if (status == 'building') ...[
            Text(
              'Analyzing bridgeport.edu…',
              style: NeyvoTextStyles.body,
            ),
            const SizedBox(height: 8),
            const LinearProgressIndicator(
              value: null,
              color: NeyvoColors.teal,
              backgroundColor: NeyvoColors.bgRaised,
            ),
          ] else if (status != 'ready') ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NeyvoColors.warning.withOpacity(0.11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: NeyvoColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'UB model is not ready yet. Initialize from bridgeport.edu to unlock department-aware operators.',
                      style: NeyvoTextStyles.micro,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true)
                        .pushNamed(PulseRouteNames.ubModelOverview),
                    child: const Text('Open UB onboarding'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Source: $sourceUrl',
              style: NeyvoTextStyles.body,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badgeChip('$departmentsCount departments learned'),
                _badgeChip('$faqCount FAQ topics'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Admissions, Student Financial Services, Registrar, Housing, IT Help Desk and more are included in the model.',
              style: NeyvoTextStyles.micro,
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true)
                  .pushNamed(PulseRouteNames.ubModelOverview),
              child: const Text('View model'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Text(text, style: NeyvoTextStyles.micro),
    );
  }
}
