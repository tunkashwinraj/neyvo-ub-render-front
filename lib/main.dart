  import 'dart:async';

  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'package:flutter/foundation.dart' show kIsWeb;
  import 'package:flutter/material.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:timezone/data/latest.dart' as tz;

import 'api/spearia_api.dart';
import 'services/user_timezone_service.dart';
import 'firebase_options.dart';
import 'neyvo_pulse_api.dart';
import 'pulse_route_names.dart';
import 'pulse_routes.dart';
import 'screens/pulse_auth_page.dart';
import 'ui/screens/ub/ub_onboarding_page.dart';
import 'screens/pulse_shell.dart';
import 'tenant/tenant_api.dart';
import 'tenant/tenant_config.dart';
import 'tenant/tenant_scope.dart';
import 'theme/neyvo_theme.dart';
import 'widgets/inactivity_detector.dart';
import 'widgets/neyvo_loading_screen.dart';

  const String _kOnboardingCompletedKey = 'neyvo_pulse_onboarding_completed';
  const String _kDefaultBaseUrl = String.fromEnvironment(
    'SPEARIA_BASE_URL',
    defaultValue: 'https://ub-neyvo-back-znhe.onrender.com',
  );

String _resolveTenantId() {
  if (!kIsWeb) {
    // For mobile/desktop builds we can keep using the default tenant for now.
    return '';
  }
  final host = Uri.base.host.toLowerCase();
  if (host.startsWith('goodwin.')) return 'goodwin';
  if (host.startsWith('ub.')) return 'ub';
  return '';
}

