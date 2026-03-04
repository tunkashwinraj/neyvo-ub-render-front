// lib/screens/phone_numbers_page.dart
// Voice OS – Numbers Hub: Training number, Production numbers, inline routing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/business_intelligence/routing_api_service.dart';
import '../features/managed_profiles/managed_profile_api_service.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../theme/neyvo_theme.dart';
import '../ui/components/glass/neyvo_glass_panel.dart';

class PhoneNumbersPage extends StatefulWidget {
  const PhoneNumbersPage({super.key});

  @override
  State<PhoneNumbersPage> createState() => _PhoneNumbersPageState();
}

class _PhoneNumbersPageState extends State<PhoneNumbersPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _account = const {};
  List<Map<String, dynamic>> _numbers = const [];
  List<Map<String, dynamic>> _profiles = const [];

  // Routing config (always visible, inline).
  String _routingMode = 'single'; // single | silent_intent
  String _defaultProfileId = '';
  final Map<String, String> _intentMap = {
    'sales': '',
    'support': '',
    'booking': '',
    'billing': '',
  };
  double _confidence = 0.75;
  bool _savingRouting = false;
  String? _routingErr;

  // Per-number attaching state.
  final Map<String, bool> _attaching = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _routingErr = null;
    });
    try {
      final results = await Future.wait([
        NeyvoPulseApi.getAccountInfo(),
        NeyvoPulseApi.listNumbers(),
        ManagedProfileApiService.listProfiles(),
        RoutingApiService.getConfig(),
      ]);

      final account = results[0] as Map<String, dynamic>;
      final numbersRes = results[1] as Map<String, dynamic>;
      final profilesRes = results[2] as Map<String, dynamic>;
      final routingRes = results[3] as Map<String, dynamic>;

      final raw = (numbersRes['numbers'] as List?) ?? (numbersRes['items'] as List?) ?? const [];
      final numbers = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final profList = (profilesRes['profiles'] as List?)?.cast<dynamic>() ?? const [];
      final profiles = profList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final config = routingRes['ok'] == true
          ? Map<String, dynamic>.from(routingRes['config'] as Map? ?? {})
          : <String, dynamic>{};

      final mode = (config['mode'] as String? ?? 'single').toString();
      final defaultProfileId = (config['defaultProfileId'] ?? '').toString();
      final intentMap = Map<String, dynamic>.from(config['intentMap'] as Map? ?? {});
      final confidence = (config['confidenceThreshold'] as num?)?.toDouble() ?? 0.75;

      if (!mounted) return;
      setState(() {
        _account = account;
        _numbers = numbers;
        _profiles = profiles;
        _routingMode = mode == 'silent_intent' ? 'silent_intent' : 'single';
        _defaultProfileId = defaultProfileId;
        _intentMap['sales'] = (intentMap['sales'] ?? '').toString();
        _intentMap['support'] = (intentMap['support'] ?? '').toString();
        _intentMap['booking'] = (intentMap['booking'] ?? '').toString();
        _intentMap['billing'] = (intentMap['billing'] ?? '').toString();
        _confidence = confidence.clamp(0.5, 0.95);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? get _trainingNumberObj {
    final primary = (_account['primary_phone_number_id'] ?? _account['vapi_phone_number_id'])?.toString().trim();
    if (primary != null && primary.isNotEmpty) {
      final byId = _numbers.firstWhere(
        (n) => ((n['phone_number_id'] ?? n['id'] ?? n['number_id'])?.toString() ?? '') == primary,
        orElse: () => const {},
      );
      if (byId.isNotEmpty) return byId;
    }
    final byRole = _numbers.firstWhere(
      (n) => (n['role']?.toString().toLowerCase() ?? '') == 'primary',
      orElse: () => const {},
    );
    return byRole.isEmpty ? null : byRole;
  }

  String? get _trainingE164 {
    final acct = (_account['primary_phone_e164'] ?? _account['primary_phone'])?.toString().trim();
    if (acct != null && acct.isNotEmpty) return acct;
    final n = _trainingNumberObj;
    final e = (n?['phone_number_e164'] ?? n?['phone_number'])?.toString().trim();
    return (e != null && e.isNotEmpty) ? e : null;
  }

  List<Map<String, dynamic>> get _productionNumbers {
    return _numbers
        .where((n) => (n['role']?.toString().toLowerCase() ?? '') != 'primary')
        .toList()
      ..sort((a, b) => _safeStr(a['phone_number_e164']).compareTo(_safeStr(b['phone_number_e164'])));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: NeyvoColors.teal));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Numbers', style: NeyvoTextStyles.title.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'Training number for quick tests, production numbers for scale, and routing that stays visible.',
                    style: NeyvoTextStyles.body,
                  ),
                  const SizedBox(height: 16),
                  _trainingHero(),
                  const SizedBox(height: 16),

                  _productionGrid(),
                  const SizedBox(height: 16),

                  _routingPanel(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trainingHero() {
    final e164 = _trainingE164 ?? '—';
    final n = _trainingNumberObj ?? const {};
    final warmUpWeek = (n['warm_up_week'] as num?)?.toInt();
    final dailyLimit = (n['daily_limit'] as num?)?.toInt();
    final remaining = (n['calls_remaining_today'] as num?)?.toInt();
    final attachedName = _safeStr(n['attached_profile_name']);
    final inboundEnabled = n['inbound_enabled'] as bool?;
    final outboundEnabled = n['outbound_enabled'] as bool?;

    return NeyvoGlassPanel(
      glowing: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.phone_in_talk_outlined, color: NeyvoColors.teal, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Training number', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
                const SizedBox(height: 6),
                Text(
                  e164,
                  style: NeyvoTextStyles.title.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Attached agent', attachedName.isEmpty ? '—' : attachedName),
                    if (warmUpWeek != null) _chip('Warm-up', 'Week $warmUpWeek'),
                    if (dailyLimit != null) _chip('Daily cap', '$dailyLimit'),
                    if (remaining != null) _chip('Remaining today', '$remaining'),
                    _chip('Inbound', (inboundEnabled ?? true) ? '✅' : '—'),
                    _chip('Outbound', (outboundEnabled ?? true) ? '✅' : '—'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: e164 == '—' ? null : _copyTrainingNumber,
                  style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: Colors.white),
                  child: const Text('Call this number now'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.launch),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NeyvoColors.textPrimary,
                    side: const BorderSide(color: NeyvoColors.borderDefault),
                  ),
                  child: const Text('Back to Launch'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyTrainingNumber() {
    final v = _trainingE164;
    if (v == null || v.isEmpty) return;
    Clipboard.setData(ClipboardData(text: v));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  Widget _productionGrid() {
    final nums = _productionNumbers;
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('Production numbers', style: NeyvoTextStyles.heading),
              const Spacer(),
              TextButton.icon(
                onPressed: _openBuyNumber,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Buy number'),
              ),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (nums.isEmpty)
            Text('No production numbers yet.', style: NeyvoTextStyles.body)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                int cols = 3;
                if (w < 980) cols = 2;
                if (w < 620) cols = 1;
                const gap = 12.0;
                final cardW = cols == 1 ? w : (w - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: nums.map((n) => SizedBox(width: cardW, child: _prodCard(n))).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _prodCard(Map<String, dynamic> n) {
    final numberId = _safeStr(n['number_id']).isNotEmpty
        ? _safeStr(n['number_id'])
        : _safeStr(n['id']).isNotEmpty
            ? _safeStr(n['id'])
            : _safeStr(n['phone_number_id']);
    final e164 = _safeStr(n['phone_number_e164']).isNotEmpty ? _safeStr(n['phone_number_e164']) : _safeStr(n['phone_number']);
    final role = (_safeStr(n['role']).isEmpty ? 'production' : _safeStr(n['role'])).toUpperCase();
    final warmUpWeek = (n['warm_up_week'] as num?)?.toInt();
    final dailyLimit = (n['daily_limit'] as num?)?.toInt();
    final usedToday = (n['calls_today'] as num?)?.toInt();
    final attachedProfileId = _safeStr(n['attached_profile_id']);
    final attachedProfileName = _safeStr(n['attached_profile_name']);

    final isAttaching = _attaching[numberId] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  e164.isEmpty ? '—' : e164,
                  style: NeyvoTextStyles.heading.copyWith(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: NeyvoColors.borderDefault),
                  color: NeyvoColors.bgOverlay.withOpacity(0.4),
                ),
                child: Text(role, style: NeyvoTextStyles.micro),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (warmUpWeek != null) _chip('Warm-up', 'Week $warmUpWeek'),
              if (dailyLimit != null)
                _chip('Daily cap', usedToday == null ? '$dailyLimit' : '$usedToday/$dailyLimit'),
              _chip('Routing', _routingMode == 'single' ? 'Single agent' : 'Intent'),
            ],
          ),
          const SizedBox(height: 12),
          Text('Operator attached', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _profiles.any((p) => _safeStr(p['profile_id']) == attachedProfileId) ? attachedProfileId : '',
            items: [
              const DropdownMenuItem(value: '', child: Text('— Not attached —')),
              ..._profiles.map((p) {
                final id = _safeStr(p['profile_id']);
                final name = _safeStr(p['profile_name']).isEmpty ? 'Unnamed agent' : _safeStr(p['profile_name']);
                return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
              }),
            ],
            onChanged: isAttaching
                ? null
                : (v) {
                    final id = (v ?? '').trim();
                    _attachNumberToProfile(numberId: numberId, profileId: id);
                  },
            decoration: InputDecoration(
              isDense: true,
              hintText: attachedProfileName.isEmpty ? '—' : attachedProfileName,
            ),
          ),
          if (isAttaching) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 3, color: NeyvoColors.teal, backgroundColor: NeyvoColors.bgBase),
          ],
        ],
      ),
    );
  }

  Future<void> _attachNumberToProfile({
    required String numberId,
    required String profileId,
  }) async {
    if (numberId.isEmpty) return;
    setState(() => _attaching[numberId] = true);
    try {
      if (profileId.isEmpty) {
        // No explicit detach endpoint exists; reloading will reflect server truth.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Detach is not available yet.')),
          );
        }
      } else {
        await ManagedProfileApiService.attachPhoneNumber(
          profileId: profileId,
          phoneNumberId: numberId,
          vapiPhoneNumberId: numberId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attached')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (!mounted) return;
      setState(() => _attaching[numberId] = false);
      _load();
    }
  }

  Widget _routingPanel() {
    return NeyvoGlassPanel(
      glowing: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_outlined, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('Routing panel', style: NeyvoTextStyles.heading),
              const Spacer(),
              if (_routingErr != null)
                Text(_routingErr!, style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.error)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                label: const Text('Single agent'),
                selected: _routingMode == 'single',
                onSelected: (v) => setState(() => _routingMode = 'single'),
              ),
              ChoiceChip(
                label: const Text('Intent routing'),
                selected: _routingMode == 'silent_intent',
                onSelected: (v) => setState(() => _routingMode = 'silent_intent'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_routingMode == 'single') ...[
            Text('Default agent', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _profiles.any((p) => _safeStr(p['profile_id']) == _defaultProfileId) ? _defaultProfileId : '',
              items: [
                const DropdownMenuItem(value: '', child: Text('— Select agent —')),
                ..._profiles.map((p) {
                  final id = _safeStr(p['profile_id']);
                  final name = _safeStr(p['profile_name']).isEmpty ? 'Unnamed agent' : _safeStr(p['profile_name']);
                  return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                }),
              ],
              onChanged: (v) => setState(() => _defaultProfileId = (v ?? '').trim()),
            ),
          ] else ...[
            Text('Intent → agent', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
            const SizedBox(height: 6),
            ..._intentMap.keys.map((intent) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(intent, style: NeyvoTextStyles.bodyPrimary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _profiles.any((p) => _safeStr(p['profile_id']) == (_intentMap[intent] ?? ''))
                              ? (_intentMap[intent] ?? '')
                              : '',
                          items: [
                            const DropdownMenuItem(value: '', child: Text('— None —')),
                            ..._profiles.map((p) {
                              final id = _safeStr(p['profile_id']);
                              final name = _safeStr(p['profile_name']).isEmpty ? 'Unnamed agent' : _safeStr(p['profile_name']);
                              return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                            }),
                          ],
                          onChanged: (v) => setState(() => _intentMap[intent] = (v ?? '').trim()),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 4),
            Text('Confidence threshold', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
            const SizedBox(height: 6),
            Slider(
              value: _confidence,
              min: 0.5,
              max: 0.95,
              divisions: 9,
              label: _confidence.toStringAsFixed(2),
              onChanged: (v) => setState(() => _confidence = v),
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _savingRouting ? null : _saveRouting,
              style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: Colors.white),
              child: _savingRouting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save routing'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pushNamed(PulseRouteNames.integrations),
            child: const Text('Inbound health check →'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRouting() async {
    setState(() {
      _savingRouting = true;
      _routingErr = null;
    });
    try {
      final intentMap = <String, String>{};
      for (final e in _intentMap.entries) {
        if (e.value.trim().isNotEmpty) intentMap[e.key] = e.value.trim();
      }
      final body = <String, dynamic>{
        'mode': _routingMode,
        'defaultProfileId': _defaultProfileId.trim(),
        'intentMap': intentMap,
        'confidenceThreshold': _confidence,
      };
      await RoutingApiService.updateConfig(body);
      if (!mounted) return;
      setState(() => _savingRouting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Routing updated')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingRouting = false;
        _routingErr = e.toString();
      });
    }
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: NeyvoColors.bgRaised.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NeyvoColors.borderSubtle),
      ),
      child: Text('$label: $value', style: NeyvoTextStyles.micro),
    );
  }

  static String _safeStr(dynamic v) => (v ?? '').toString().trim();

  Future<void> _openBuyNumber() async {
    final areaCodeCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: 'Production Line');
    String type = 'local';
    bool searching = false;
    bool purchasing = false;
    String? err;
    List<Map<String, dynamic>> results = const [];
    String? selectedE164;

    Future<void> search(StateSetter setInner) async {
      setInner(() {
        searching = true;
        err = null;
        results = const [];
        selectedE164 = null;
      });
      try {
        final res = await NeyvoPulseApi.searchNumbers(
          country: 'US',
          type: type,
          limit: 20,
          areaCode: areaCodeCtrl.text.trim().isEmpty ? null : areaCodeCtrl.text.trim(),
          voiceEnabled: true,
          smsEnabled: null,
          mmsEnabled: null,
          includeSuggested: true,
        );
        final list = (res['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        setInner(() {
          results = list;
          searching = false;
        });
      } catch (e) {
        setInner(() {
          err = e.toString();
          searching = false;
        });
      }
    }

    Future<void> purchase(StateSetter setInner) async {
      final num = (selectedE164 ?? '').trim();
      if (num.isEmpty) return;
      setInner(() {
        purchasing = true;
        err = null;
      });
      try {
        await NeyvoPulseApi.purchaseNumber(
          phoneNumber: num,
          friendlyName: nameCtrl.text.trim().isEmpty ? 'Production Line' : nameCtrl.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Number purchased')));
        _load();
      } catch (e) {
        setInner(() {
          purchasing = false;
          err = e.toString();
        });
      }
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NeyvoColors.bgOverlay,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Buy a number', style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (err != null) ...[
                Text(err!, style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.error)),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: 'local', child: Text('Local')),
                        DropdownMenuItem(value: 'mobile', child: Text('Mobile')),
                        DropdownMenuItem(value: 'tollfree', child: Text('Toll-free')),
                      ],
                      onChanged: searching || purchasing ? null : (v) => setInner(() => type = v ?? 'local'),
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: areaCodeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      decoration: const InputDecoration(
                        labelText: 'Area code',
                        hintText: 'Optional',
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Friendly name'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: searching || purchasing ? null : () => search(setInner),
                style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: Colors.white),
                icon: searching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search, size: 18),
                label: Text(searching ? 'Searching…' : 'Search'),
              ),
              const SizedBox(height: 12),
              if (results.isNotEmpty) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = results[i];
                      final e164 = (r['e164'] ?? r['phone_number'] ?? '').toString();
                      final friendly = (r['friendly'] ?? r['friendly_name'] ?? e164).toString();
                      final selected = selectedE164 == e164;
                      return ListTile(
                        title: Text(friendly, style: NeyvoTextStyles.bodyPrimary),
                        subtitle: Text(e164, style: NeyvoTextStyles.micro),
                        trailing: selected ? const Icon(Icons.check_circle, color: NeyvoColors.success) : null,
                        onTap: purchasing ? null : () => setInner(() => selectedE164 = e164),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: (selectedE164 == null || purchasing) ? null : () => purchase(setInner),
                  style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: Colors.white),
                  child: purchasing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Purchase selected number'),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    areaCodeCtrl.dispose();
    nameCtrl.dispose();
  }
}
