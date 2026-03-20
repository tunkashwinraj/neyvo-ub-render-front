// lib/screens/settings_page.dart
// Enhanced settings page with VAPI config, call scripts, and customization

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/neyvo_api.dart';
import '../neyvo_pulse_api.dart';
import '../core/providers/timezone_provider.dart';
import '../services/user_timezone_service.dart';
import '../utils/payment_result_dialog.dart';
import '../pulse_route_names.dart';
import 'pulse_shell.dart';
import '../theme/neyvo_theme.dart';

class PulseSettingsPage extends ConsumerStatefulWidget {
  const PulseSettingsPage({super.key});

  @override
  ConsumerState<PulseSettingsPage> createState() => _PulseSettingsPageState();
}

class _PulseSettingsPageState extends ConsumerState<PulseSettingsPage> {
  final _schoolName = TextEditingController();
  final _defaultLateFee = TextEditingController();
  final _currency = TextEditingController();
  String _timezoneValue = 'America/New_York';
  final _vapiPhoneNumberId = TextEditingController();
  final _primaryPhoneController = TextEditingController();
  bool _verifyingPhone = false;
  bool _phoneVerified = false;
  final _vapiAssistantId = TextEditingController();
  final _callScript = TextEditingController();
  
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _showAdvanced = false;
  String? _myRole;
  String? _voiceTierDisplay;
  String? _subscriptionTier;
  String? _accountId;
  bool _inboundEnabled = true;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _settingsAgents = [];
  String? _defaultAgentId;
  bool _isEducationOrg = false;
  Map<String, dynamic>? _schoolIntegration;
  bool _schoolTokenVisible = false;
  final _memberUserIdController = TextEditingController();
  final _linkAccountIdController = TextEditingController();
  String _newMemberRole = 'staff';
  bool _linkingAccount = false;

  @override
  void initState() {
    super.initState();
    _load();
    _maybeShowPaymentResult();
  }

