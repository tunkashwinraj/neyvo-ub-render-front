// lib/neyvo_pulse/pulse_routes.dart
import 'package:flutter/material.dart';

import 'pulse_route_names.dart';
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

class PulseRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case PulseRouteNames.auth:
        return MaterialPageRoute(builder: (_) => const PulseAuthPage());
      case PulseRouteNames.dashboard:
      case PulseRouteNames.campaigns:
      case PulseRouteNames.templateScripts:
        return MaterialPageRoute(builder: (_) => const PulseShell());
      case PulseRouteNames.outbound:
        return MaterialPageRoute(builder: (_) => const OutboundCallsPage());
      case PulseRouteNames.students:
        return MaterialPageRoute(builder: (_) => const StudentsListPage());
      case PulseRouteNames.reminders:
        return MaterialPageRoute(builder: (_) => const RemindersPage());
      case PulseRouteNames.reports:
        return MaterialPageRoute(builder: (_) => const ReportsPage());
      case PulseRouteNames.settings:
        return MaterialPageRoute(builder: (_) => const PulseSettingsPage());
      case PulseRouteNames.backendTest:
        return MaterialPageRoute(builder: (_) => const BackendTestPage());
      case PulseRouteNames.callHistory:
        return MaterialPageRoute(builder: (_) => const CallHistoryPage());
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
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Pulse: route not found', style: TextStyle(fontSize: 16)),
            ),
          ),
        );
    }
  }
}
