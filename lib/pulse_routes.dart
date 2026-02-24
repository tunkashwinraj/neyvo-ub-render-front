// lib/pulse_routes.dart
import 'package:flutter/material.dart';

import 'pulse_route_names.dart';
import 'screens/agents_list_page.dart';
import 'screens/outbound_calls_page.dart';
import 'screens/pulse_auth_page.dart';
import 'screens/pulse_shell.dart';
import 'screens/students_list_page.dart';
import 'screens/reminders_page.dart';
import 'screens/reports_page.dart';
import 'screens/settings_page.dart';
import 'screens/backend_test_page.dart';
import 'screens/call_history_page.dart';
import 'screens/payments_page.dart';
import 'screens/ai_insights_page.dart';
import 'screens/training_page.dart';
import 'screens/audit_log_page.dart';
import 'screens/integration_page.dart';
import 'screens/campaigns_page.dart';
import 'screens/template_scripts_page.dart';
import 'screens/plan_selector_page.dart';
import 'screens/onboarding_page.dart';
import 'screens/agent_detail_page.dart';
import 'screens/projects_list_page.dart';
import 'screens/project_detail_page.dart';

class PulseRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case PulseRouteNames.auth:
        return MaterialPageRoute(builder: (_) => const PulseAuthPage());
      case PulseRouteNames.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingPage());
      case PulseRouteNames.agents:
        // Keep drawer visible by routing through PulseShell.
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.agents));
      case PulseRouteNames.agentDetail:
        final agentId = settings.arguments as String? ?? '';
        return MaterialPageRoute(builder: (_) => AgentDetailPage(agentId: agentId));
      case PulseRouteNames.projects:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.projects));
      case PulseRouteNames.voiceLibrary:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.voiceLibrary));
      case PulseRouteNames.exports:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.exports));
      case PulseRouteNames.analytics:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.analytics));
      case PulseRouteNames.projectDetail:
        final projectId = settings.arguments as String? ?? '';
        return MaterialPageRoute(builder: (_) => ProjectDetailPage(projectId: projectId));
      case PulseRouteNames.dashboard:
      case PulseRouteNames.campaigns:
        return MaterialPageRoute(builder: (_) => const PulseShell());
      case PulseRouteNames.templateScripts:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.templateScripts));
      case PulseRouteNames.wallet:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.wallet));
      case PulseRouteNames.usage:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.usage));
      case PulseRouteNames.voiceTier:
        // Voice tier lives under Settings → Billing (inside PulseShell).
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.settings));
      case PulseRouteNames.developerConsole:
        return MaterialPageRoute(builder: (_) => const BackendTestPage());
      case PulseRouteNames.subscriptionPlan:
        // Plan selection lives under Settings → Billing (inside PulseShell).
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.settings));
      case PulseRouteNames.addons:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.addons));
      case PulseRouteNames.outbound:
        return MaterialPageRoute(builder: (_) => const OutboundCallsPage());
      case PulseRouteNames.students:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.students));
      case PulseRouteNames.reminders:
        return MaterialPageRoute(builder: (_) => const RemindersPage());
      case PulseRouteNames.reports:
        return MaterialPageRoute(builder: (_) => const ReportsPage());
      case PulseRouteNames.settings:
        // Settings must stay inside PulseShell so the drawer remains visible.
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.settings));
      case PulseRouteNames.backendTest:
        return MaterialPageRoute(builder: (_) => const BackendTestPage());
      case PulseRouteNames.callHistory:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.callHistory));
      case PulseRouteNames.payments:
        return MaterialPageRoute(builder: (_) => const PaymentsPage());
      case PulseRouteNames.aiInsights:
        return MaterialPageRoute(builder: (_) => const AiInsightsPage());
      case PulseRouteNames.training:
        return MaterialPageRoute(builder: (_) => const TrainingPage());
      case PulseRouteNames.auditLog:
        return MaterialPageRoute(builder: (_) => const AuditLogPage());
      case PulseRouteNames.integration:
        return MaterialPageRoute(builder: (_) => const IntegrationPage());
      case PulseRouteNames.phoneNumbers:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.phoneNumbers));
      case PulseRouteNames.callbacks:
        return MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.callbacks));
      default:
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
