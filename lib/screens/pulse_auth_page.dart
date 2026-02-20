// lib/neyvo_pulse/screens/pulse_auth_page.dart
// Neyvo Pulse – Auth (new layout, same colors/fonts).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/spearia_theme.dart';

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

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      if (_isSignUp) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      if (!mounted) return;
      // Auth state stream in main will rebuild and show PulseShell
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? e.code;
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: SpeariaAura.heroGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: SpeariaSpacing.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Neyvo Pulse',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Student Financial • Schools & Universities',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: SpeariaSpacing.section),
                  Container(
                    padding: const EdgeInsets.all(SpeariaSpacing.xl),
                    decoration: SpeariaFX.card(radius: SpeariaRadius.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isSignUp ? 'Create account' : 'Sign in',
                          style: SpeariaType.headlineMedium,
                        ),
                        const SizedBox(height: SpeariaSpacing.lg),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'you@school.edu',
                          ),
                        ),
                        const SizedBox(height: SpeariaSpacing.md),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: SpeariaSpacing.md),
                          Text(
                            _error!,
                            style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.error),
                          ),
                        ],
                        const SizedBox(height: SpeariaSpacing.xl),
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
                        const SizedBox(height: SpeariaSpacing.md),
                        TextButton(
                          onPressed: () => setState(() {
                            _isSignUp = !_isSignUp;
                            _error = null;
                          }),
                          child: Text(_isSignUp ? 'Already have an account? Sign in' : 'Need an account? Sign up'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
