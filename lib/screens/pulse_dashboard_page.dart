// lib/screens/pulse_dashboard_page.dart
// Neyvo – enterprise home: stats, AI status bar, recent calls, agents.

import 'package:flutter/material.dart';

import '../pulse_route_names.dart';
import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';
import 'wallet_page.dart';

class PulseDashboardPage extends StatefulWidget {
  const PulseDashboardPage({super.key});

  @override
  State<PulseDashboardPage> createState() => _PulseDashboardPageState();
}

class _PulseDashboardPageState extends State<PulseDashboardPage> with SingleTickerProviderStateMixin {
  int? _activeAgents;
  int? _callsThisMonth;
  int? _creditsUsed;
  double? _resolutionRatePct;
  List<Map<String, dynamic>> _recentCalls = [];
  List<Map<String, dynamic>> _recentAgents = [];
  bool _loading = true;
  bool _onboardingBillingShown = false;
  int _completedCallsTotal = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _load();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final agentsRes = await NeyvoPulseApi.listAgents();
      final overviewRes = await NeyvoPulseApi.getAnalyticsOverview();
      final callsRes = await NeyvoPulseApi.listCalls();
      final accountRes = await NeyvoPulseApi.getAccountInfo();

      final agents = (agentsRes['agents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final calls = (callsRes['calls'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final overview = overviewRes;

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final callsThisMonth = calls.where((c) {
        final t = c['ended_at'] ?? c['created_at'];
        if (t == null) return false;
        final dt = t is DateTime ? t : DateTime.tryParse(t.toString());
        return dt != null && !dt.isBefore(monthStart);
      }).length;

      final creditsUsed = (overview['credits_consumed'] as num?)?.toInt() ??
          (overview['credits_used'] as num?)?.toInt();
      final resolutionRate = (overview['resolution_rate'] as num?)?.toDouble() ??
          (overview['resolution_rate_pct'] as num?)?.toDouble();

      final recentCalls = calls.take(10).toList();
      final activeAgentsList = agents.where((a) => (a['status'] as String?)?.toLowerCase() == 'active').toList();
      final recentAgents = agents.take(3).toList();
      final completedCallsTotal = calls.where((c) {
        final st = (c['status'] as String?)?.toLowerCase();
        if (st == 'completed') return true;
        final endedAt = c['ended_at'];
        return endedAt != null && st != 'failed';
      }).length;
      final onboardingBillingShown = accountRes['onboarding_billing_shown'] == true;

      if (mounted) {
        setState(() {
          _activeAgents = activeAgentsList.isEmpty ? agents.length : activeAgentsList.length;
          _callsThisMonth = callsThisMonth;
          _creditsUsed = creditsUsed ?? 0;
          _resolutionRatePct = resolutionRate ?? 0.0;
          _recentCalls = recentCalls;
          _recentAgents = recentAgents;
          _completedCallsTotal = completedCallsTotal;
          _onboardingBillingShown = onboardingBillingShown;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismissBillingHowItWorks() async {
    setState(() => _onboardingBillingShown = true);
    try {
      await NeyvoPulseApi.updateAccountInfo({'onboarding_billing_shown': true});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Home', style: NeyvoTextStyles.title),
                  const SizedBox(height: 4),
                  Text(
                    'Overview of your AI voice agents and call activity.',
                    style: NeyvoTextStyles.body,
                  ),
                  const SizedBox(height: 24),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator(color: NeyvoColors.teal)),
                    )
                  else ...[
                    // Section 1: Stats row (4 cards)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        int cols = 4;
                        if (w < 980) cols = 2;
                        if (w < 520) cols = 1;
                        final spacing = 24.0;
                        final cardW = cols == 1 ? w : (w - spacing * (cols - 1)) / cols;

                        final cards = <Widget>[
                          _DashboardStatCard(
                            label: 'Active Agents',
                            value: '${_activeAgents ?? 0}',
                            icon: Icons.smart_toy_outlined,
                            color: NeyvoColors.teal,
                          ),
                          _DashboardStatCard(
                            label: 'Calls This Month',
                            value: '${_callsThisMonth ?? 0}',
                            icon: Icons.call_outlined,
                            color: NeyvoColors.info,
                          ),
                          InkWell(
                            onTap: () => Navigator.of(context).pushNamed(PulseRouteNames.wallet),
                            borderRadius: BorderRadius.circular(NeyvoRadius.lg),
                            child: _DashboardStatCard(
                              label: 'Credits Used',
                              value: '${_creditsUsed ?? 0}',
                              icon: Icons.bolt_outlined,
                              color: NeyvoColors.coral,
                            ),
                          ),
                          _DashboardStatCard(
                            label: 'Resolution Rate',
                            value: '${(_resolutionRatePct ?? 0).toStringAsFixed(1)}%',
                            icon: Icons.check_circle_outline,
                            color: NeyvoColors.success,
                          ),
                        ];

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: cards.map((c) => SizedBox(width: cardW, child: c)).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // How Neyvo billing works (show when no completed calls yet)
                    if (!_onboardingBillingShown && _completedCallsTotal == 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'How Neyvo billing works',
                              style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary),
                            ),
                          ),
                          TextButton(
                            onPressed: _dismissBillingHowItWorks,
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pay only for what you use. No monthly voice fees.',
                        style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          int cols = 3;
                          if (w < 980) cols = 1;
                          final spacing = 16.0;
                          final cardW = cols == 1 ? w : (w - spacing * (cols - 1)) / cols;

                          final cards = <Widget>[
                            NeyvoCard(
                              padding: const EdgeInsets.all(NeyvoSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.workspace_premium_outlined, color: NeyvoColors.teal, size: 28),
                                  const SizedBox(height: 12),
                                  Text('Plan', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
                                  const SizedBox(height: 4),
                                  Text('Free, Pro, or Business. Unlock voice tiers and credit bonus.', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary, fontSize: 13)),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () => Navigator.pushNamed(context, PulseRouteNames.settings),
                                    child: const Text('Billing → Plan'),
                                  ),
                                ],
                              ),
                            ),
                            NeyvoCard(
                              padding: const EdgeInsets.all(NeyvoSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.account_balance_wallet_outlined, color: NeyvoColors.teal, size: 28),
                                  const SizedBox(height: 12),
                                  Text('Wallet', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
                                  const SizedBox(height: 4),
                                  Text('Buy credits in packs. Used per minute of call time.', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary, fontSize: 13)),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pushNamed(PulseRouteNames.wallet),
                                    child: const Text('Add Credits'),
                                  ),
                                ],
                              ),
                            ),
                            NeyvoCard(
                              padding: const EdgeInsets.all(NeyvoSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.record_voice_over_outlined, color: NeyvoColors.teal, size: 28),
                                  const SizedBox(height: 12),
                                  Text('Voice Quality', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textPrimary)),
                                  const SizedBox(height: 4),
                                  Text('Neutral, Natural, or Ultra. Set default in Billing.', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary, fontSize: 13)),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () => Navigator.pushNamed(context, PulseRouteNames.settings),
                                    child: const Text('Billing → Voice Tier'),
                                  ),
                                ],
                              ),
                            ),
                          ];

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: cards.map((c) => SizedBox(width: cardW, child: c)).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Section 2: Glowing AI status bar
                    _AiStatusBar(pulseAnimation: _pulseAnimation),
                    const SizedBox(height: 24),

                    // Section 3: Two-column (60/40)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 60,
                          child: _RecentCallsSection(calls: _recentCalls),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 40,
                          child: _YourAgentsSection(
                            agents: _recentAgents,
                            onCreateAgent: () => Navigator.of(context).pushNamed(PulseRouteNames.agents),
                            onAddCredits: () => Navigator.of(context).pushNamed(PulseRouteNames.wallet),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return NeyvoCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: NeyvoTextStyles.display.copyWith(color: NeyvoColors.textPrimary, fontSize: 28),
          ),
        ],
      ),
    );
  }
}

