  import 'dart:async';

  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'package:flutter/foundation.dart' show kIsWeb;
  import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:timezone/data/latest.dart' as tz;

import 'api/neyvo_api.dart';
import 'core/providers/account_provider.dart';
import 'core/providers/timezone_provider.dart';
import 'services/user_timezone_service.dart';
import 'firebase_options.dart';
import 'neyvo_pulse_api.dart';
import 'pulse_route_names.dart';
import 'pulse_routes.dart';
import 'screens/pulse_auth_page.dart';
import 'screens/pulse_shell.dart';
import 'tenant/tenant_config.dart';
import 'tenant/tenant_scope.dart';
import 'theme/neyvo_theme.dart';
import 'widgets/inactivity_detector.dart';
import 'widgets/neyvo_loading_screen.dart';

  const String _kOnboardingCompletedKey = 'neyvo_pulse_onboarding_completed';
const String _kDefaultBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://fallback-url.onrender.com',
);
  /// Backend URL for the staging/testing frontend (e.g. Render service on Testing branch).
  /// Build: flutter build web --dart-define=API_BASE_URL_STAGING=https://your-staging-back.onrender.com
  /// If not set, staging uses the same URL as prod (single Render service).
  const String _kStagingBaseUrl = String.fromEnvironment(
    'API_BASE_URL_STAGING',
  defaultValue: _kDefaultBaseUrl,
  );

/// When true (e.g. --dart-define=FORCE_STAGING=true), treat localhost as staging so local matches staging behavior.
const bool _kForceStaging = bool.fromEnvironment('FORCE_STAGING', defaultValue: false);

/// True when the app is running on the Firebase staging host (e.g. ub-neyvo-staging.web.app).
bool get _isStagingHost {
  if (_kForceStaging && kIsWeb) return true;
  if (!kIsWeb) return false;
  final host = Uri.base.host.toLowerCase();
  return host.contains('staging') || host.endsWith('-staging.web.app') || host.endsWith('-staging.firebaseapp.com');
}

