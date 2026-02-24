// lib/neyvo_pulse/pulse_route_names.dart
// Route path constants only (no screen imports).

abstract class PulseRouteNames {
  static const String auth = '/pulse/auth';
  static const String dashboard = '/pulse/dashboard';
  static const String outbound = '/pulse/outbound';
  static const String students = '/pulse/students';
  static const String reminders = '/pulse/reminders';
  static const String reports = '/pulse/reports';
  static const String settings = '/pulse/settings';
  static const String backendTest = '/pulse/backend-test';
  static const String callHistory = '/pulse/call-history';
  static const String payments = '/pulse/payments';
  static const String aiInsights = '/pulse/ai-insights';
  static const String training = '/pulse/training';
  static const String auditLog = '/pulse/audit-log';
  static const String integration = '/pulse/integration';
  static const String campaigns = '/pulse/campaigns';
  static const String templateScripts = '/pulse/template-scripts';
  static const String wallet = '/pulse/wallet';
  static const String usage = '/pulse/usage';
  static const String voiceTier = '/pulse/voice-tier';
  static const String developerConsole = '/pulse/developer-console';
  static const String phoneNumbers = '/pulse/phone-numbers';
  static const String subscriptionPlan = '/pulse/subscription-plan';
  static const String addons = '/pulse/addons';
  static const String agents = '/pulse/agents';
  static const String agentDetail = '/pulse/agent-detail';
  static const String callbacks = '/pulse/callbacks';
  static const String onboarding = '/onboarding';
  static const String workflows = '/pulse/workflows';
  static const String projects = '/pulse/projects';
  static const String projectDetail = '/pulse/project-detail';
  static const String voiceLibrary = '/pulse/voice-library';
  static const String exports = '/pulse/exports';
  static const String analytics = '/pulse/analytics';

  // Admin-only (not in sidebar; gate by admin email when ready)
  static const String adminConsole = '/admin/console';
  static const String adminAuditLog = '/admin/audit-log';
  static const String adminBackendTest = '/admin/backend-test';
}
