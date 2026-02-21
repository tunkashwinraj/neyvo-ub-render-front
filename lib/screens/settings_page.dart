// lib/screens/settings_page.dart
// Enhanced settings page with VAPI config, call scripts, and customization

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import 'pulse_shell.dart';
import 'voice_tier_page.dart';
import '../theme/spearia_theme.dart';

class PulseSettingsPage extends StatefulWidget {
  const PulseSettingsPage({super.key});

  @override
  State<PulseSettingsPage> createState() => _PulseSettingsPageState();
}

class _PulseSettingsPageState extends State<PulseSettingsPage> {
  final _schoolName = TextEditingController();
  final _defaultLateFee = TextEditingController();
  final _currency = TextEditingController();
  final _vapiPhoneNumberId = TextEditingController();
  final _vapiAssistantId = TextEditingController();
  final _callScript = TextEditingController();
  
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _showAdvanced = false;
  String? _myRole;
  String? _voiceTierDisplay;
  String? _subscriptionTier;
  List<Map<String, dynamic>> _members = [];
  final _memberUserIdController = TextEditingController();
  String _newMemberRole = 'staff';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _schoolName.dispose();
    _defaultLateFee.dispose();
    _currency.dispose();
    _vapiPhoneNumberId.dispose();
    _vapiAssistantId.dispose();
    _callScript.dispose();
    _memberUserIdController.dispose();
    super.dispose();
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
        _vapiPhoneNumberId.text = s['vapi_phone_number_id']?.toString() ?? '';
        _vapiAssistantId.text = s['vapi_assistant_id']?.toString() ?? '';
        _callScript.text = s['call_script']?.toString() ?? '';
      }
      final roleRes = await NeyvoPulseApi.getMyRole();
      final membersRes = await NeyvoPulseApi.listMembers();
      try {
        final tierRes = await NeyvoPulseApi.getBillingTier();
        if (mounted) _voiceTierDisplay = tierRes['tier_display']?.toString();
      } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(SpeariaSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.error), textAlign: TextAlign.center),
                const SizedBox(height: SpeariaSpacing.lg),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.all(SpeariaSpacing.lg),
      children: [
        Text('Settings', style: SpeariaType.headlineLarge),
        const SizedBox(height: SpeariaSpacing.sm),
        Text(
          'Configure your school and system preferences',
          style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
        ),
        const SizedBox(height: SpeariaSpacing.xl),
        
        // School Information
        Text('School Information', style: SpeariaType.titleLarge),
        const SizedBox(height: SpeariaSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(SpeariaSpacing.lg),
            child: Column(
              children: [
                TextField(
                  controller: _schoolName,
                  decoration: const InputDecoration(
                    labelText: 'School Name',
                    hintText: 'Neyvo Academy',
                    prefixIcon: Icon(Icons.school),
                  ),
                ),
                const SizedBox(height: SpeariaSpacing.md),
                TextField(
                  controller: _defaultLateFee,
                  decoration: const InputDecoration(
                    labelText: 'Default Late Fee',
                    hintText: '\$25',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: SpeariaSpacing.md),
                TextField(
                  controller: _currency,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    hintText: 'USD',
                    prefixIcon: Icon(Icons.currency_exchange),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: SpeariaSpacing.xl),
        
        // Subscription Plan
        Text('Subscription Plan', style: SpeariaType.titleLarge),
        const SizedBox(height: SpeariaSpacing.md),
        Card(
          child: ListTile(
            title: Text(_subscriptionTier == 'business' ? 'Business' : _subscriptionTier == 'pro' ? 'Pro' : 'Free', style: SpeariaType.titleMedium),
            subtitle: const Text('Unlock voice tiers and credit bonus. Only wallet top-ups and subscription charge your card.'),
            trailing: FilledButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.subscriptionPlan))),
              child: const Text('Change Plan'),
            ),
          ),
        ),
        
        const SizedBox(height: SpeariaSpacing.xl),
        
        // Voice Tier
        Text('Voice tier', style: SpeariaType.titleLarge),
        const SizedBox(height: SpeariaSpacing.md),
        Card(
          child: ListTile(
            title: Text(_voiceTierDisplay ?? 'Natural Human', style: SpeariaType.titleMedium),
            subtitle: const Text('Billed per minute. Change tier anytime.'),
            trailing: FilledButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceTierPage())),
              child: const Text('Change'),
            ),
          ),
        ),
        
        const SizedBox(height: SpeariaSpacing.xl),
        
        // VAPI Configuration
        Text('VAPI Configuration', style: SpeariaType.titleLarge),
        const SizedBox(height: SpeariaSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(SpeariaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _vapiPhoneNumberId,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number ID',
                    hintText: '3007da9c-6d2c-4c38-85bd-6cfa7900f8f2',
                    prefixIcon: Icon(Icons.phone),
                    helperText: 'VAPI phone number ID for outbound calls',
                  ),
                ),
                const SizedBox(height: SpeariaSpacing.md),
                TextField(
                  controller: _vapiAssistantId,
                  decoration: const InputDecoration(
                    labelText: 'Assistant ID',
                    hintText: '93f2fcf8-a0e8-422c-be36-2d7c20fb4904',
                    prefixIcon: Icon(Icons.smart_toy),
                    helperText: 'VAPI assistant ID for AI conversations',
                  ),
                ),
                const SizedBox(height: SpeariaSpacing.md),
                Text(
                  'Note: VAPI configuration is stored locally. Update these values when your VAPI setup changes.',
                  style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: SpeariaSpacing.xl),
        
        // Call Scripts
        ExpansionTile(
          title: Text('Call Scripts & Customization', style: SpeariaType.titleLarge),
          subtitle: Text('Customize AI behavior and call scripts', style: SpeariaType.bodySmall),
          initiallyExpanded: false,
          children: [
            Card(
              margin: const EdgeInsets.only(top: SpeariaSpacing.md),
              child: Padding(
                padding: const EdgeInsets.all(SpeariaSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call Script Template',
                      style: SpeariaType.titleMedium,
                    ),
                    const SizedBox(height: SpeariaSpacing.sm),
                    Text(
                      'Customize the AI prompt for outbound calls. Use placeholders like {student_name}, {balance}, {due_date}.',
                      style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted),
                    ),
                    const SizedBox(height: SpeariaSpacing.md),
                    TextField(
                      controller: _callScript,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Call Script',
                        hintText: 'Hello {student_name}, this is a reminder about your balance of {balance}...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: SpeariaSpacing.md),
                    Wrap(
                      spacing: SpeariaSpacing.sm,
                      children: [
                        Chip(
                          label: const Text('{student_name}'),
                          onDeleted: () {
                            _callScript.text += ' {student_name}';
                            _callScript.selection = TextSelection.fromPosition(
                              TextPosition(offset: _callScript.text.length),
                            );
                          },
                        ),
                        Chip(
                          label: const Text('{balance}'),
                          onDeleted: () {
                            _callScript.text += ' {balance}';
                            _callScript.selection = TextSelection.fromPosition(
                              TextPosition(offset: _callScript.text.length),
                            );
                          },
                        ),
                        Chip(
                          label: const Text('{due_date}'),
                          onDeleted: () {
                            _callScript.text += ' {due_date}';
                            _callScript.selection = TextSelection.fromPosition(
                              TextPosition(offset: _callScript.text.length),
                            );
                          },
                        ),
                        Chip(
                          label: const Text('{late_fee}'),
                          onDeleted: () {
                            _callScript.text += ' {late_fee}';
                            _callScript.selection = TextSelection.fromPosition(
                              TextPosition(offset: _callScript.text.length),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: SpeariaSpacing.xl),

        // Team roles (Phase D RBAC)
        Text('Team roles', style: SpeariaType.titleLarge),
        const SizedBox(height: SpeariaSpacing.sm),
        Text(
          'Your role: ${_myRole ?? "—"} (used for access control when signed in)',
          style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary),
        ),
        const SizedBox(height: SpeariaSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(SpeariaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_myRole == 'admin') ...[
                  Text('Assign role to a user (by Firebase UID)', style: SpeariaType.titleMedium),
                  const SizedBox(height: SpeariaSpacing.sm),
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
                      const SizedBox(width: SpeariaSpacing.sm),
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
                      const SizedBox(width: SpeariaSpacing.sm),
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
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                            }
                          }
                        },
                        child: const Text('Set role'),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpeariaSpacing.lg),
                ],
                Text('Members with assigned roles:', style: SpeariaType.labelMedium),
                const SizedBox(height: SpeariaSpacing.xs),
                if (_members.isEmpty) ...[
                  Text('None yet. Assign roles above (admin only).', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
                  if (_myRole != 'admin' && FirebaseAuth.instance.currentUser?.uid != null) ...[
                    const SizedBox(height: SpeariaSpacing.sm),
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
                    padding: const EdgeInsets.only(bottom: SpeariaSpacing.xs),
                    child: Text('${m['user_id'] ?? m['id'] ?? '?'}: ${m['role'] ?? '—'}', style: SpeariaType.bodySmall),
                  ))),
              ],
            ),
          ),
        ),

        const SizedBox(height: SpeariaSpacing.xl),
        
        // Save Button
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text(_saving ? 'Saving...' : 'Save Settings'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: SpeariaSpacing.md),
          ),
        ),
        
        const SizedBox(height: SpeariaSpacing.lg),
        
        // Data integration (link to dedicated page)
        Card(
          child: ListTile(
            leading: const Icon(Icons.integration_instructions_outlined),
            title: const Text('Data integration'),
            subtitle: const Text('Connect your school DB: webhook, CSV upload, API pull'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(PulseRouteNames.integration),
          ),
        ),
        const SizedBox(height: SpeariaSpacing.md),

        // System Info
        Card(
          color: SpeariaAura.bgDark,
          child: Padding(
            padding: const EdgeInsets.all(SpeariaSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('System Information', style: SpeariaType.labelMedium.copyWith(color: SpeariaAura.textSecondary)),
                const SizedBox(height: SpeariaSpacing.xs),
                Text('Backend: https://neyvo-pulse.onrender.com', style: SpeariaType.bodySmall),
                Text('Version: 1.0.0', style: SpeariaType.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
