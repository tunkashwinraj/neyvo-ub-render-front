// lib/pulse_routes.dart
import 'package:flutter/material.dart';

import 'debug_session_log.dart';
import 'pulse_route_names.dart';
import 'screens/pulse_auth_page.dart';
import 'screens/pulse_shell.dart';
import 'screens/training_page.dart';
import 'screens/onboarding_page.dart';
import 'screens/agent_detail_page.dart';
import 'ui/screens/calls/calls_section.dart';
import 'ui/screens/calls/test_call_page.dart';
import 'ui/screens/ub/ub_model_overview_page.dart';
import 'screens/developer_console_page.dart';
import 'features/operators/universal_operator_wizard/universal_operator_wizard_screen.dart';
import 'ui/screens/internal/backup_rollback_page.dart';

/// Maps legacy Pulse paths to canonical (tab-matching) route names for deep links.
String? _legacyPulsePathToCanonical(String path) {
  switch (path) {
    case '/pulse/dashboard':
      return PulseRouteNames.dashboard;
    case '/pulse/agents':
      return PulseRouteNames.agents;
    case '/pulse/phone-numbers':
      return PulseRouteNames.phoneNumbers;
    case '/pulse/calls':
      return PulseRouteNames.calls;
    case '/pulse/analytics':
      return PulseRouteNames.analytics;
    case '/pulse/executive-dashboard':
      return PulseRouteNames.executiveDashboard;
    default:
      return null;
  }
}

class PulseRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // #region agent log
    final name = settings.name ?? '';
    if (name.isNotEmpty && (name.startsWith('/pulse/') || name == PulseRouteNames.auth || name == PulseRouteNames.onboarding)) {
      debugSessionLog('pulse_routes.dart:generateRoute', 'generateRoute called', {'routeName': name}, 'A');
    }
    // #endregion
    switch (settings.name) {
      case PulseRouteNames.internalBackups:
        // Internal ops page (not shown in sidebar).
        return MaterialPageRoute(builder: (_) => const BackupRollbackPage());
      case PulseRouteNames.auth:
        return MaterialPageRoute(builder: (_) => const PulseAuthPage());
      case PulseRouteNames.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingPage());
      case PulseRouteNames.launch:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.launch));
      case PulseRouteNames.setupCenter:
        // Setup Center is replaced by Launch Wizard.
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.launch));
      case PulseRouteNames.agents:
        // Keep drawer visible by routing through PulseShell.
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.agents));
      case PulseRouteNames.calls:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.calls));
      case PulseRouteNames.students:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.students));
      case PulseRouteNames.campaigns:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.campaigns));
      case PulseRouteNames.team:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.team));
      case PulseRouteNames.outbound:
        // Legacy outbound route -> Calls/Dialer.
        return MaterialPageRoute(
          builder: (_) => const PulseShell(
            initialRouteName: PulseRouteNames.calls,
            initialCallsSection: CallsSection.dialer,
          ),
        );
      case PulseRouteNames.dialer:
        return MaterialPageRoute(
          builder: (_) => const PulseShell(
            initialRouteName: PulseRouteNames.calls,
            initialCallsSection: CallsSection.dialer,
          ),
        );
      case PulseRouteNames.agentDetail:
        final agentId = settings.arguments as String? ?? '';
        return MaterialPageRoute(builder: (_) => AgentDetailPage(agentId: agentId));
      case PulseRouteNames.managedProfiles:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.managedProfiles));
      case PulseRouteNames.managedProfileDetail:
        // Open Pulse shell on Operators tab and push profile detail (use .agents so shell selects Operators, not Home).
        final profileId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => PulseShell(
            initialRouteName: PulseRouteNames.agents,
            initialProfileId: profileId,
          ),
        );
      case PulseRouteNames.universalOperatorWizard:
        return MaterialPageRoute(builder: (_) => const UniversalOperatorWizardScreen());
      case PulseRouteNames.analytics:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.analytics));
      case PulseRouteNames.executiveDashboard:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.executiveDashboard));
      case PulseRouteNames.billing:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.billing));
      case PulseRouteNames.wallet:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.wallet));
      case PulseRouteNames.usage:
      case PulseRouteNames.addons:
      case PulseRouteNames.payments:
        // Billing is unified in one page for Voice OS.
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.billing));
      case PulseRouteNames.voiceTier:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.voiceTier));
      case PulseRouteNames.subscriptionPlan:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.subscriptionPlan));
      case PulseRouteNames.developerConsole:
        return MaterialPageRoute(builder: (_) => const DeveloperConsolePage());
      case PulseRouteNames.settings:
        // Settings must stay inside PulseShell so the drawer remains visible.
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.settings));
      case PulseRouteNames.training:
        return MaterialPageRoute(builder: (_) => const TrainingPage());
      case PulseRouteNames.auditLog:
        // Audit log feature removed — land on dashboard.
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.dashboard));
      case PulseRouteNames.integrations:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.integrations));
      case PulseRouteNames.integration:
        // Legacy alias.
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.integrations));
      case PulseRouteNames.phoneNumbers:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.phoneNumbers));
      case PulseRouteNames.agency:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.agency));
      case PulseRouteNames.voiceStudio:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.voiceStudio));
      case PulseRouteNames.testCall:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.testCall));
      case PulseRouteNames.ubModelOverview:
        return MaterialPageRoute(builder: (_) => const UbModelOverviewPage());
      case PulseRouteNames.dashboard:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.dashboard));
      default:
        if ((settings.name ?? '').startsWith('/pulse/')) {
          // Legacy path → canonical (tab-matching) route so old deep links open the correct tab.
          final name = settings.name!;
          final canonical = _legacyPulsePathToCanonical(name);
          return MaterialPageRoute(
            builder: (_) => PulseShell(initialRouteName: canonical ?? name),
          );
        }
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Page not found', style: TextStyle(fontSize: 16)),
            ),
          ),
        );
    }
  }
}
