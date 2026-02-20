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
import 'template_scripts_page.dart';
import '../../theme/spearia_theme.dart';

class PulseShell extends StatefulWidget {
  const PulseShell({super.key});

  @override
  State<PulseShell> createState() => _PulseShellState();
}

class _PulseShellState extends State<PulseShell> {
  int _selectedIndex = 0;

  // Single source of truth: nav items and pages in same order (index i = page i)
  static final List<_NavItem> _nav = [
    _NavItem('Dashboard', Icons.dashboard_outlined, PulseRouteNames.dashboard),
    _NavItem('Students', Icons.school_outlined, PulseRouteNames.students),
    _NavItem('Calls', Icons.phone_in_talk_outlined, PulseRouteNames.outbound),
    _NavItem('Campaigns', Icons.campaign_outlined, PulseRouteNames.campaigns),
    _NavItem('Reminders', Icons.notifications_outlined, PulseRouteNames.reminders),
    _NavItem('Reports', Icons.assessment_outlined, PulseRouteNames.reports),
    _NavItem('AI Insights', Icons.insights_outlined, PulseRouteNames.aiInsights),
    _NavItem('Scripts', Icons.description_outlined, PulseRouteNames.templateScripts),
    _NavItem('Training', Icons.menu_book_outlined, PulseRouteNames.training),
    _NavItem('Audit log', Icons.history, PulseRouteNames.auditLog),
    _NavItem('Settings', Icons.settings_outlined, PulseRouteNames.settings),
    _NavItem('Data integration', Icons.integration_instructions_outlined, PulseRouteNames.integration),
    _NavItem('Backend Test', Icons.network_check_outlined, PulseRouteNames.backendTest),
  ];

  List<Widget> get _pages => [
    const PulseDashboardPage(),
    const StudentsListPage(),
    const OutboundCallsPage(),
    const CampaignsPage(),
    const RemindersPage(),
    const ReportsPage(),
    const AiInsightsPage(),
    const TemplateScriptsPage(),
    const TrainingPage(),
    const AuditLogPage(),
    const PulseSettingsPage(),
    const IntegrationPage(),
    const BackendTestPage(),
  ];

  @override
  void initState() {
    super.initState();
    if (kIsWeb) debugPrint('PulseShell initialized');
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
                        selected: selected,
                        selectedTileColor: SpeariaAura.primary.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onTap: () => setState(() => _selectedIndex = i),
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
