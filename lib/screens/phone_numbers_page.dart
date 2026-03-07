// lib/screens/phone_numbers_page.dart
// Voice OS – Numbers Hub: Production numbers only.

import 'package:flutter/material.dart';

import '../features/managed_profiles/managed_profile_api_service.dart';
import '../neyvo_pulse_api.dart';
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

  final Map<String, bool> _attaching = {};
  bool _syncingFromVapi = false;

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
        NeyvoPulseApi.getAccountInfo(),
        NeyvoPulseApi.listNumbers(),
        ManagedProfileApiService.listProfiles(),
      ]);

      final account = results[0] as Map<String, dynamic>;
      final numbersRes = results[1] as Map<String, dynamic>;
      final profilesRes = results[2] as Map<String, dynamic>;

      final raw = (numbersRes['numbers'] as List?) ?? (numbersRes['items'] as List?) ?? const [];
      final numbers = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final profList = (profilesRes['profiles'] as List?)?.cast<dynamic>() ?? const [];
      final profiles = profList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (!mounted) return;
      setState(() {
        _account = account;
        _numbers = numbers;
        _profiles = profiles;
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

  Future<void> _syncFromVapi() async {
    setState(() => _syncingFromVapi = true);
    try {
      final res = await NeyvoPulseApi.syncNumbersFromVapi();
      if (!mounted) return;
      final added = res['added_count'] as int? ?? 0;
      final message = res['message'] as String? ?? (added > 0 ? 'Added $added number(s) from VAPI.' : 'No new numbers to add.');
      setState(() => _syncingFromVapi = false);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncingFromVapi = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Primary number (if any) – imported or assigned as primary. Shown in its own section.
  List<Map<String, dynamic>> get _primaryNumbers {
    return _numbers
        .where((n) => (n['role']?.toString().toLowerCase() ?? '') == 'primary')
        .toList();
  }

  /// Non-primary numbers for the "Production numbers" grid.
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
                    'Production numbers for your voice agents.',
                    style: NeyvoTextStyles.body,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Numbers only appear here after they are linked to your account. Use "Refresh" to pull in all numbers from your VAPI dashboard.',
                    style: NeyvoTextStyles.body.copyWith(
                      color: NeyvoColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_primaryNumbers.isNotEmpty) _primarySection(),
                  if (_primaryNumbers.isNotEmpty) const SizedBox(height: 20),
                  _productionGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primarySection() {
    final primary = _primaryNumbers;
    if (primary.isEmpty) return const SizedBox.shrink();
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.call, color: NeyvoColors.teal),
              const SizedBox(width: 10),
              Text('Primary number', style: NeyvoTextStyles.heading),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your main number (imported or set as primary). Used for inbound and as default outbound.',
            style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: primary.map((n) => _prodCard(n)).toList(),
          ),
        ],
      ),
    );
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
                onPressed: _syncingFromVapi ? null : _syncFromVapi,
                icon: _syncingFromVapi
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync, size: 18),
                label: Text(_syncingFromVapi ? 'Refreshing…' : 'Refresh'),
              ),
              TextButton.icon(
                onPressed: _openBuyNumber,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Buy number'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (nums.isEmpty && _primaryNumbers.isEmpty)
            Text(
              'No numbers yet. Buy a number or use Refresh to link numbers you already have in the VAPI dashboard.',
              style: NeyvoTextStyles.body,
            )
          else if (nums.isEmpty)
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
          includeSuggested: false,
        );
        // Backend returns "available" (Neyvo Pulse) or "items" (legacy); support both
        final list = (res['available'] as List?)?.cast<Map<String, dynamic>>() ??
            (res['items'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
        final message = res['message'] as String?;
        setInner(() {
          results = list;
          err = list.isEmpty && message != null && message.isNotEmpty ? message : null;
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
                        hintText: 'e.g. 203',
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
                style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: NeyvoColors.white),
                icon: searching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.white))
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
                      final locality = (r['locality'] ?? '').toString().trim();
                      final region = (r['region'] ?? '').toString().trim();
                      final location = locality.isNotEmpty && region.isNotEmpty
                          ? '$locality, $region'
                          : (locality.isNotEmpty ? locality : (region.isNotEmpty ? region : null));
                      final selected = selectedE164 == e164;
                      return ListTile(
                        title: Text(friendly, style: NeyvoTextStyles.bodyPrimary),
                        subtitle: Text(
                          location != null ? '$e164 — $location' : e164,
                          style: NeyvoTextStyles.micro,
                        ),
                        trailing: selected ? const Icon(Icons.check_circle, color: NeyvoColors.success) : null,
                        onTap: purchasing ? null : () => setInner(() => selectedE164 = e164),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: (selectedE164 == null || purchasing) ? null : () => purchase(setInner),
                  style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal, foregroundColor: NeyvoColors.white),
                  child: purchasing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.white))
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
