// lib/neyvo_pulse/pulse_route_names.dart
// Route path constants only (no screen imports).

abstract class PulseRouteNames {
  static const String auth = '/pulse/auth';
  static const String dashboard = '/pulse/home';
  static const String launch = '/pulse/launch';
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
  /// Deprecated: audit log removed; deep links redirect to dashboard.
  static const String auditLog = '/pulse/audit-log';
  // Canonical integrations route for Voice OS.
  static const String integrations = '/pulse/integrations';
  // Legacy alias (do not use in new UI).
  static const String integration = '/pulse/integration';
  static const String campaigns = '/pulse/campaigns';
  static const String team = '/pulse/team';
  static const String templateScripts = '/pulse/template-scripts';
  static const String wallet = '/pulse/wallet';
  static const String usage = '/pulse/usage';
  static const String voiceTier = '/pulse/voice-tier';
  static const String developerConsole = '/pulse/developer-console';
  static const String phoneNumbers = '/pulse/lines';
  static const String calls = '/pulse/call-logs';
  static const String dialer = '/pulse/dialer';
  static const String billing = '/pulse/billing';
  static const String subscriptionPlan = '/pulse/subscription-plan';
  static const String addons = '/pulse/addons';
  static const String agents = '/pulse/operators';
  static const String agentDetail = '/pulse/agent-detail';
  static const String managedProfiles = '/pulse/managed-profiles';
  static const String managedProfileDetail = '/pulse/managed-profile-detail';
  static const String universalOperatorWizard = '/pulse/universal-operator-wizard';
  static const String agency = '/pulse/agency';
  static const String callbacks = '/pulse/callbacks';
  static const String onboarding = '/onboarding';
  static const String workflows = '/pulse/workflows';
  static const String projects = '/pulse/projects';
  static const String projectDetail = '/pulse/project-detail';
  static const String voiceLibrary = '/pulse/voice-library';
  static const String exports = '/pulse/exports';
  static const String analytics = '/pulse/insights';
  static const String executiveDashboard = '/pulse/executive-dashboard';
  static const String businessSetup = '/pulse/business-setup';
  static const String setupCenter = '/pulse/setup';
  static const String voiceStudio = '/pulse/voice-studio';
  static const String testCall = '/pulse/test-call';
  static const String ubModelOverview = '/pulse/ub-model-overview';
  static const String health = '/pulse/health-check';

  // ARIA Operators (raw paths, separate from managed_profiles)
  static const String operatorsRoot = '/operators';
  static const String operatorsNew = '/operators/new';
  // Dynamic segments handled by PulseRouter:
  // - /operators/building/{operator_id}
  // - /operators/{operator_id}
  // - /operators/{operator_id}/optimization
  static String operatorsOptimization(String operatorId) => '/operators/$operatorId/optimization';

  // Admin-only (not in sidebar; gate by admin email when ready)
  static const String adminConsole = '/admin/console';
  /// Deprecated: audit log removed.
  static const String adminAuditLog = '/admin/audit-log';
  static const String adminBackendTest = '/admin/backend-test';
  // Internal ops (not in sidebar)
  static const String internalBackups = '/internal/backups';
}
