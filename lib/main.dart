  import 'dart:async';

  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'package:flutter/material.dart';

  import 'api/spearia_api.dart';
  import 'firebase_options.dart';
  import 'neyvo_pulse_api.dart';
  import 'pulse_routes.dart';
  import 'screens/pulse_auth_page.dart';
  import 'screens/pulse_shell.dart';
  import 'theme/spearia_theme.dart';

  Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Phase D RBAC: send current user id to backend for role checks; clear account when logging out so new user gets their own
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      SpeariaApi.setUserId(user?.uid);
      if (user == null) NeyvoPulseApi.setDefaultAccountId(null);
    });
    SpeariaApi.setUserId(FirebaseAuth.instance.currentUser?.uid);
    if (FirebaseAuth.instance.currentUser == null) NeyvoPulseApi.setDefaultAccountId(null);

    SpeariaApi.setBaseUrl('https://neyvo-pulse.onrender.com');
    SpeariaApi.setDefaultTimeout(const Duration(seconds: 30));

    runApp(const NeyvoPulseApp());
  }

  class NeyvoPulseApp extends StatelessWidget {
    const NeyvoPulseApp({super.key});

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        title: 'Neyvo Pulse',
        debugShowCheckedModeBanner: false,
        theme: SpeariaTheme.light(),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData && snapshot.data != null) {
              return const PulseShell();
            }
            return const PulseAuthPage();
          },
        ),
        onGenerateRoute: PulseRouter.generateRoute,
      );
    }
  }