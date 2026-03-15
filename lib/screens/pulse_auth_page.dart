// lib/neyvo_pulse/screens/pulse_auth_page.dart
// Neyvo Pulse – Auth (new layout, same colors/fonts).

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../api/spearia_api.dart';
import '../theme/neyvo_theme.dart';
import '../neyvo_pulse_api.dart';
import '../tenant/tenant_scope.dart';
import '../tenant/tenant_brand.dart';
import '../ui/components/glass/neyvo_glass_panel.dart';
import '../widgets/recaptcha_v2_checkbox.dart';

class PulseAuthPage extends StatefulWidget {
  const PulseAuthPage({super.key});

  @override
  State<PulseAuthPage> createState() => _PulseAuthPageState();
}

class _PulseAuthPageState extends State<PulseAuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _verifying = false;
  bool _recaptchaVerified = false; // reCAPTCHA v2 "I'm not a robot" checked (web only)
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
      _verifying = false;
    });
    if (!_validateInputs()) {
      setState(() => _loading = false);
      return;
    }
    final email = _email.text.trim();
    final password = _password.text;

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Ensure the very next API call sends this user so backend tenant check uses correct account.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        SpeariaApi.setUserId(user.uid);
      }
      // Immediately verify tenant/org membership so that cross-tenant
      // logins are rejected at the auth screen instead of inside the
      // Pulse shell. No dashboard data is ever loaded until this succeeds.
      try {
        await NeyvoPulseApi.getAccountInfo();
      } on ApiException catch (e) {
        // Any 403 on account = wrong portal (same as main.dart gate).
        if (e.statusCode == 403) {
          NeyvoPulseApi.clearAccountInfoCache();
          await FirebaseAuth.instance.signOut();
          NeyvoPulseApi.setDefaultAccountId(null);
          if (!mounted) return;
          setState(() {
            _error = 'These credentials are not valid for this portal. Please sign in at the correct school site (ub.neyvo.ai or goodwin.neyvo.ai).';
            _loading = false;
          });
          return;
        }
        // For other API errors, fall through and let the post-auth gate handle them.
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? e.code;
        _loading = false;
      });
    } catch (e, _) {
      final msg = e.toString().toLowerCase();
      final isAppCheckOrThrottle = msg.contains('appcheck') || msg.contains('app check') ||
          msg.contains('throttl') || msg.contains('403');
      setState(() {
        _error = isAppCheckOrThrottle
            ? 'Sign-in is temporarily unavailable. Please use the correct portal (ub.neyvo.ai or goodwin.neyvo.ai) or try again later.'
            : (e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString());
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = TenantScope.of(context)?.config;
    final primary = TenantBrand.primary(context);
    final tenantId = (tenant?.tenantId ?? '').toLowerCase();
    final isGoodwin = tenantId == 'goodwin';
    final isUb = tenantId == 'ub' || tenant == null;
    return Scaffold(
      backgroundColor: NeyvoColors.bgLight,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NeyvoColors.white,
              Color(0xFFFAF8FC),
              Color(0xFFF5F0FA),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: NeyvoSpacing.xxl),
                    if (isGoodwin)
                      Image.asset(
                        'assets/goodwin_logo/goodwin_horiz_rgb.png',
                        fit: BoxFit.contain,
                        height: 58,
                      )
                    else if (isUb)
                      SvgPicture.asset(
                        'assets/ub_logo/ub_logo_horizontal_purple.svg',
                        fit: BoxFit.contain,
                        height: 58,
                        colorFilter: const ColorFilter.mode(
                          NeyvoColors.ubPurple,
                          BlendMode.srcIn,
                        ),
                      )
                    else if (tenant?.logoHorizontalColorUrl != null &&
                        tenant!.logoHorizontalColorUrl!.isNotEmpty)
                      Builder(
                        builder: (context) {
                          final url = tenant.logoHorizontalColorUrl!;
                          final lower = url.toLowerCase();
                          if (lower.endsWith('.png') ||
                              lower.endsWith('.jpg') ||
                              lower.endsWith('.jpeg')) {
                            return Image.network(
                              url,
                              fit: BoxFit.contain,
                              height: 58,
                              errorBuilder: (context, _, __) {
                                final t = TenantScope.of(context)?.config;
                                final isUb = t == null || t.tenantId == 'ub';
                                if (isUb) {
                                  return SvgPicture.asset(
                                    'assets/ub_logo/ub_logo_horizontal_purple.svg',
                                    fit: BoxFit.contain,
                                    height: 58,
                                    colorFilter: const ColorFilter.mode(
                                      NeyvoColors.ubPurple,
                                      BlendMode.srcIn,
                                    ),
                                  );
                                }
                                return Text(
                                  (t?.schoolName ?? 'Neyvo').trim().isEmpty ? 'Neyvo' : (t?.schoolName ?? 'Neyvo'),
                                  style: NeyvoType.headlineMediumLight.copyWith(color: primary),
                                  textAlign: TextAlign.center,
                                );
                              },
                            );
                          } else {
                            return SvgPicture.network(
                              url,
                              fit: BoxFit.contain,
                              height: 58,
                              placeholderBuilder: (_) => const SizedBox(height: 58),
                            );
                          }
                        },
                      )
                    else
                      SvgPicture.asset(
                        'assets/ub_logo/ub_logo_horizontal_purple.svg',
                        fit: BoxFit.contain,
                        height: 58,
                        // Force UB purple so the logo is not black
                        colorFilter: const ColorFilter.mode(
                          NeyvoColors.ubPurple,
                          BlendMode.srcIn,
                        ),
                      ),
                    const SizedBox(height: NeyvoSpacing.xl),
                    Text(
                      'Neyvo',
                      style: NeyvoType.displayLargeLight,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NeyvoSpacing.sm),
                    Text(
                      'Sign in to access your voice intelligence platform.',
                      style: NeyvoType.bodySmallLight,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NeyvoSpacing.section),
                    NeyvoCard(
                      padding: const EdgeInsets.all(NeyvoSpacing.xl),
                      glowing: false,
                      child: Form(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign in',
                              style: NeyvoType.headlineMedium.copyWith(
                                color: NeyvoTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: NeyvoSpacing.lg),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'you@company.com',
                              ),
                            ),
                            const SizedBox(height: NeyvoSpacing.md),
                            TextField(
                              controller: _password,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: NeyvoSpacing.md),
                              Container(
                                padding: const EdgeInsets.all(NeyvoSpacing.sm),
                                decoration: BoxDecoration(
                                  color: NeyvoColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(NeyvoRadius.sm),
                                ),
                                child: Text(
                                  _error!,
                                  style: NeyvoType.bodySmall.copyWith(color: NeyvoColors.error),
                                ),
                              ),
                            ],
                            if (kIsWeb) ...[
                              const SizedBox(height: NeyvoSpacing.lg),
                              buildRecaptchaV2Checkbox(
                                siteKey: '6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI',
                                onVerified: (token) {
                                  if (mounted) setState(() => _recaptchaVerified = true);
                                },
                              ),
                              const SizedBox(height: NeyvoSpacing.sm),
                            ],
                            const SizedBox(height: NeyvoSpacing.xl),
                            FilledButton(
                              onPressed: (_loading || _verifying || (kIsWeb && !_recaptchaVerified)) ? null : _submit,
                              style: FilledButton.styleFrom(backgroundColor: primary),
                              child: _loading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Sign in'),
                            ),
                            if (kIsWeb) ...[
                              const SizedBox(height: NeyvoSpacing.xs),
                              Center(
                                child: Text(
                                  'Protected by reCAPTCHA. Privacy & Terms apply.',
                                  style: NeyvoType.bodySmall.copyWith(
                                    color: NeyvoTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            const SizedBox(height: NeyvoSpacing.sm),
                            TextButton(
                              onPressed: (_loading || _verifying) ? null : _showForgotPasswordDialog,
                              child: Text(
                                'Forgot password?',
                                style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: NeyvoSpacing.section),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