String _resolveBaseUrlForTenant(String tenantId) {
  // For now, always use the existing Render backend URL. When custom
  // API subdomains (api.ub.neyvo.ai, api.goodwin.neyvo.ai) are fully
  // configured and have DNS + TLS, this helper can be updated to
  // route per-tenant to those hosts instead.
  return _kDefaultBaseUrl;
}
/// Fallback account_id when getAccountInfo fails or returns empty (single-tenant deployments).
/// 1) Build-time: flutter build web --dart-define=NEYVO_ACCOUNT_ID=870065
/// 2) Runtime: when backend is ub-neyvo-back-znhe.onrender.com, use 870065 per FIRESTORE_QUICK_REFERENCE
String get _kFallbackAccountId {
    const fromEnv = String.fromEnvironment('NEYVO_ACCOUNT_ID', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
  if (SpeariaApi.baseUrl.contains('ub-neyvo-back-znhe.onrender.com')) return '870065';
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
    SpeariaApi.setUserId(user?.uid);
    if (user == null) NeyvoPulseApi.setDefaultAccountId(null);
  });
  SpeariaApi.setUserId(FirebaseAuth.instance.currentUser?.uid);
  if (FirebaseAuth.instance.currentUser == null) NeyvoPulseApi.setDefaultAccountId(null);

  // Resolve tenant + backend base URL.
  final tenantId = _resolveTenantId();
  final baseUrl = _resolveBaseUrlForTenant(tenantId.isNotEmpty ? tenantId : '');

  // Configure backend base URL once. In dev you can override via:
  // flutter run -d chrome --web-port 9095 --dart-define=SPEARIA_BASE_URL=http://127.0.0.1:8000
  SpeariaApi.setBaseUrl(baseUrl);
  if (tenantId.isNotEmpty) {
    SpeariaApi.setTenantId(tenantId);
  }
    SpeariaApi.setDefaultTimeout(const Duration(seconds: 30));

    tz.initializeTimeZones();

    final tenantConfig = await TenantApi.fetchConfig();

    runApp(NeyvoPulseRoot(tenantConfig: tenantConfig));
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
              timeout: Duration(minutes: 3),
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

  /// After login: load account; if UB intro not completed show UbOnboardingPage else PulseShell.
  class _PostAuthGate extends StatefulWidget {
    const _PostAuthGate();

    @override
    State<_PostAuthGate> createState() => _PostAuthGateState();
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
    PulseRouteNames.auditLog,
    PulseRouteNames.analytics,
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

  class _PostAuthGateState extends State<_PostAuthGate> {
    bool _loaded = false;
    bool _onboardingCompleted = true;

    @override
    void initState() {
      super.initState();
      _loadAccount();
    }

    Future<void> _loadAccount() async {
      try {
        final res = await NeyvoPulseApi.getAccountInfo();
        final ok = res['ok'] == true;
        final accountId = res['account_id'] as String?;
        final onboardingFromApi = res['onboarding_completed'];
        // Only use the UB demo fallback account for the UB tenant. For
        // Goodwin (and future tenants) we require a real account mapping
        // from the backend so each school has its own business data.
        final tenant = TenantScope.of(context)?.config;
        final isUbTenant = tenant == null || tenant.tenantId == 'ub';
        if (ok && accountId != null && accountId.isNotEmpty) {
          NeyvoPulseApi.setDefaultAccountId(accountId);
        } else if (isUbTenant && _kFallbackAccountId.isNotEmpty) {
          NeyvoPulseApi.setDefaultAccountId(_kFallbackAccountId);
        }
        // Load user timezone from settings for date display
        try {
          final settingsRes = await NeyvoPulseApi.getSettings();
          final tzStr = (settingsRes['settings'] as Map?)?['timezone']?.toString();
          UserTimezoneService.setTimezone(tzStr);
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
        // Handle tenant mismatch (user logging into the wrong school domain).
        final payload = e.payload;
        final errorCode = payload is Map ? '${payload['error'] ?? ''}'.trim() : '';
        final isTenantMismatch = e.statusCode == 403 && errorCode == 'tenant_mismatch';
        if (isTenantMismatch) {
          if (!mounted) return;
          final tenant = TenantScope.of(context)?.config;
          final tenantId = tenant?.tenantId ?? 'ub';
          final otherDomain = tenantId == 'goodwin' ? 'ub.neyvo.ai' : 'goodwin.neyvo.ai';
          final schoolName = tenantId == 'goodwin'
              ? 'University of Bridgeport'
              : 'Goodwin University';
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Use the correct portal'),
              content: Text(
                'This account belongs to $schoolName.\n\n'
                'Please sign in at $otherDomain instead.',
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
          NeyvoPulseApi.setDefaultAccountId(null);
          // Do not mark this gate as "loaded"; authStateChanges will
          // rebuild the app back to PulseAuthPage after sign-out so
          // the user never reaches PulseShell on a mismatched tenant.
          return;
        }
        // For all other API errors, fall back to the legacy behavior.
        final tenant = TenantScope.of(context)?.config;
        final isUbTenant = tenant == null || tenant.tenantId == 'ub';
        if (isUbTenant && _kFallbackAccountId.isNotEmpty) {
          NeyvoPulseApi.setDefaultAccountId(_kFallbackAccountId);
        }
        if (mounted) setState(() { _loaded = true; _onboardingCompleted = true; });
      } catch (_) {
        final tenant = TenantScope.of(context)?.config;
        final isUbTenant = tenant == null || tenant.tenantId == 'ub';
        if (isUbTenant && _kFallbackAccountId.isNotEmpty) {
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
      final tenant = TenantScope.of(context)?.config;
      if (!_onboardingCompleted && (tenant?.tenantId == 'ub' || tenant == null)) {
        return const UbOnboardingPage();
      }
      // On web refresh: use URL path so /pulse/operators (etc.) opens the correct tab instead of a blank/wrong view.
      final path = kIsWeb ? Uri.base.path : null;
      final hasPaymentParam = kIsWeb && (Uri.base.queryParameters['payment'] ?? '').trim().isNotEmpty;
      final initialRoute = _initialRouteFromPath(path, hasPaymentParam: hasPaymentParam);
      return PulseShell(initialRouteName: initialRoute);
    }
  }