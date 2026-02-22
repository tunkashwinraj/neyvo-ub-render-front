// lib/screens/pulse_dashboard_page.dart
// Neyvo Pulse – School-focused dashboard (new structure, same theme).

import 'package:flutter/material.dart';

import '../pulse_route_names.dart';
import '../neyvo_pulse_api.dart';
import '../../theme/spearia_theme.dart';
import 'phone_numbers_page.dart';

class PulseDashboardPage extends StatefulWidget {
  const PulseDashboardPage({super.key});

  @override
  State<PulseDashboardPage> createState() => _PulseDashboardPageState();
}

class _PulseDashboardPageState extends State<PulseDashboardPage> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  int? _callsTodayUsed;
  int? _callsTodayCapacity;
  final _campaignContactsController = TextEditingController(text: '1000');
  int _campaignContacts = 1000;
  List<Map<String, dynamic>>? _campaignScenarios;
  bool _campaignLoading = false;
  Map<String, dynamic>? _numbersSummary;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _campaignContactsController.addListener(() {
      final v = int.tryParse(_campaignContactsController.text.replaceAll(RegExp(r'\D'), ''));
      if (v != null && v != _campaignContacts) setState(() => _campaignContacts = v);
    });
    _loadCampaignScenarios();
    _loadNumbersSummary();
  }

  @override
  void dispose() {
    _campaignContactsController.dispose();
    super.dispose();
  }

  Future<void> _loadCampaignScenarios() async {
    if (_campaignContacts < 1) return;
    setState(() => _campaignLoading = true);
    try {
      final res = await NeyvoPulseApi.campaignEstimateQuick(contacts: _campaignContacts);
      final list = (res['scenarios'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() {
        _campaignScenarios = list;
        _campaignLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _campaignLoading = false);
    }
  }

  Future<void> _loadNumbersSummary() async {
    try {
      final res = await NeyvoPulseApi.listNumbers();
      if (mounted) setState(() => _numbersSummary = res);
    } catch (_) {}
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
      int callsUsed = 0;
      int capacity = 0;
      try {
        final numbersRes = await NeyvoPulseApi.listNumbers();
        final numbers = numbersRes['numbers'] as List? ?? [];
        capacity = (numbersRes['total_daily_capacity'] as num?)?.toInt() ?? 0;
        for (final n in numbers) {
          callsUsed += (n['calls_today'] as num?)?.toInt() ?? 0;
        }
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
          _callsTodayUsed = callsUsed;
          _callsTodayCapacity = capacity;
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
            'Manage balances, reminders, and reach out to contacts.',
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
                    label: 'Contacts',
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
                    label: 'Reaches',
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
            if (_callsTodayCapacity != null && _callsTodayCapacity! > 0)
              Padding(
                padding: const EdgeInsets.only(top: SpeariaSpacing.md),
                child: InkWell(
                  onTap: () => Navigator.of(context).pushNamed(PulseRouteNames.phoneNumbers),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: SpeariaAura.bgDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SpeariaAura.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 20, color: SpeariaAura.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Reaches today: ${_callsTodayUsed ?? 0} / $_callsTodayCapacity capacity',
                          style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
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
            title: 'Reach out',
            subtitle: 'Reach out to contacts about balances, due dates, and late fees',
            icon: Icons.phone_in_talk_outlined,
            color: SpeariaAura.primary,
            onTap: () => Navigator.of(context).pushNamed(PulseRouteNames.outbound),
          ),
          const SizedBox(height: SpeariaSpacing.md),
          _DashboardCard(
            title: 'Contacts',
            subtitle: 'View and manage your contact list',
            icon: Icons.contacts_outlined,
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
            title: 'Reach history',
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
          const SizedBox(height: SpeariaSpacing.xl),
          // Campaign Planner
          Text('Campaign Planner', style: SpeariaType.titleLarge),
          const SizedBox(height: 8),
          Text(
            'See how many days to complete a campaign and how adding numbers speeds it up.',
            style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted),
          ),
          const SizedBox(height: SpeariaSpacing.md),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: SpeariaAura.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(SpeariaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('How many contacts do you need to call?', style: SpeariaType.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _campaignContactsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _loadCampaignScenarios(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _campaignLoading ? null : () => _loadCampaignScenarios(),
                        child: _campaignLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Update'),
                      ),
                    ],
                  ),
                  if (_numbersSummary != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Overall today: ${_callsTodayUsed ?? 0} / ${_callsTodayCapacity ?? 0} calls used across ${(_numbersSummary!['total_numbers'] as num?)?.toInt() ?? 0} numbers',
                      style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary),
                    ),
                  ],
                  if (_campaignScenarios != null && _campaignScenarios!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Setup')),
                          DataColumn(label: Text('Daily capacity')),
                          DataColumn(label: Text('Days to complete')),
                          DataColumn(label: Text('Monthly cost')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _campaignScenarios!.map((s) {
                          final numbers = (s['numbers'] as num?)?.toInt() ?? 0;
                          final capacity = (s['daily_capacity'] as num?)?.toInt() ?? 0;
                          final days = (s['days'] as num?)?.toInt() ?? 0;
                          final cost = s['monthly_cost']?.toString() ?? '\$0';
                          return DataRow(
                            cells: [
                              DataCell(Text(numbers == 1 ? 'Your current 1 number' : '+ ${numbers - 1} more number${numbers > 2 ? 's' : ''}')),
                              DataCell(Text('$capacity/day')),
                              DataCell(Text('$days days')),
                              DataCell(Text(cost)),
                              DataCell(
                                TextButton(
                                  onPressed: () {
                                    showBuyNumberModal(context, onDone: () {
                                      _loadStats();
                                      _loadNumbersSummary();
                                      _loadCampaignScenarios();
                                    });
                                  },
                                  child: const Text('Add number'),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
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
