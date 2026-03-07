  import 'dart:async';

  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'package:flutter/foundation.dart' show kIsWeb;
  import 'package:flutter/material.dart';
  import 'package:shared_preferences/shared_preferences.dart';

  import 'api/spearia_api.dart';
  import 'firebase_options.dart';
  import 'neyvo_pulse_api.dart';
  import 'pulse_route_names.dart';
  import 'pulse_routes.dart';
  import 'screens/pulse_auth_page.dart';
  import 'ui/screens/ub/ub_onboarding_page.dart';
  import 'screens/pulse_shell.dart';
  import 'theme/neyvo_theme.dart';
  import 'widgets/inactivity_detector.dart';

  const String _kOnboardingCompletedKey = 'neyvo_pulse_onboarding_completed';

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

    SpeariaApi.setBaseUrl('https://ub-neyvo-back.onrender.com');
    SpeariaApi.setDefaultTimeout(const Duration(seconds: 30));

    runApp(const NeyvoPulseApp());
  }

  class NeyvoPulseApp extends StatelessWidget {
    const NeyvoPulseApp({super.key});

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        title: 'Neyvo',
        debugShowCheckedModeBanner: false,
        theme: NeyvoThemeData.light(),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData && snapshot.data != null) {
              return const InactivityDetector(
                timeout: Duration(minutes: 15),
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
        if (ok && accountId != null && accountId.isNotEmpty) {
          NeyvoPulseApi.setDefaultAccountId(accountId);
        }
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
      } catch (_) {
        if (mounted) setState(() { _loaded = true; _onboardingCompleted = true; });
      }
    }

    @override
    Widget build(BuildContext context) {
      if (!_loaded) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (!_onboardingCompleted) {
        return const UbOnboardingPage();
      }
      // After Stripe redirect, land on wallet or settings when URL path matches (web).
      final path = kIsWeb ? Uri.base.path : null;
      final initialRoute = (path == PulseRouteNames.wallet || path == PulseRouteNames.settings)
          ? path
          : null;
      return PulseShell(initialRouteName: initialRoute);
    }
  }