  void _maybeShowPaymentResult() {
    try {
      final payment = Uri.base.queryParameters['payment'];
      if (payment == null || payment.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showPaymentResultDialogIfNeeded(context, payment);
        if (!mounted) return;
        PulseShellController.navigatePulse(context, PulseRouteNames.billing);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _schoolName.dispose();
    _defaultLateFee.dispose();
    _currency.dispose();
    _vapiPhoneNumberId.dispose();
    _vapiAssistantId.dispose();
    _callScript.dispose();
    _primaryPhoneController.dispose();
    _memberUserIdController.dispose();
    _linkAccountIdController.dispose();
    super.dispose();
  }

  static const List<String> _timezoneOptions = [
    'America/New_York', 'America/Chicago', 'America/Denver', 'America/Los_Angeles',
    'America/Phoenix', 'America/Anchorage', 'Pacific/Honolulu', 'UTC',
    'Europe/London', 'Europe/Paris', 'Europe/Berlin', 'Asia/Kolkata',
    'Asia/Tokyo', 'Asia/Shanghai', 'Australia/Sydney',
  ];

  String _userPhone(User? user) {
    if (user == null) return '—';
    if ((user.phoneNumber ?? '').isNotEmpty) return user.phoneNumber!;
    for (final p in user.providerData) {
      if ((p.phoneNumber ?? '').isNotEmpty) return p.phoneNumber!;
    }
    return '—';
  }

  Future<void> _seedDemo() async {
    setState(() => _error = null);
    try {
      final res = await NeyvoPulseApi.seedFull();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Demo data loaded')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await NeyvoPulseApi.getSettings();
      final s = res['settings'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        _schoolName.text = s['school_name']?.toString() ?? '';
        _defaultLateFee.text = s['default_late_fee']?.toString() ?? '';
        _currency.text = s['currency']?.toString() ?? 'USD';
        final tz = (s['timezone']?.toString() ?? '').trim();
        _timezoneValue = tz.isNotEmpty ? tz : 'America/New_York';
        UserTimezoneService.setTimezone(_timezoneValue);
        _vapiPhoneNumberId.text = s['vapi_phone_number_id']?.toString() ?? '';
        _primaryPhoneController.text = s['primary_phone_e164']?.toString() ?? s['primary_phone']?.toString() ?? '';
        _vapiAssistantId.text = s['vapi_assistant_id']?.toString() ?? '';
        _callScript.text = s['call_script']?.toString() ?? '';
        _inboundEnabled = s['inbound_enabled'] != false;
        _defaultAgentId = (s['default_agent_id']?.toString() ?? '').trim().isEmpty ? null : s['default_agent_id']?.toString().trim();
        _accountId = (s['account_id']?.toString() ?? '').trim().isEmpty ? null : s['account_id']?.toString().trim();
        if (_accountId == null || _accountId!.isEmpty) {
          // Fallback so user sees something; backend may use different Firestore collection
          _accountId = NeyvoPulseApi.defaultAccountId;
        }
      }
      final roleRes = await NeyvoPulseApi.getMyRole();
      final membersRes = await NeyvoPulseApi.listMembers();
      try {
        final tierRes = await NeyvoPulseApi.getBillingTier();
        if (mounted) _voiceTierDisplay = tierRes['tier_display']?.toString();
      } catch (_) {}
      bool isEdu = false;
      try {
        final agentsRes = await NeyvoPulseApi.listAgents();
        final agents = agentsRes['agents'] as List? ?? [];
        _settingsAgents = agents.cast<Map<String, dynamic>>();
        isEdu = _settingsAgents.any((a) => (a['industry']?.toString().toLowerCase() ?? '') == 'education');
        if (_defaultAgentId != null && !_settingsAgents.any((a) => (a['id']?.toString() ?? '') == _defaultAgentId)) {
          _defaultAgentId = null;
        }
      } catch (_) {}
      Map<String, dynamic>? schoolInt;
      if (isEdu) {
        try {
          schoolInt = await NeyvoPulseApi.getSchoolIntegration();
        } catch (_) {}
      }
      String? subTier;
      try {
        final subRes = await NeyvoPulseApi.getSubscription();
        subTier = (subRes['tier'] as String?)?.toLowerCase();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _myRole = roleRes['role']?.toString();
          _members = List<Map<String, dynamic>>.from(membersRes['members'] as List? ?? []);
          _subscriptionTier = subTier;
          _isEducationOrg = isEdu;
          _schoolIntegration = schoolInt;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await NeyvoPulseApi.updateSettings(
        schoolName: null,
        defaultLateFee: _defaultLateFee.text.trim().isEmpty ? null : _defaultLateFee.text.trim(),
        currency: _currency.text.trim().isEmpty ? null : _currency.text.trim(),
        timezone: _timezoneValue,
        inboundEnabled: _inboundEnabled,
        primaryPhoneE164: null,
        vapiAssistantId: null,
        vapiPhoneNumberId: null,
        defaultAgentId: _defaultAgentId,
        callScript: _callScript.text.trim().isEmpty ? null : _callScript.text.trim(),
      );
      UserTimezoneService.setTimezone(_timezoneValue);
      ref.read(userTimezoneProvider.notifier).syncFromService();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
        setState(() => _saving = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _linkToAccount() async {
    final accountId = _linkAccountIdController.text.trim();
    if (accountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an account ID')));
      return;
    }
    setState(() => _linkingAccount = true);
    try {
      await NeyvoPulseApi.linkUserToAccount(accountId);
      if (!mounted) return;
      NeyvoPulseApi.setDefaultAccountId(accountId);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Linked to account $accountId')));
      _linkAccountIdController.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _linkingAccount = false);
    }
  }

  void _showForgotPasswordDialog() {
    final email = (FirebaseAuth.instance.currentUser?.email ?? '').trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address on file for this account.')),
      );
      return;
    }
    bool sending = false;
    bool success = false;
    String? dialogError;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
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
                            'We\'ll send a password reset link to:',
                            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                          ),
                          const SizedBox(height: NeyvoSpacing.sm),
                          Text(
                            email,
                            style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary),
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
                        : const Text('Send link'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: NeyvoTheme.bgPrimary, body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        backgroundColor: NeyvoTheme.bgPrimary,
        appBar: AppBar(title: const Text('Settings'), backgroundColor: NeyvoTheme.bgSurface),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Something went wrong', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                const SizedBox(height: 8),
                Text(_error!, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: NeyvoSpacing.lg),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      children: [
        Text('University of Bridgeport', style: NeyvoType.headlineLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.xl),
        Text('Account', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.sm),
        const SizedBox(height: NeyvoSpacing.md),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: ListTile(
              leading: const Icon(Icons.badge_outlined, color: NeyvoTheme.textSecondary),
              title: Text('Account ID', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
              subtitle: Text(
                (_accountId != null && _accountId!.length <= 20) ? _accountId! : '—',
                style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
              ),
              trailing: (_accountId != null && _accountId!.length <= 20)
                  ? IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copy',
                      onPressed: () {
                        if (_accountId != null) {
                          Clipboard.setData(ClipboardData(text: _accountId!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account ID copied')),
                          );
                        }
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: NeyvoSpacing.md),
        Card(
          color: NeyvoTheme.bgCard,
          child: ListTile(
            leading: const Icon(Icons.lock_reset, color: NeyvoTheme.textSecondary),
            title: Text('Forgot password', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
            subtitle: Text(
              'Send a password reset link to your email',
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showForgotPasswordDialog,
          ),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        Text('Organization', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.md),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _timezoneValue,
                  decoration: const InputDecoration(
                    labelText: 'Timezone',
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  items: [
                    for (final z in _timezoneOptions) DropdownMenuItem(value: z, child: Text(z)),
                    if (!_timezoneOptions.contains(_timezoneValue) && _timezoneValue.isNotEmpty)
                      DropdownMenuItem(value: _timezoneValue, child: Text(_timezoneValue)),
                  ],
                  onChanged: (v) => setState(() => _timezoneValue = v ?? 'America/New_York'),
                ),
                const SizedBox(height: NeyvoSpacing.md),
                DropdownButtonFormField<String>(
                  value: _defaultAgentId,
                  decoration: const InputDecoration(
                    labelText: 'Default agent for outbound calls',
                    prefixIcon: Icon(Icons.record_voice_over_outlined),
                    hintText: 'Used when placing a call from a contact',
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('— None (choose per call)')),
                    ..._settingsAgents.map((a) {
                      final id = (a['id'] ?? '').toString();
                      final name = (a['name'] ?? 'Unnamed').toString();
                      return DropdownMenuItem<String>(value: id, child: Text(name));
                    }),
                  ],
                  onChanged: (v) => setState(() => _defaultAgentId = v),
                ),
                const SizedBox(height: NeyvoSpacing.md),
                SwitchListTile(
                  value: _inboundEnabled,
                  onChanged: (bool value) => setState(() => _inboundEnabled = value),
                  title: const Text('Allow inbound calls'),
                  subtitle: const Text(
                    'When off, your phone numbers are outbound-only; inbound callers hear a message and the call ends.',
                  ),
                  secondary: const Icon(Icons.call_received_outlined),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text(_saving ? 'Saving...' : 'Save Settings'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: NeyvoSpacing.md),
          ),
        ),
        const SizedBox(height: NeyvoSpacing.lg),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('System Information', style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textSecondary)),
                const SizedBox(height: NeyvoSpacing.xs),
                Text('Version: 1.0.0', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
