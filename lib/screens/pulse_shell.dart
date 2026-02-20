// lib/neyvo_pulse/screens/pulse_shell.dart
// Neyvo Pulse – main shell with navigation (clean minimal layout).

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
import '../../theme/spearia_theme.dart';

class PulseShell extends StatefulWidget {
  const PulseShell({super.key});

  @override
  State<PulseShell> createState() => _PulseShellState();
}

class _PulseShellState extends State<PulseShell> {
  int _selectedIndex = 0;
  static const List<_NavItem> _nav = [
    _NavItem('Dashboard', Icons.dashboard_outlined, PulseRouteNames.dashboard),
    _NavItem('Students', Icons.school_outlined, PulseRouteNames.students),
    _NavItem('Calls', Icons.phone_in_talk_outlined, PulseRouteNames.outbound),
    _NavItem('Reminders', Icons.notifications_outlined, PulseRouteNames.reminders),
    _NavItem('Reports', Icons.assessment_outlined, PulseRouteNames.reports),
    _NavItem('AI Insights', Icons.insights_outlined, PulseRouteNames.aiInsights),
    _NavItem('Training', Icons.menu_book_outlined, PulseRouteNames.training),
    _NavItem('Audit log', Icons.history, PulseRouteNames.auditLog),
    _NavItem('Settings', Icons.settings_outlined, PulseRouteNames.settings),
    _NavItem('Backend Test', Icons.network_check_outlined, PulseRouteNames.backendTest),
  ];

  Widget _page() {
    switch (_selectedIndex) {
      case 0:
        return const PulseDashboardPage();
      case 1:
        return const StudentsListPage();
      case 2:
        return const OutboundCallsPage();
      case 3:
        return const RemindersPage();
      case 4:
        return const ReportsPage();
      case 5:
        return const AiInsightsPage();
      case 6:
        return const TrainingPage();
      case 7:
        return const PulseSettingsPage();
      case 8:
        return const BackendTestPage();
      default:
        return const PulseDashboardPage();
    }
  }

  @override
  void initState() {
    super.initState();
    // Debug: verify widget is building
    if (kIsWeb) {
      print('📊 PulseShell initialized');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug: verify build is called
    if (kIsWeb) {
      print('🔨 PulseShell building (index: $_selectedIndex)');
    }
    
    return Scaffold(
      backgroundColor: SpeariaAura.bg,
      appBar: AppBar(
        title: Text(_nav[_selectedIndex].label),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: SpeariaAura.primary),
              child: Text(
                'Neyvo Pulse',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...List.generate(_nav.length, (i) {
              final item = _nav[i];
              return ListTile(
                leading: Icon(item.icon, color: _selectedIndex == i ? SpeariaAura.primary : SpeariaAura.textMuted),
                title: Text(item.label),
                selected: _selectedIndex == i,
                onTap: () {
                  setState(() => _selectedIndex = i);
                  Navigator.pop(context);
                },
              );
            }),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: SpeariaAura.textMuted),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),
      body: _page(),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}
