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

  Future<void> _showForgotPasswordDialog() async {
    final emailC = TextEditingController(text: _email.text.trim());
    String? dialogError;
    bool sending = false;
    bool success = false;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: !sending,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reset password'),
              content: SingleChildScrollView(
                child: success
                    ? Text(
                        'Check your email for a link to reset your password.',
                        style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Enter your email and we\'ll send you a link to set a new password.',
                            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                          ),
                          const SizedBox(height: NeyvoSpacing.lg),
                          TextField(
                            controller: emailC,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'you@company.com',
                            ),
                            enabled: !sending,
                          ),
                          if (dialogError != null) ...[
                            const SizedBox(height: NeyvoSpacing.sm),
                            Text(
                              dialogError!,
                              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.error),
                            ),
                          ],
                        ],
                      ),
              ),
              actions: [
                if (!success)
                  TextButton(
                    onPressed: sending ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                if (success)
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  )
                else
                  FilledButton(
                    onPressed: sending
                        ? null
                        : () async {
                            final email = emailC.text.trim();
                            if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
                              setDialogState(() => dialogError = 'Please enter a valid email address');
                              return;
                            }
                            setDialogState(() {
                              dialogError = null;
                              sending = true;
                            });
                            try {
                              await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                              if (!ctx.mounted) return;
                              setDialogState(() {
                                sending = false;
                                success = true;
                              });
                            } on FirebaseAuthException catch (e) {
                              if (!ctx.mounted) return;
                              setDialogState(() {
                                sending = false;
                                dialogError = e.code == 'user-not-found'
                                    ? 'No account found for this email.'
                                    : (e.message ?? e.code);
                              });
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setDialogState(() {
                                sending = false;
                                dialogError = e.toString();
                              });
                            }
                          },
                    child: sending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send reset link'),
                  ),
              ],
            );
          },
        );
      },
    );
    emailC.dispose();
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
                            if (!_isSignUp) ...[
                              const SizedBox(height: NeyvoSpacing.sm),
                              TextButton(
                                onPressed: _loading ? null : _showForgotPasswordDialog,
                                child: Text(
                                  'Forgot password?',
                                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                                ),
                              ),
                            ],
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