class _AiStatusBar extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _AiStatusBar({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return NeyvoCard(
      glowing: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NeyvoColors.teal.withOpacity(pulseAnimation.value),
                  boxShadow: [
                    BoxShadow(
                      color: NeyvoColors.teal.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Text(
            'NEYVO AI ACTIVE',
            style: NeyvoTextStyles.label.copyWith(
              color: NeyvoColors.teal,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'All systems operational',
              style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary, fontSize: 12),
            ),
          ),
          Text(
            'Uptime: 99.9%',
            style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RecentCallsSection extends StatelessWidget {
  final List<Map<String, dynamic>> calls;

  const _RecentCallsSection({required this.calls});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Calls', style: NeyvoTextStyles.heading),
        const SizedBox(height: 12),
        NeyvoCard(
          padding: EdgeInsets.zero,
          child: calls.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.phone_in_talk_outlined, size: 48, color: NeyvoColors.textMuted),
                        const SizedBox(height: 12),
                        Text('No calls yet', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          'Assign a phone number to an agent to start receiving calls.',
                          style: NeyvoTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header row
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: NeyvoColors.borderSubtle))),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: _tableHeader('Agent')),
                          Expanded(flex: 1, child: _tableHeader('Direction')),
                          Expanded(flex: 1, child: _tableHeader('Duration')),
                          Expanded(flex: 1, child: _tableHeader('Outcome')),
                          Expanded(flex: 1, child: _tableHeader('Time')),
                        ],
                      ),
                    ),
                    ...calls.asMap().entries.map((e) => _callRowWidget(context, e.value)),
                  ],
                ),
        ),
      ],
    );
  }

  static Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text.toUpperCase(),
        style: NeyvoTextStyles.label.copyWith(
          color: NeyvoColors.textMuted,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static Widget _callRowWidget(BuildContext context, Map<String, dynamic> c) {
    final agentName = c['agent_name'] ?? c['agent_id'] ?? '—';
    final dir = (c['direction'] as String?)?.toLowerCase() ?? 'inbound';
    final duration = (c['duration_seconds'] as num?)?.toInt() ?? 0;
    final outcome = (c['outcome'] as String?)?.toLowerCase() ?? '—';
    final ended = c['ended_at'] ?? c['created_at'];
    final timeStr = ended != null
        ? (ended is DateTime
            ? '${ended.month}/${ended.day} ${ended.hour}:${ended.minute.toString().padLeft(2, '0')}'
            : ended.toString().length > 16
                ? ended.toString().substring(0, 16)
                : ended.toString())
        : '—';

    final isResolved = outcome.contains('resolved') || outcome == 'completed';
    final outcomeColor = isResolved ? NeyvoColors.success : NeyvoColors.error;
    final dirBg = dir == 'inbound' ? NeyvoColors.info.withOpacity(0.1) : NeyvoColors.teal.withOpacity(0.1);
    final dirColor = dir == 'inbound' ? NeyvoColors.info : NeyvoColors.teal;
    final dirLabel = dir == 'inbound' ? '← Inbound' : '→ Outbound';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(PulseRouteNames.callHistory),
        hoverColor: NeyvoColors.bgHover,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: NeyvoColors.borderSubtle))),
          child: Row(
            children: [
              Expanded(flex: 2, child: _cell(agentName.toString(), primary: true)),
              Expanded(
                flex: 1,
                child: _cell(
                  '',
                  custom: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: dirBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: dirColor.withOpacity(0.2)),
                    ),
                    child: Text(dirLabel, style: NeyvoTextStyles.micro.copyWith(color: dirColor)),
                  ),
                ),
              ),
              Expanded(flex: 1, child: _cell('${duration}s')),
              Expanded(
                flex: 1,
                child: _cell(
                  '',
                  custom: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: outcomeColor),
                      ),
                      const SizedBox(width: 6),
                      Text(outcome.isEmpty ? '—' : outcome, style: NeyvoTextStyles.micro.copyWith(color: outcomeColor)),
                    ],
                  ),
                ),
              ),
              Expanded(flex: 1, child: _cell(timeStr)),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _cell(String text, {bool primary = false, Widget? custom}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: custom ??
          Text(
            text,
            style: primary
                ? NeyvoTextStyles.bodyPrimary
                : NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
    );
  }
}

