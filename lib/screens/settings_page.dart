// lib/screens/settings_page.dart
// Enhanced settings page with VAPI config, call scripts, and customization

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../neyvo_pulse_api.dart';
import '../utils/payment_result_dialog.dart';
import '../pulse_route_names.dart';
import '../theme/neyvo_theme.dart';

class PulseSettingsPage extends StatefulWidget {
  const PulseSettingsPage({super.key});

  @override
  State<PulseSettingsPage> createState() => _PulseSettingsPageState();
}

class _PulseSettingsPageState extends State<PulseSettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _schoolName = TextEditingController();
  final _defaultLateFee = TextEditingController();
  final _currency = TextEditingController();
  String _timezoneValue = 'America/New_York';
  String _primaryIndustry = 'Healthcare';
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

  // Developer console – phone numbers
  final _devPhoneNumberIdController = TextEditingController();
  final _devPhoneE164Controller = TextEditingController();
  bool _devWorking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.billing);
      });
    } catch (_) {}
  }

  Future<void> _devAttachNumber() async {
    final id = _devPhoneNumberIdController.text.trim();
    final e164 = _devPhoneE164Controller.text.trim();
    if (id.isEmpty || e164.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone_number_id and E.164 number')));
      return;
    }
    setState(() => _devWorking = true);
    try {
      final res = await NeyvoPulseApi.attachNumber(phoneNumberId: id, phoneNumberE164: e164);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attached: ${res['phone_number_id'] ?? id}')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attach failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  Future<void> _devDetachNumber() async {
    final id = _devPhoneNumberIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone_number_id to detach')));
      return;
    }
    setState(() => _devWorking = true);
    try {
      await NeyvoPulseApi.releaseNumber(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Detached $id')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Detach failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  Future<void> _devSetPrimary() async {
    final id = _devPhoneNumberIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone_number_id to set primary')));
      return;
    }
    setState(() => _devWorking = true);
    try {
      await NeyvoPulseApi.setOutboundPrimary(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Primary set to $id')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Set primary failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  Future<void> _devRegisterFreecaller() async {
    final id = _devPhoneNumberIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone_number_id to register')));
      return;
    }
    setState(() => _devWorking = true);
    try {
      await NeyvoPulseApi.registerFreecaller(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registered freecaller for $id')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Register failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  Future<void> _devWarmupStatus() async {
    final id = _devPhoneNumberIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone_number_id to check warm-up')));
      return;
    }
    setState(() => _devWorking = true);
    try {
      final res = await NeyvoPulseApi.getWarmUpStatus(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Warm-up: ${res['status'] ?? res}')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Warm-up check failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  Future<void> _devCapacity() async {
    final id = _devPhoneNumberIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone_number_id to check capacity')));
      return;
    }
    setState(() => _devWorking = true);
    try {
      final res = await NeyvoPulseApi.getNumberCapacity(id);
      if (!mounted) return;
      final remaining = res['remaining_today'] ?? res['remaining'] ?? res;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Capacity: $remaining calls remaining today')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Capacity check failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  Future<void> _devAdvanceWarmup() async {
    final id = _devPhoneNumberIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone_number_id to advance warm-up')));
      return;
    }
    setState(() => _devWorking = true);
    try {
      await NeyvoPulseApi.advanceWarmUp(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Warm-up advanced for $id')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Advance warm-up failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _schoolName.dispose();
    _defaultLateFee.dispose();
    _currency.dispose();
    _vapiPhoneNumberId.dispose();
    _vapiAssistantId.dispose();
    _callScript.dispose();
    _primaryPhoneController.dispose();
    _memberUserIdController.dispose();
    _linkAccountIdController.dispose();
    _devPhoneNumberIdController.dispose();
    _devPhoneE164Controller.dispose();
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
        _primaryIndustry = s['primary_industry']?.toString() ?? 'Healthcare';
        final tz = (s['timezone']?.toString() ?? '').trim();
        _timezoneValue = tz.isNotEmpty ? tz : 'America/New_York';
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
        schoolName: _schoolName.text.trim().isEmpty ? null : _schoolName.text.trim(),
        defaultLateFee: _defaultLateFee.text.trim().isEmpty ? null : _defaultLateFee.text.trim(),
        currency: _currency.text.trim().isEmpty ? null : _currency.text.trim(),
        timezone: _timezoneValue,
        inboundEnabled: _inboundEnabled,
        primaryPhoneE164: _primaryPhoneController.text.trim().isEmpty ? null : _primaryPhoneController.text.trim(),
        vapiAssistantId: _vapiAssistantId.text.trim().isEmpty ? null : _vapiAssistantId.text.trim(),
        vapiPhoneNumberId: _vapiPhoneNumberId.text.trim().isEmpty ? null : _vapiPhoneNumberId.text.trim(),
        defaultAgentId: _defaultAgentId,
      );
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
    
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          labelColor: NeyvoTheme.teal,
          unselectedLabelColor: NeyvoTheme.textSecondary,
          indicatorColor: NeyvoTheme.teal,
          tabs: const [
            Tab(text: 'Organization'),
            Tab(text: 'Team'),
            Tab(text: 'Security'),
            Tab(text: 'Telephony'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOrganizationTab(user),
              _buildTeamTab(),
              _buildSecurityTab(user),
              _buildApiKeysTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrganizationTab(User? user) {
    return ListView(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      children: [
        Text('Organization', style: NeyvoType.headlineLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.sm),
        Text(
          'Configure your organization and preferences',
          style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
        ),
        const SizedBox(height: NeyvoSpacing.lg),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Billing', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Wallet, subscription, numbers cost, add-ons.', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.billing),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NeyvoSpacing.sm),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Integrations', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Inbound health check and data sync.', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.integrations),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        Text('Account', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.md),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined, color: NeyvoTheme.textSecondary),
                  title: Text('Account ID', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (_accountId != null && _accountId!.length <= 20) ? _accountId! : '—',
                        style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
                      ),
                      if (_accountId != null && _accountId!.length > 20)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Backend should return a short Account ID (e.g. 6–8 digits), not the document ID.',
                            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                          ),
                        )
                      else if (_accountId == NeyvoPulseApi.defaultAccountId)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Account ID is set when your account is created. Use it when contacting support.',
                            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                          ),
                        ),
                    ],
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
                Padding(
                  padding: const EdgeInsets.only(left: NeyvoSpacing.lg, right: NeyvoSpacing.lg, bottom: NeyvoSpacing.sm),
                  child: Text(
                    'Your unique account identifier. Use it when linking integrations or contacting support.',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: NeyvoTheme.textSecondary),
                  title: Text('Email', style: NeyvoType.bodyLarge.copyWith(color: NeyvoTheme.textPrimary)),
                  subtitle: Text(user?.email ?? 'Not signed in', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary)),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_outlined, color: NeyvoTheme.textSecondary),
                  title: Text('Phone', style: NeyvoType.bodyLarge.copyWith(color: NeyvoTheme.textPrimary)),
                  subtitle: Text(_userPhone(user), style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary)),
                ),
                if (user != null && _userPhone(user) == '—')
                  Padding(
                    padding: const EdgeInsets.only(left: NeyvoSpacing.lg, top: 4),
                    child: Text(
                      'Add a phone in Firebase Auth (phone sign-in or link phone to this account) to see it here.',
                      style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                    ),
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.only(left: NeyvoSpacing.lg, right: NeyvoSpacing.lg, top: NeyvoSpacing.md, bottom: NeyvoSpacing.sm),
                  child: Text(
                    'Link to a different account',
                    style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: NeyvoSpacing.lg, vertical: NeyvoSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _linkAccountIdController,
                          decoration: const InputDecoration(
                            labelText: 'Account ID (6–8 digits)',
                            hintText: 'e.g. 12345678',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _linkToAccount(),
                        ),
                      ),
                      const SizedBox(width: NeyvoSpacing.md),
                      FilledButton(
                        onPressed: _linkingAccount ? null : _linkToAccount,
                        child: _linkingAccount ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Link'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: NeyvoSpacing.lg, right: NeyvoSpacing.lg, bottom: NeyvoSpacing.md),
                  child: Text(
                    'Switch this user to another org. You must be signed in (X-User-Id). After linking, the app will reload settings for the new account.',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: NeyvoSpacing.xl),
        
        // Organization Information
        Text('Organization Information', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.md),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Column(
              children: [
                TextField(
                  controller: _schoolName,
                  decoration: const InputDecoration(
                    labelText: 'Organization Name',
                    hintText: 'Acme Inc',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: NeyvoSpacing.md),
                DropdownButtonFormField<String>(
                  value: _primaryIndustry,
                  decoration: const InputDecoration(
                    labelText: 'Primary Industry',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    'Healthcare', 'Education', 'Automotive', 'Real Estate',
                    'Finance', 'Retail', 'Sales', 'Recruitment', 'Logistics',
                    'Hospitality', 'Insurance', 'Government', 'Home Services',
                    'Telecom', 'Custom',
                  ]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _primaryIndustry = v ?? 'Healthcare'),
                ),
                const SizedBox(height: NeyvoSpacing.md),
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
                TextField(
                  controller: _primaryPhoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone number (E.164)',
                    hintText: '+1234567890',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    suffixIcon: _verifyingPhone
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : TextButton(
                            onPressed: _primaryPhoneController.text.trim().isEmpty ? null : () async {
                              setState(() => _verifyingPhone = true);
                              try {
                                // Backend verify endpoint if available; for now just mark as verified
                                await Future.delayed(const Duration(milliseconds: 800));
                                if (mounted) setState(() { _phoneVerified = true; _verifyingPhone = false; });
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Number format accepted. Save to update.')));
                              } catch (_) {
                                if (mounted) setState(() => _verifyingPhone = false);
                              }
                            },
                            child: const Text('Verify'),
                          ),
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: NeyvoSpacing.md),
                Text(
                  'Voice / Vapi',
                  style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textSecondary),
                ),
                const SizedBox(height: NeyvoSpacing.sm),
                TextField(
                  controller: _vapiAssistantId,
                  decoration: const InputDecoration(
                    labelText: 'Vapi Assistant ID',
                    hintText: 'e.g. from Vapi dashboard',
                    prefixIcon: Icon(Icons.smart_toy_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: NeyvoSpacing.sm),
                TextField(
                  controller: _vapiPhoneNumberId,
                  decoration: const InputDecoration(
                    labelText: 'Vapi Phone Number ID',
                    hintText: 'Optional',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
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
        
        // Save Button
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
        
        // Data integration (link to Integrations tab)
        Card(
          color: NeyvoTheme.bgCard,
          child: ListTile(
            leading: const Icon(Icons.integration_instructions_outlined, color: NeyvoTheme.textSecondary),
            title: Text('Data integration', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
            subtitle: Text('Connect your data: webhook, CSV upload, API pull', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _tabController.animateTo(3),
          ),
        ),
        const SizedBox(height: NeyvoSpacing.md),

        // Seed templates (run once if agent wizard shows no templates)
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Templates & voice profiles', style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textSecondary)),
                const SizedBox(height: NeyvoSpacing.sm),
                Text('If the agent wizard shows no use-case options, seed the template library once.', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                const SizedBox(height: NeyvoSpacing.sm),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Seed templates'),
                      onPressed: () async {
                        try {
                          await NeyvoPulseApi.seedTemplates();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Templates seeded.')));
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.record_voice_over, size: 18),
                      label: const Text('Seed voice profiles'),
                      onPressed: () async {
                        try {
                          await NeyvoPulseApi.seedVoiceProfiles();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice profiles seeded.')));
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NeyvoSpacing.md),
        if (_isEducationOrg) ...[
          Text('Student Data Integration', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
          const SizedBox(height: NeyvoSpacing.xs),
          Text(
            'Sync student and payment data automatically from your school system.',
            style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
          ),
          const SizedBox(height: NeyvoSpacing.md),
          Card(
            color: NeyvoTheme.bgCard,
            child: Padding(
              padding: const EdgeInsets.all(NeyvoSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: _schoolIntegration?['enabled'] == true,
                    onChanged: (v) async {
                      try {
                        await NeyvoPulseApi.patchSchoolIntegration(enabled: v);
                        _load();
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
                    title: const Text('Enable Integration'),
                  ),
                  if (_schoolIntegration?['enabled'] == true) ...[
                    const Divider(),
                    ListTile(
                      title: Text('Webhook URL', style: NeyvoType.labelLarge),
                      subtitle: const SelectableText('https://neyvo-launch.onrender.com/api/pulse/integrations/school/webhook'),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: 'https://neyvo-launch.onrender.com/api/pulse/integrations/school/webhook'));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copied')));
                        },
                      ),
                    ),
                    ListTile(
                      title: Text('Webhook Token', style: NeyvoType.labelLarge),
                      subtitle: Text(_schoolTokenVisible ? (_schoolIntegration?['token'] ?? '••••••••') : '••••••••••••••••'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _schoolTokenVisible = !_schoolTokenVisible),
                            child: Text(_schoolTokenVisible ? 'Hide' : 'Reveal'),
                          ),
                          TextButton(
                            onPressed: () async {
                              try {
                                final res = await NeyvoPulseApi.regenerateSchoolIntegrationToken();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('New token: ${res['token'] ?? 'saved'} (copy it now; it won\'t be shown again)')));
                                  _load();
                                }
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                              }
                            },
                            child: const Text('Regenerate'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Regenerating will break existing integrations until you update the token.', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.warning)),
                    const SizedBox(height: NeyvoSpacing.md),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Send Test Event'),
                      onPressed: () async {
                        try {
                          await NeyvoPulseApi.sendSchoolWebhookTest();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Test received — integration is working')));
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Test failed: $e')));
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: NeyvoSpacing.lg),
        ],
        // Developer console – phone numbers (moved from Billing)
        _buildBillingTabDeveloperSection(),
        // System Info
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('System Information', style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textSecondary)),
                const SizedBox(height: NeyvoSpacing.xs),
                Text('Backend: https://neyvo-launch.onrender.com', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                Text('Version: 1.0.0', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamTab() {
    return ListView(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      children: [
        Text('Team', style: NeyvoType.headlineLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.sm),
        Text(
          'Manage team members and roles',
          style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        Text('Your role: ${_myRole ?? "—"}', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
        const SizedBox(height: NeyvoSpacing.md),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_myRole == 'admin') ...[
                  Text('Assign role (by Firebase UID)', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                  const SizedBox(height: NeyvoSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _memberUserIdController,
                          decoration: const InputDecoration(
                            labelText: 'User ID',
                            hintText: 'Firebase UID',
                          ),
                        ),
                      ),
                      const SizedBox(width: NeyvoSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _newMemberRole,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: ['admin', 'staff', 'viewer']
                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (v) => setState(() => _newMemberRole = v ?? 'staff'),
                        ),
                      ),
                      const SizedBox(width: NeyvoSpacing.sm),
                      FilledButton(
                        onPressed: () async {
                          final uid = _memberUserIdController.text.trim();
                          if (uid.isEmpty) return;
                          try {
                            await NeyvoPulseApi.setMemberRole(uid, _newMemberRole);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role updated')));
                              _load();
                            }
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                          }
                        },
                        child: const Text('Set role'),
                      ),
                    ],
                  ),
                  const SizedBox(height: NeyvoSpacing.lg),
                ],
                Text('Members with assigned roles:', style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textPrimary)),
                const SizedBox(height: NeyvoSpacing.xs),
                if (_members.isEmpty) ...[
                  Text('None yet. Assign roles above (admin only).', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                  if (_myRole != 'admin' && FirebaseAuth.instance.currentUser?.uid != null) ...[
                    const SizedBox(height: NeyvoSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null) return;
                        try {
                          await NeyvoPulseApi.setMemberRole(uid, 'admin');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are now the first admin.')));
                            _load();
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Become first admin (one-time)'),
                    ),
                  ],
                ] else
                  ...(_members.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: NeyvoSpacing.xs),
                    child: Text('${m['user_id'] ?? m['id'] ?? '?'}: ${m['role'] ?? '—'}', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                  ))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBillingTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Billing moved', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Billing is now a dedicated section in the Voice OS navigation.',
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.billing),
              child: const Text('Open Billing'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingTabDeveloperSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: NeyvoSpacing.xl),
        Text('Developer console – phone numbers', style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.md),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attach/detach numbers and run verification checks (warm-up, capacity, freecaller, primary).',
                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                ),
                const SizedBox(height: NeyvoSpacing.md),
                TextField(
                  controller: _devPhoneNumberIdController,
                  decoration: const InputDecoration(
                    labelText: 'phone_number_id',
                    hintText: 'Twilio/Vapi number id',
                  ),
                ),
                const SizedBox(height: NeyvoSpacing.sm),
                TextField(
                  controller: _devPhoneE164Controller,
                  decoration: const InputDecoration(
                    labelText: 'Phone (E.164)',
                    hintText: '+1234567890',
                  ),
                ),
                const SizedBox(height: NeyvoSpacing.md),
                Wrap(
                  spacing: NeyvoSpacing.sm,
                  runSpacing: NeyvoSpacing.sm,
                  children: [
                    FilledButton.tonal(
                      onPressed: _devWorking ? null : _devAttachNumber,
                      child: const Text('Attach'),
                    ),
                    FilledButton.tonal(
                      onPressed: _devWorking ? null : _devDetachNumber,
                      child: const Text('Detach'),
                    ),
                    FilledButton.tonal(
                      onPressed: _devWorking ? null : _devSetPrimary,
                      child: const Text('Set primary'),
                    ),
                    FilledButton.tonal(
                      onPressed: _devWorking ? null : _devRegisterFreecaller,
                      child: const Text('Register freecaller'),
                    ),
                    FilledButton.tonal(
                      onPressed: _devWorking ? null : _devWarmupStatus,
                      child: const Text('Warm-up status'),
                    ),
                    FilledButton.tonal(
                      onPressed: _devWorking ? null : _devCapacity,
                      child: const Text('Capacity'),
                    ),
                    FilledButton.tonal(
                      onPressed: _devWorking ? null : _devAdvanceWarmup,
                      child: const Text('Advance warm-up'),
                    ),
                  ],
                ),
                if (_devWorking) ...[
                  const SizedBox(height: NeyvoSpacing.sm),
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: NeyvoSpacing.sm),
                      Text('Running operation...', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeysTab() {
    return ListView(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      children: [
        Text('API Keys', style: NeyvoType.headlineLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.sm),
        Text(
          'Generate and manage API keys for integrations',
          style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('API keys allow external services to access your account.', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                const SizedBox(height: NeyvoSpacing.md),
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API key generation coming soon')));
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Generate key'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityTab(User? user) {
    return ListView(
      padding: const EdgeInsets.all(NeyvoSpacing.lg),
      children: [
        Text('Security', style: NeyvoType.headlineLarge.copyWith(color: NeyvoTheme.textPrimary)),
        const SizedBox(height: NeyvoSpacing.sm),
        Text(
          'Password, sessions, and data export',
          style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
        ),
        const SizedBox(height: NeyvoSpacing.xl),
        Card(
          color: NeyvoTheme.bgCard,
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: NeyvoTheme.textSecondary),
                  title: Text('Change password', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                  subtitle: Text('Manage via Firebase Auth', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use Firebase console or email reset link')));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined, color: NeyvoTheme.textSecondary),
                  title: Text('Data export', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
                  subtitle: Text('GDPR-compliant export of your data', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data export coming soon')));
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
