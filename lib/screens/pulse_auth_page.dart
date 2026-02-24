// lib/neyvo_pulse/screens/pulse_auth_page.dart
// Neyvo Pulse – Auth (new layout, same colors/fonts).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/neyvo_theme.dart';
import '../neyvo_pulse_api.dart';

class PulseAuthPage extends StatefulWidget {
  const PulseAuthPage({super.key});

  @override
  State<PulseAuthPage> createState() => _PulseAuthPageState();
}

class _PulseAuthPageState extends State<PulseAuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _orgName = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _orgName.dispose();
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
    if (_isSignUp && _orgName.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your organization name');
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
    final orgName = _orgName.text.trim();
    try {
      if (_isSignUp) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        // After creating the user, store the organization/account name via backend.
        try {
          if (orgName.isNotEmpty) {
            await NeyvoPulseApi.updateAccountInfo({'account_name': orgName});
          }
        } catch (_) {
          // Non-fatal; onboarding/settings will still allow editing later.
        }
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [NeyvoTheme.teal, NeyvoTheme.tealLight],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Neyvo',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: NeyvoSpacing.section),
                  const SizedBox(height: NeyvoSpacing.section),
                  Container(
                    padding: const EdgeInsets.all(NeyvoSpacing.xl),
                    decoration: BoxDecoration(
                      color: NeyvoTheme.bgCard,
                      borderRadius: BorderRadius.circular(NeyvoRadius.lg),
                      border: Border.all(color: NeyvoTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isSignUp ? 'Create account' : 'Sign in',
                          style: NeyvoType.headlineMedium.copyWith(color: NeyvoTheme.textPrimary),
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
                        if (_isSignUp) ...[
                          TextField(
                            controller: _orgName,
                            decoration: const InputDecoration(
                              labelText: 'Organization name',
                              hintText: 'e.g. Riverside Academy',
                            ),
                          ),
                          const SizedBox(height: NeyvoSpacing.md),
                        ],
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
