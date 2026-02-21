// lib/screens/addons_page.dart
// Add-ons & Features: extra numbers (115 cr/mo), Neyvo Shield (50 cr/mo per number), HIPAA (4900 cr/mo on Pro; included on Business).
// All charged from wallet. Calls PATCH /api/billing/addons/shield and /api/billing/addons/hipaa.

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import 'pulse_shell.dart';
import '../theme/spearia_theme.dart';

class AddonsPage extends StatefulWidget {
  const AddonsPage({super.key});

  @override
  State<AddonsPage> createState() => _AddonsPageState();
}

class _AddonsPageState extends State<AddonsPage> {
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _numbers;
  bool _loading = true;
  String? _error;
  String? _updating;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        NeyvoPulseApi.getBillingWallet(),
        NeyvoPulseApi.listNumbers(),
      ]);
      if (mounted) setState(() {
        _wallet = results[0] as Map<String, dynamic>?;
        _numbers = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int get _includedNumbers {
    final t = (_wallet?['subscription_tier'] as String?)?.toLowerCase() ?? 'free';
    if (t == 'business') return 10;
    if (t == 'pro') return 3;
    return 1;
  }

  List<dynamic> get _numberList => _numbers?['numbers'] as List? ?? [];

  List<String> get _shieldNumberIds => List<String>.from(_wallet?['addon_shield_numbers'] as List? ?? []);

  bool get _hipaaEnabled => _wallet?['addon_hipaa'] == true;

  String get _subTier => (_wallet?['subscription_tier'] as String?)?.toLowerCase() ?? 'free';

  int get _extraNumberCount => (_wallet?['extra_number_ids'] as List?)?.length ?? 0;

  int get _monthlyCreditsExtraNumbers => (_numberList.length > _includedNumbers ? _numberList.length - _includedNumbers : 0) * 115;

  int get _monthlyCreditsShield => _shieldNumberIds.length * 50;

  int get _monthlyCreditsHipaa {
    if (_subTier == 'business') return 0;
    if (_subTier == 'pro' && _hipaaEnabled) return 4900;
    return 0;
  }

  int get _monthlyCreditsTotal => _monthlyCreditsExtraNumbers + _monthlyCreditsShield + _monthlyCreditsHipaa;

  Future<void> _toggleShield(String numberId, bool enabled) async {
    if (_updating != null) return;
    setState(() => _updating = numberId);
    try {
      await NeyvoPulseApi.setAddonShield(numberId: numberId, enabled: enabled);
      if (mounted) _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _updating = null);
    }
  }

  Future<void> _toggleHipaa(bool enabled) async {
    if (_updating != null) return;
    if (_subTier == 'free') return;
    setState(() => _updating = 'hipaa');
    try {
      await NeyvoPulseApi.setAddonHipaa(enabled: enabled);
      if (mounted) _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _updating = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _wallet == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading add-ons…', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add-ons & Features', style: SpeariaType.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Everything here is charged from your wallet — no extra subscriptions.',
            style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
          ),
          const SizedBox(height: 32),
          // A — Phone Numbers
          Text('Phone Numbers', style: SpeariaType.titleLarge),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Included: $_includedNumbers number${_includedNumbers == 1 ? '' : 's'} on your plan.', style: SpeariaType.bodyMedium),
                  if (_numberList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._numberList.map<Widget>((n) {
                      final id = n['id'] as String? ?? n['number_id']?.toString() ?? '';
                      final phone = n['phone_number'] as String? ?? n['friendly_name']?.toString() ?? id;
                      final isExtra = _numberList.indexOf(n) >= _includedNumbers;
                      return ListTile(
                        title: Text(phone, style: SpeariaType.bodyMedium),
                        subtitle: isExtra ? const Text('115 credits/month (\$1.15) auto-deducted', style: TextStyle(fontSize: 12, color: SpeariaAura.textMuted)) : null,
                        dense: true,
                      );
                    }),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PulseShell(initialRouteName: PulseRouteNames.phoneNumbers))),
                    icon: const Icon(Icons.add),
                    label: const Text('Add another number'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // B — Neyvo Shield
          Text('Neyvo Shield (Spam Protection)', style: SpeariaType.titleLarge),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('50 credits/month (\$0.50) per number. Automatic spam flag monitoring and caller registry.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary)),
                  if (_numberList.isEmpty)
                    Padding(padding: const EdgeInsets.only(top: 12), child: Text('Add a phone number first.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)))
                  else
                    ..._numberList.map<Widget>((n) {
                      final id = n['id'] as String? ?? n['number_id']?.toString() ?? '';
                      final phone = n['phone_number'] as String? ?? n['friendly_name']?.toString() ?? id;
                      final enabled = _shieldNumberIds.contains(id);
                      return SwitchListTile(
                        title: Text(phone, style: SpeariaType.bodyMedium),
                        subtitle: const Text('50 credits/month per number'),
                        value: enabled,
                        onChanged: _updating != null ? null : (v) => _toggleShield(id, v),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // C — HIPAA
          Text('HIPAA Compliance Mode', style: SpeariaType.titleLarge),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Required for healthcare, student financial data, and legal clients.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary)),
                  const SizedBox(height: 12),
                  if (_subTier == 'free')
                    ListTile(
                      title: const Text('Upgrade to Pro or Business to enable HIPAA'),
                      leading: Icon(Icons.lock_outline, color: SpeariaAura.textMuted),
                    )
                  else if (_subTier == 'business')
                    const ListTile(
                      title: Text('Included in your Business plan — no extra charge'),
                      leading: Icon(Icons.check_circle_outline, color: SpeariaAura.success),
                    )
                  else
                    SwitchListTile(
                      title: const Text('Enable HIPAA Compliance'),
                      subtitle: const Text('4,900 credits/month (\$49.00)'),
                      value: _hipaaEnabled,
                      onChanged: _updating != null ? null : (v) => _toggleHipaa(v),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // D — Monthly cost preview
          Text('Monthly cost preview', style: SpeariaType.titleLarge),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: SpeariaAura.border)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your estimated add-on cost this month: $_monthlyCreditsTotal credits (\$${(_monthlyCreditsTotal / 100).toStringAsFixed(2)})', style: SpeariaType.titleMedium),
                  const SizedBox(height: 8),
                  Text('$_monthlyCreditsExtraNumbers credits for extra numbers + $_monthlyCreditsShield credits for Shield + $_monthlyCreditsHipaa credits for HIPAA', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