String _resolveBaseUrlForEnvironment() {
  // Staging frontend (Firebase staging site) talks to testing backend (e.g. Render Testing branch).
  if (_isStagingHost) return _kStagingBaseUrl;

  // Organization-only deployment: use configured base URL.
  return _kDefaultBaseUrl;
}
/// Fallback account_id when getAccountInfo fails or returns empty (Goodwin-only deployment).
/// Build: flutter build web --dart-define=NEYVO_ACCOUNT_ID=757763
String get _kFallbackAccountId {
  const fromEnv = String.fromEnvironment('NEYVO_ACCOUNT_ID', defaultValue: '');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (NeyvoApi.baseUrl.contains(Uri.parse(_kDefaultBaseUrl).host)) return '757763';
  return '';
}

  Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
    }

  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    NeyvoApi.setUserId(user?.uid);
    if (user == null) NeyvoPulseApi.setDefaultAccountId(null);
  });
  NeyvoApi.setUserId(FirebaseAuth.instance.currentUser?.uid);
  if (FirebaseAuth.instance.currentUser == null) NeyvoPulseApi.setDefaultAccountId(null);

  final baseUrl = _resolveBaseUrlForEnvironment();

  // Configure backend base URL once. In dev you can override via:
  // flutter run -d chrome --web-port 9095 --dart-define=API_BASE_URL=http://127.0.0.1:8000
  NeyvoApi.setBaseUrl(baseUrl);
  NeyvoApi.setDefaultTimeout(const Duration(seconds: 15));

    tz.initializeTimeZones();

    // Organization-only theme bootstrap. Avoid tenant endpoint at startup.
    const tenantConfig = TenantConfig.defaultGoodwin;

    runApp(
      ProviderScope(
        child: NeyvoPulseRoot(tenantConfig: tenantConfig),
      ),
    );
  }

  class NeyvoPulseRoot extends StatelessWidget {
    final TenantConfig tenantConfig;

    const NeyvoPulseRoot({super.key, required this.tenantConfig});

    @override
    Widget build(BuildContext context) {
      return TenantScope(
        config: tenantConfig,
        child: const NeyvoPulseApp(),
      );
    }
  }

  class NeyvoPulseApp extends StatelessWidget {
  const NeyvoPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = TenantScope.of(context);
    final tenant = scope?.config;
    return MaterialApp(
      title: 'Neyvo',
      debugShowCheckedModeBanner: false,
      theme: NeyvoThemeData.light(
        primaryColor: tenant?.primaryColor,
        secondaryColor: tenant?.secondaryColor ?? tenant?.accentColor,
        accentColor: tenant?.accentColor,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const NeyvoLoadingScreen();
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const InactivityDetector(
              timeout: const Duration(hours: 1),
              child: _PostAuthGate(),
            );
          }
          return const PulseAuthPage();
        },
      ),
    onGenerateRoute: (settings) {
      if (settings.name == PulseRouteNames.settings && settings.arguments is Map) {
        // Forward tab hint down to Settings page via PulseShell initialRouteName; SettingsPage reads arguments.
      }
      return PulseRouter.generateRoute(settings);
    },
    );
  }
}

  /// After login: load account then show PulseShell (Goodwin-only; no tenant switching).
  class _PostAuthGate extends ConsumerStatefulWidget {
    const _PostAuthGate();

    @override
    ConsumerState<_PostAuthGate> createState() => _PostAuthGateState();
  }

  /// Paths that PulseShell can open as the initial tab (must match PulseRouteNames).
  const Set<String> _pulseShellPaths = {
    PulseRouteNames.dashboard,
    PulseRouteNames.launch,
    PulseRouteNames.agents,
    PulseRouteNames.calls,
    PulseRouteNames.students,
    PulseRouteNames.campaigns,
    PulseRouteNames.team,
    PulseRouteNames.analytics,
    PulseRouteNames.executiveDashboard,
    PulseRouteNames.billing,
    PulseRouteNames.wallet,
    PulseRouteNames.settings,
    PulseRouteNames.phoneNumbers,
    PulseRouteNames.managedProfiles,
    PulseRouteNames.integrations,
    PulseRouteNames.voiceTier,
    PulseRouteNames.subscriptionPlan,
    PulseRouteNames.agency,
    PulseRouteNames.voiceStudio,
    PulseRouteNames.testCall,
    PulseRouteNames.health,
  };

  String? _initialRouteFromPath(String? path, {required bool hasPaymentParam}) {
    if (path == null || path.isEmpty) return hasPaymentParam ? PulseRouteNames.billing : null;
    if (hasPaymentParam) return PulseRouteNames.billing;
    if (path.startsWith('/pulse/') && _pulseShellPaths.contains(path)) return path;
    return null;
  }

  class _PostAuthGateState extends ConsumerState<_PostAuthGate> {
    bool _loaded = false;
    bool _onboardingCompleted = true;

    @override
    void initState() {
      super.initState();
      _loadAccount();
    }

    Future<void> _loadAccount() async {
      try {
        final res = await ref.read(accountInfoProvider.future);
        final ok = res['ok'] == true;
        final accountId = res['account_id'] as String?;
        final onboardingFromApi = res['onboarding_completed'];
        if (ok && accountId != null && accountId.isNotEmpty) {
          NeyvoPulseApi.setDefaultAccountId(accountId);
        } else if (_kFallbackAccountId.isNotEmpty) {
          NeyvoPulseApi.setDefaultAccountId(_kFallbackAccountId);
        }
        // Load user timezone from settings for date display
        try {
          final settingsRes = await NeyvoPulseApi.getSettings();
          final tzStr = (settingsRes['settings'] as Map?)?['timezone']?.toString();
          UserTimezoneService.setTimezone(tzStr);
          ref.read(userTimezoneProvider.notifier).syncFromService();
        } catch (_) {}
        // If API says not completed, check local persistence (so we don't loop when backend doesn't persist)
        bool completed = onboardingFromApi == true;
        if (!completed) {
          final prefs = await SharedPreferences.getInstance();
          completed = prefs.getBool(_kOnboardingCompletedKey) == true;
        }
        if (mounted) {
          setState(() {
            _loaded = true;
            _onboardingCompleted = completed;
          });
        }
      } on ApiException catch (e) {
        // 403 = account not authorized for Goodwin University (single-tenant app).
        if (e.statusCode == 403) {
          if (!mounted) return;
          NeyvoPulseApi.clearAccountInfoCache();
          NeyvoPulseApi.setDefaultAccountId(null);
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Not authorized'),
              content: const Text(
                'This account is not authorized for Goodwin University.\n\n'
                'Please sign in with a Goodwin University account or contact your administrator.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          await FirebaseAuth.instance.signOut();
          return;
        }
        if (_kFallbackAccountId.isNotEmpty) {
          NeyvoPulseApi.setDefaultAccountId(_kFallbackAccountId);
        }
        if (mounted) setState(() { _loaded = true; _onboardingCompleted = true; });
      } catch (_) {
        if (_kFallbackAccountId.isNotEmpty) {
          NeyvoPulseApi.setDefaultAccountId(_kFallbackAccountId);
        }
        if (mounted) setState(() { _loaded = true; _onboardingCompleted = true; });
      }
    }

    @override
    Widget build(BuildContext context) {
      if (!_loaded) {
        return const NeyvoLoadingScreen();
      }
      // Goodwin-only: no separate onboarding; go straight to shell.
      // On web refresh: use URL path so /pulse/operators (etc.) opens the correct tab instead of a blank/wrong view.
      final path = kIsWeb ? Uri.base.path : null;
      final hasPaymentParam = kIsWeb && (Uri.base.queryParameters['payment'] ?? '').trim().isNotEmpty;
      final initialRoute = _initialRouteFromPath(path, hasPaymentParam: hasPaymentParam);
      return PulseShell(initialRouteName: initialRoute);
    }
  }