class _YourAgentsSection extends StatelessWidget {
  final List<Map<String, dynamic>> agents;
  final VoidCallback onCreateAgent;
  final VoidCallback onAddCredits;

  const _YourAgentsSection({
    required this.agents,
    required this.onCreateAgent,
    required this.onAddCredits,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Agents', style: NeyvoTextStyles.heading),
        const SizedBox(height: 12),
        NeyvoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (agents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No agents yet. Create one to get started.',
                    style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
                  ),
                )
              else
                ...agents.map((a) {
                  final name = a['name'] as String? ?? 'Unnamed';
                  final status = (a['status'] as String?)?.toLowerCase() ?? 'draft';
                  final industry = (a['industry'] as String?) ?? '';
                  final id = a['id'] as String?;
                  final dotColor = status == 'active'
                      ? NeyvoColors.success
                      : status == 'inactive'
                          ? NeyvoColors.textMuted
                          : NeyvoColors.warning;
                  return InkWell(
                    onTap: id != null
                        ? () => Navigator.of(context).pushNamed(PulseRouteNames.agentDetail, arguments: id)
                        : null,
                    hoverColor: NeyvoColors.bgHover.withOpacity(0.5),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dotColor,
                              boxShadow: status == 'active'
                                  ? [BoxShadow(color: NeyvoColors.success.withOpacity(0.6), blurRadius: 6)]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w500)),
                                if (industry.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: NeyvoColors.borderSubtle.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      industry,
                                      style: NeyvoTextStyles.micro,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 12, color: NeyvoColors.textMuted),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onCreateAgent,
                      style: FilledButton.styleFrom(
                        backgroundColor: NeyvoColors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                      child: const Text('+ Create Agent'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onAddCredits,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NeyvoColors.textSecondary,
                        side: const BorderSide(color: NeyvoColors.borderDefault),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                      child: const Text('+ Add Credits'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
