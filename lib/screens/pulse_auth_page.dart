// lib/neyvo_pulse/screens/pulse_auth_page.dart
// Neyvo Pulse – Auth (new layout, same colors/fonts).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/neyvo_theme.dart';
import '../neyvo_pulse_api.dart';
import '../ui/components/ai_orb/neyvo_ai_orb.dart';
import '../ui/components/backgrounds/neyvo_neural_background.dart';
import '../ui/components/glass/neyvo_glass_panel.dart';

class PulseAuthPage extends StatefulWidget {
  const PulseAuthPage({super.key});

  @override
  State<PulseAuthPage> createState() => _PulseAuthPageState();
}

class _PulseAuthPageState extends State<PulseAuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return false;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address');
      return false;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return false;
    }
    if (_isSignUp && password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    if (!_validateInputs()) {
      setState(() => _loading = false);
      return;
    }
    final email = _email.text.trim();
    final password = _password.text;
    try {
      if (_isSignUp) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      if (!mounted) return;
      // Auth state stream in main will rebuild and show PulseShell
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.code == 'email-already-in-use' ? 'Email already in use' : (e.message ?? e.code);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      body: Stack(
        children: [
          const Positioned.fill(child: NeyvoNeuralBackground()),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.xxl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: NeyvoSpacing.lg),
                      const NeyvoAIOrb(
                        state: NeyvoAIOrbState.idle,
                        size: 140,
                      ),
                      const SizedBox(height: NeyvoSpacing.lg),
                      Text(
                        'Neyvo Voice OS',
                        style: NeyvoType.displayLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: NeyvoSpacing.sm),
                      Text(
                        'Enter your autonomous voice intelligence environment.',
                        style: NeyvoType.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: NeyvoSpacing.section),
                      NeyvoGlassPanel(
                        glowing: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isSignUp ? 'Create account' : 'Sign in',
                              style: NeyvoType.headlineMedium.copyWith(
                                color: NeyvoTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: NeyvoSpacing.lg),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'you@company.com',
                              ),
                            ),
                            const SizedBox(height: NeyvoSpacing.md),
                            TextField(
                              controller: _password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: NeyvoSpacing.md),
                              Text(
                                _error!,
                                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.error),
                              ),
                            ],
                            const SizedBox(height: NeyvoSpacing.xl),
                            FilledButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(_isSignUp ? 'Create account' : 'Sign in'),
                            ),
                            const SizedBox(height: NeyvoSpacing.md),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => setState(() {
                                        _isSignUp = !_isSignUp;
                                        _error = null;
                                      }),
                              child: Text(
                                _isSignUp
                                    ? 'Already have an account? Sign in'
                                    : 'Need an account? Sign up',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: NeyvoSpacing.section),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
