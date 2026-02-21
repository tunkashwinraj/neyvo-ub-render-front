// lib/screens/pulse_shell.dart
// Neyvo Pulse – main shell with persistent sidebar (always visible).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../pulse_route_names.dart';
import 'pulse_dashboard_page.dart';
import 'students_list_page.dart';
import 'outbound_calls_page.dart';
import 'reminders_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import 'backend_test_page.dart';
import 'ai_insights_page.dart';
import 'training_page.dart';
import 'audit_log_page.dart';
import 'integration_page.dart';
import 'campaigns_page.dart';
import 'phone_numbers_page.dart';
import 'template_scripts_page.dart';
import 'wallet_page.dart';
import 'usage_page.dart';
import 'voice_tier_page.dart';
import 'developer_console_page.dart';
import '../neyvo_pulse_api.dart';
import '../theme/spearia_theme.dart';

class PulseShell extends StatefulWidget {
  const PulseShell({super.key, this.initialRouteName});

  final String? initialRouteName;

  @override
  State<PulseShell> createState() => _PulseShellState();
}

class _PulseShellState extends State<PulseShell> {
  int _selectedIndex = 0;
  int? _walletCredits;
  int? _numbersCount;
  int? _callsTodayCapacity;
  int? _callsTodayUsed;

  // Single source of truth: nav items and pages in same order (index i = page i)
  static List<_NavItem> get _nav => [
    const _NavItem('Dashboard', Icons.dashboard_outlined, PulseRouteNames.dashboard),
    const _NavItem('Students', Icons.school_outlined, PulseRouteNames.students),
    const _NavItem('Calls', Icons.phone_in_talk_outlined, PulseRouteNames.outbound),
    const _NavItem('Phone Numbers', Icons.phone_outlined, PulseRouteNames.phoneNumbers),
    const _NavItem('Campaigns', Icons.campaign_outlined, PulseRouteNames.campaigns),
    const _NavItem('Reminders', Icons.notifications_outlined, PulseRouteNames.reminders),
    const _NavItem('Reports', Icons.assessment_outlined, PulseRouteNames.reports),
    const _NavItem('Wallet', Icons.account_balance_wallet_outlined, PulseRouteNames.wallet),
    const _NavItem('Usage', Icons.bar_chart_outlined, PulseRouteNames.usage),
    const _NavItem('Voice tier', Icons.record_voice_over_outlined, PulseRouteNames.voiceTier),
    const _NavItem('AI Insights', Icons.insights_outlined, PulseRouteNames.aiInsights),
    const _NavItem('Scripts', Icons.description_outlined, PulseRouteNames.templateScripts),
    const _NavItem('Training', Icons.menu_book_outlined, PulseRouteNames.training),
    const _NavItem('Audit log', Icons.history, PulseRouteNames.auditLog),
    const _NavItem('Settings', Icons.settings_outlined, PulseRouteNames.settings),
    const _NavItem('Data integration', Icons.integration_instructions_outlined, PulseRouteNames.integration),
    const _NavItem('Backend Test', Icons.network_check_outlined, PulseRouteNames.backendTest),
    const _NavItem('Developer Console', Icons.code_outlined, PulseRouteNames.developerConsole),
  ];

  List<Widget> get _pages => [
    const PulseDashboardPage(),
    const StudentsListPage(),
    const OutboundCallsPage(),
    const PhoneNumbersPage(),
    const CampaignsPage(),
    const RemindersPage(),
    const ReportsPage(),
    const WalletPage(),
    const UsagePage(),
    const VoiceTierPage(),
    const AiInsightsPage(),
    const TemplateScriptsPage(),
    const TrainingPage(),
    const AuditLogPage(),
    const PulseSettingsPage(),
    const IntegrationPage(),
    const BackendTestPage(),
    const DeveloperConsolePage(),
  ];

  @override
  void initState() {
    super.initState();
    if (kIsWeb) debugPrint('PulseShell initialized');
    _loadWalletCredits();
    _loadNumbersSummary();
    final name = widget.initialRouteName;
    if (name != null && name.isNotEmpty) {
      final idx = _nav.indexWhere((n) => n.route == name);
      if (idx >= 0) _selectedIndex = idx;
    }
  }

  Future<void> _loadWalletCredits() async {
    try {
      final w = await NeyvoPulseApi.getBillingWallet();
      if (mounted) setState(() => _walletCredits = (w['credits'] as num?)?.toInt());
    } catch (_) {}
  }

  Future<void> _loadNumbersSummary() async {
    try {
      final res = await NeyvoPulseApi.listNumbers();
      if (mounted) {
        setState(() {
          _numbersCount = (res['total_numbers'] as num?)?.toInt();
          _callsTodayCapacity = (res['total_daily_capacity'] as num?)?.toInt();
          final numbers = res['numbers'] as List? ?? [];
          int used = 0;
          for (final n in numbers) {
            used += (n['calls_today'] as num?)?.toInt() ?? 0;
          }
          _callsTodayUsed = used;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) debugPrint('PulseShell building (index: $_selectedIndex)');

    return Scaffold(
      backgroundColor: SpeariaAura.bg,
      body: Row(
        children: [
          // Persistent sidebar (always visible)
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: SpeariaAura.surface,
              border: Border(right: BorderSide(color: SpeariaAura.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Neyvo Pulse',
                    style: SpeariaType.titleLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: SpeariaAura.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: _nav.length,
                    itemBuilder: (context, i) {
                      final item = _nav[i];
                      final selected = _selectedIndex == i;
                      String? subtitle;
                      if (item.label == 'Wallet' && _walletCredits != null) {
                        subtitle = '${_walletCredits!.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} credits';
                      } else if (item.label == 'Phone Numbers' && _numbersCount != null) {
                        subtitle = '$_numbersCount number${_numbersCount == 1 ? '' : 's'}';
                      }
                      return ListTile(
                        leading: Icon(
                          item.icon,
                          size: 22,
                          color: selected ? SpeariaAura.primary : SpeariaAura.iconMuted,
                        ),
                        title: Text(
                          item.label,
                          style: SpeariaType.bodyMedium.copyWith(
                            color: selected ? SpeariaAura.primary : SpeariaAura.textPrimary,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        subtitle: subtitle != null ? Text(subtitle, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)) : null,
                        selected: selected,
                        selectedTileColor: SpeariaAura.primary.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onTap: () {
                          setState(() => _selectedIndex = i);
                          if (item.label == 'Wallet') _loadWalletCredits();
                          if (item.label == 'Phone Numbers') _loadNumbersSummary();
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, size: 22, color: SpeariaAura.textMuted),
                  title: Text('Sign out', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary)),
                  onTap: () async => await FirebaseAuth.instance.signOut(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_walletCredits != null && _walletCredits! < 500 && _walletCredits! >= 0)
                  Material(
                    color: SpeariaAura.warning.withOpacity(0.15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: SpeariaAura.warning, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Low credits — $_walletCredits remaining. Top up to keep calls running.',
                              style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textPrimary),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _selectedIndex = _nav.indexWhere((n) => n.label == 'Wallet')),
                            child: const Text('Top up'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: SpeariaAura.surface,
                    border: Border(bottom: BorderSide(color: SpeariaAura.border)),
                  ),
                  child: Text(
                    _nav[_selectedIndex].label,
                    style: SpeariaType.headlineMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: _selectedIndex < _pages.length
                      ? _pages[_selectedIndex]
                      : const PulseDashboardPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}
