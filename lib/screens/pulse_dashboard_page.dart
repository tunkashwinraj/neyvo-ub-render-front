// lib/screens/pulse_dashboard_page.dart
// Neyvo Pulse – School-focused dashboard (new structure, same theme).

import 'package:flutter/material.dart';

import '../pulse_route_names.dart';
import '../neyvo_pulse_api.dart';
import '../../theme/spearia_theme.dart';

class PulseDashboardPage extends StatefulWidget {
  const PulseDashboardPage({super.key});

  @override
  State<PulseDashboardPage> createState() => _PulseDashboardPageState();
}

class _PulseDashboardPageState extends State<PulseDashboardPage> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final reports = await NeyvoPulseApi.reportsSummary();
      final students = await NeyvoPulseApi.listStudents();
      final calls = await NeyvoPulseApi.listCalls();
      Map<String, dynamic>? successSummary;
      try {
        final res = await NeyvoPulseApi.getCallsSuccessSummary();
        successSummary = res['success_summary'] as Map<String, dynamic>?;
      } catch (_) {}
      
      if (mounted) {
        setState(() {
          _stats = {
            'total_students': (students['students'] as List?)?.length ?? 0,
            'total_balance': reports['summary']?['total_balance'] ?? 0.0,
            'total_calls': (calls['calls'] as List?)?.length ?? 0,
            'overdue_count': reports['summary']?['overdue_count'] ?? 0,
            'resolution_rate_pct': successSummary?['resolution_rate_pct'] ?? 0.0,
            'calls_with_payment_received': successSummary?['calls_with_payment_received'] ?? 0,
            'attributed_amount_total': successSummary?['attributed_amount_total'] ?? 0.0,
          };
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        children: [
          Text(
            'Dashboard',
            style: SpeariaType.headlineLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Manage balances, reminders, and outbound calls to students.',
            style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
          ),
          const SizedBox(height: SpeariaSpacing.xl),
          
          // Stats Cards
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(SpeariaSpacing.xl), child: CircularProgressIndicator()))
          else if (_stats != null) ...[
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Students',
                    value: '${_stats!['total_students']}',
                    icon: Icons.school_outlined,
                    color: SpeariaAura.primary,
                  ),
                ),
                const SizedBox(width: SpeariaSpacing.md),
                Expanded(
                  child: _StatCard(
                    label: 'Total Balance',
                    value: '\$${(_stats!['total_balance'] as num).toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet_outlined,
                    color: SpeariaAura.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpeariaSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Calls Made',
                    value: '${_stats!['total_calls']}',
                    icon: Icons.phone_outlined,
                    color: SpeariaAura.info,
                  ),
                ),
                const SizedBox(width: SpeariaSpacing.md),
                Expanded(
                  child: _StatCard(
                    label: 'Overdue',
                    value: '${_stats!['overdue_count']}',
                    icon: Icons.warning_amber_outlined,
                    color: SpeariaAura.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpeariaSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Resolution rate',
                    value: '${(_stats!['resolution_rate_pct'] as num).toStringAsFixed(1)}%',
                    icon: Icons.check_circle_outline,
                    color: SpeariaAura.success,
                  ),
                ),
                const SizedBox(width: SpeariaSpacing.md),
                Expanded(
                  child: _StatCard(
                    label: 'Revenue from calls',
                    value: '\$${(_stats!['attributed_amount_total'] as num).toStringAsFixed(0)}',
                    icon: Icons.payments_outlined,
                    color: SpeariaAura.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpeariaSpacing.xl),
          ],
          
          // Quick Actions
          Text(
            'Quick Actions',
            style: SpeariaType.titleLarge,
          ),
          const SizedBox(height: SpeariaSpacing.md),
          _DashboardCard(
            title: 'Outbound calls',
            subtitle: 'Call students about balances, due dates, and late fees',
            icon: Icons.phone_in_talk_outlined,
            color: SpeariaAura.primary,
            onTap: () => Navigator.of(context).pushNamed(PulseRouteNames.outbound),
          ),
          const SizedBox(height: SpeariaSpacing.md),
          _DashboardCard(
            title: 'Students',
            subtitle: 'View and manage student list',
            icon: Icons.school_outlined,
            color: SpeariaAura.accent,
            onTap: () => Navigator.of(context).pushNamed(PulseRouteNames.students),
          ),
          const SizedBox(height: SpeariaSpacing.md),
          _DashboardCard(
            title: 'Reminders',
            subtitle: 'Schedule payment reminders',
            icon: Icons.notifications_outlined,
            color: SpeariaAura.info,
            onTap: () => Navigator.of(context).pushNamed(PulseRouteNames.reminders),
          ),
          const SizedBox(height: SpeariaSpacing.md),
          _DashboardCard(
            title: 'Reports',
            subtitle: 'View financial reports and analytics',
            icon: Icons.assessment_outlined,
            color: SpeariaAura.success,
            onTap: () => Navigator.of(context).pushNamed(PulseRouteNames.reports),
          ),
          const SizedBox(height: SpeariaSpacing.md),
          _DashboardCard(
            title: 'Call Logs',
            subtitle: 'View call history, transcripts, and outcomes',
            icon: Icons.history,
            color: SpeariaAura.info,
            onTap: () => Navigator.of(context).pushNamed(PulseRouteNames.callHistory),
          ),
          const SizedBox(height: SpeariaSpacing.md),
          _DashboardCard(
            title: 'AI Insights',
            subtitle: 'Common questions, payment barriers, recommendations',
            icon: Icons.insights_outlined,
            color: SpeariaAura.primary,
            onTap: () => Navigator.of(context).pushNamed(PulseRouteNames.aiInsights),
          ),
          const SizedBox(height: SpeariaSpacing.md),
          _DashboardCard(
            title: 'Assistant Training',
            subtitle: 'FAQ and policy so the assistant knows your school',
            icon: Icons.menu_book_outlined,
            color: SpeariaAura.accent,
            onTap: () => Navigator.of(context).pushNamed(PulseRouteNames.training),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(SpeariaSpacing.lg),
          decoration: SpeariaFX.statCard(accentColor: color),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 24),
                  Text(
                    value,
                    style: SpeariaType.headlineMedium.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpeariaSpacing.sm),
              Text(
                label,
                style: SpeariaType.bodySmall.copyWith(
                  color: SpeariaAura.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Left accent border
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(SpeariaRadius.md),
                bottomLeft: Radius.circular(SpeariaRadius.md),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SpeariaRadius.md),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(SpeariaSpacing.lg),
              decoration: SpeariaFX.statCard(accentColor: color),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(SpeariaSpacing.md),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(SpeariaRadius.sm),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: SpeariaSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: SpeariaType.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: SpeariaType.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: SpeariaAura.textMuted),
                ],
              ),
            ),
            // Left accent border
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(SpeariaRadius.md),
                    bottomLeft: Radius.circular(SpeariaRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
