// lib/screens/phone_numbers_page.dart
// Voice OS – Numbers Hub: Production numbers only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/neyvo_api.dart';
import '../core/providers/numbers_provider.dart';
import '../theme/neyvo_theme.dart';
import '../ui/components/glass/neyvo_glass_panel.dart';

class PhoneNumbersPage extends ConsumerStatefulWidget {
  const PhoneNumbersPage({super.key});

  @override
  ConsumerState<PhoneNumbersPage> createState() => _PhoneNumbersPageState();
}

class _PhoneNumbersPageState extends ConsumerState<PhoneNumbersPage> {
  Future<void> _load() async {
    ref.invalidate(numbersNotifierProvider);
  }

  Future<void> _syncFromVapi() async {
    ref.read(numbersSyncBusyProvider.notifier).setBusy(true);
    try {
      final res = await ref.read(numbersNotifierProvider.notifier).syncNumbersFromVapi();
      if (!mounted) return;
      final added = res['added_count'] as int? ?? 0;
      final message = res['message'] as String? ?? (added > 0 ? 'Added $added number(s) from VAPI.' : 'No new numbers to add.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) ref.read(numbersSyncBusyProvider.notifier).setBusy(false);
    }
  }

  Future<void> _openImportNumber(NumbersData data) async {
    final numberCtrl = TextEditingController();
    final friendlyCtrl = TextEditingController(text: 'Production Line');
    String provider = 'twilio';
    bool setAsPrimary = true;

    final twilioSidCtrl = TextEditingController();
    final twilioTokenCtrl = TextEditingController();
    final telnyxKeyCtrl = TextEditingController();
    final vonageKeyCtrl = TextEditingController();
    final vonageSecretCtrl = TextEditingController();

    String? err;
    bool importing = false;

    Future<void> submit(StateSetter setInner) async {
      final number = numberCtrl.text.trim();
      if (number.isEmpty || !number.startsWith('+')) {
        setInner(() => err = 'Enter a valid E.164 number (e.g. +12035551234).');
        return;
      }
      if (provider == 'twilio' && (twilioSidCtrl.text.trim().isEmpty || twilioTokenCtrl.text.trim().isEmpty)) {
        setInner(() => err = 'Twilio Account SID and Auth Token are required.');
        return;
      }
      if (provider == 'telnyx' && telnyxKeyCtrl.text.trim().isEmpty) {
        setInner(() => err = 'Telnyx API key is required.');
        return;
      }
      if (provider == 'vonage' && (vonageKeyCtrl.text.trim().isEmpty || vonageSecretCtrl.text.trim().isEmpty)) {
        setInner(() => err = 'Vonage API key and secret are required.');
        return;
      }

      setInner(() {
        err = null;
        importing = true;
      });
      try {
        final res = await ref.read(numbersNotifierProvider.notifier).importNumberToOrg(
          provider: provider,
          numberE164: number,
          friendlyName: friendlyCtrl.text.trim().isEmpty ? null : friendlyCtrl.text.trim(),
          setAsPrimary: setAsPrimary,
          twilioAccountSid: twilioSidCtrl.text.trim(),
          twilioAuthToken: twilioTokenCtrl.text.trim(),
          telnyxApiKey: telnyxKeyCtrl.text.trim(),
          vonageApiKey: vonageKeyCtrl.text.trim(),
          vonageApiSecret: vonageSecretCtrl.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        if (!mounted) return;
        final msg = (res['message'] ?? 'Number imported and linked.').toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      } catch (e) {
        setInner(() {
          err = e.toString();
          importing = false;
        });
      } finally {
        if (mounted) setInner(() => importing = false);
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
                  Text('Import number to VAPI', style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                  const Spacer(),
                  IconButton(
                    onPressed: importing ? null : () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Import a carrier number (Twilio, Telnyx, or Vonage) into VAPI and link it to this account. The number will appear on the Phone Numbers tab and can be used by your operators.',
                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
              ),
              const SizedBox(height: 10),
              if (err != null) ...[
                Text(err!, style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.error)),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Text('Account ID', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
                  const SizedBox(width: 8),
                  Text(
                    _safeStr(data.account['account_id'] ?? data.account['id'] ?? ''),
                    style: NeyvoTextStyles.bodyPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: provider,
                items: const [
                  DropdownMenuItem(value: 'twilio', child: Text('Twilio')),
                  DropdownMenuItem(value: 'telnyx', child: Text('Telnyx')),
                  DropdownMenuItem(value: 'vonage', child: Text('Vonage')),
                ],
                onChanged: importing ? null : (v) => setInner(() => provider = v ?? 'twilio'),
                decoration: const InputDecoration(labelText: 'Provider'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: numberCtrl,
                enabled: !importing,
                decoration: const InputDecoration(
                  labelText: 'Number (E.164)',
                  hintText: 'e.g. +12035551234',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: friendlyCtrl,
                enabled: !importing,
                decoration: const InputDecoration(
                  labelText: 'Friendly name (optional)',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: setAsPrimary,
                    onChanged: importing ? null : (v) => setInner(() => setAsPrimary = v ?? true),
                  ),
                  const Expanded(child: Text('Set as primary')),
                ],
              ),
              const SizedBox(height: 6),
              if (provider == 'twilio') ...[
                TextField(
                  controller: twilioSidCtrl,
                  enabled: !importing,
                  decoration: const InputDecoration(labelText: 'Twilio Account SID'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: twilioTokenCtrl,
                  enabled: !importing,
                  decoration: const InputDecoration(labelText: 'Twilio Auth Token'),
                  obscureText: true,
                ),
              ] else if (provider == 'telnyx') ...[
                TextField(
                  controller: telnyxKeyCtrl,
                  enabled: !importing,
                  decoration: const InputDecoration(labelText: 'Telnyx API Key'),
                  obscureText: true,
                ),
              ] else if (provider == 'vonage') ...[
                TextField(
                  controller: vonageKeyCtrl,
                  enabled: !importing,
                  decoration: const InputDecoration(labelText: 'Vonage API Key'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: vonageSecretCtrl,
                  enabled: !importing,
                  decoration: const InputDecoration(labelText: 'Vonage API Secret'),
                  obscureText: true,
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: importing ? null : () => submit(setInner),
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: NeyvoColors.white),
                icon: importing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: NeyvoColors.white))
                    : const Icon(Icons.upload, size: 18),
                label: Text(importing ? 'Importing…' : 'Import & assign to org'),
              ),
              const SizedBox(height: 8),
              Text(
                'Credentials are used one-time to import this number into VAPI and are not stored on Neyvo servers.',
                style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );

    numberCtrl.dispose();
    friendlyCtrl.dispose();
    twilioSidCtrl.dispose();
    twilioTokenCtrl.dispose();
    telnyxKeyCtrl.dispose();
    vonageKeyCtrl.dispose();
    vonageSecretCtrl.dispose();
  }

  /// Primary number (if any) – imported or assigned as primary. Shown in its own section.
  /// Deduplicated by E.164 so the same number never appears twice.
  List<Map<String, dynamic>> _primaryNumbers(List<Map<String, dynamic>> numbers) {
    final rolePrimary = numbers
        .where((n) => (n['role']?.toString().toLowerCase() ?? '') == 'primary')
        .toList();
    final seen = <String>{};
    return rolePrimary.where((n) {
      final e164 = (n['phone_number'] ?? n['phone_number_e164'] ?? '').toString().trim();
      final key = e164.replaceAll(RegExp(r'\D'), '');
      if (key.isNotEmpty && seen.contains(key)) return false;
      if (key.isNotEmpty) seen.add(key);
      return true;
    }).toList();
  }

  /// Non-primary numbers for the "Production numbers" grid.
  List<Map<String, dynamic>> _productionNumbers(List<Map<String, dynamic>> numbers) {
    return numbers
        .where((n) => (n['role']?.toString().toLowerCase() ?? '') != 'primary')
        .toList()
      ..sort((a, b) => _safeStr(a['phone_number_e164']).compareTo(_safeStr(b['phone_number_e164'])));
  }

  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(numbersNotifierProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    return asyncValue.when(
      data: (data) => RefreshIndicator(
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
                      'Numbers only appear here after they are linked to your account. Use "Import from carrier" to bring in an existing Twilio, Telnyx, or Vonage number, or "Refresh" to pull in all numbers from your VAPI dashboard.',
                      style: NeyvoTextStyles.body.copyWith(
                        color: NeyvoColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_primaryNumbers(data.numbers).isNotEmpty) _primarySection(data),
                    if (_primaryNumbers(data.numbers).isNotEmpty) const SizedBox(height: 20),
                    _productionGrid(data),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      loading: () => Center(child: CircularProgressIndicator(color: primaryColor)),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$e', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _primarySection(NumbersData data) {
    final primary = _primaryNumbers(data.numbers);
    if (primary.isEmpty) return const SizedBox.shrink();
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.call, color: Theme.of(context).colorScheme.primary),
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
            children: primary.map((n) => _prodCard(data, n)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _productionGrid(NumbersData data) {
    final nums = _productionNumbers(data.numbers);
    final syncing = ref.watch(numbersSyncBusyProvider);
    return NeyvoGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text('Production numbers', style: NeyvoTextStyles.heading),
              const Spacer(),
              TextButton.icon(
                onPressed: syncing ? null : _syncFromVapi,
                icon: syncing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync, size: 18),
                label: Text(syncing ? 'Refreshing…' : 'Refresh'),
              ),
              TextButton.icon(
                onPressed: () => _openImportNumber(data),
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('Import from carrier'),
              ),
              TextButton.icon(
                onPressed: _openBuyNumber,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Buy number'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (nums.isEmpty && _primaryNumbers(data.numbers).isEmpty)
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
                  children: nums.map((n) => SizedBox(width: cardW, child: _prodCard(data, n))).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _prodCard(NumbersData data, Map<String, dynamic> n) {
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

    final attachBusy = ref.watch(numbersAttachBusyProvider);
    final isAttaching = attachBusy[numberId] == true;

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
            value: data.profiles.any((p) => _safeStr(p['profile_id']) == attachedProfileId) ? attachedProfileId : '',
            items: [
              const DropdownMenuItem(value: '', child: Text('— Not attached —')),
              ...data.profiles.map((p) {
                final id = _safeStr(p['profile_id']);
                final name = _safeStr(p['profile_name']).isEmpty ? 'Unnamed agent' : _safeStr(p['profile_name']);
                return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
              }),
            ],
            onChanged: isAttaching
                ? null
                : (v) {
                    final id = (v ?? '').trim();
                    _attachNumberToProfile(data, numberId: numberId, profileId: id);
                  },
            decoration: InputDecoration(
              isDense: true,
              hintText: attachedProfileName.isEmpty ? '—' : attachedProfileName,
            ),
          ),
          if (isAttaching) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(minHeight: 3, color: Theme.of(context).colorScheme.primary, backgroundColor: NeyvoColors.bgBase),
          ],
        ],
      ),
    );
  }

  Future<void> _attachNumberToProfile(
    NumbersData data, {
    required String numberId,
    required String profileId,
  }) async {
    if (numberId.isEmpty) return;
    ref.read(numbersAttachBusyProvider.notifier).setForNumber(numberId, true);
    try {
      if (profileId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Detach is not available yet.')),
          );
        }
      } else {
        try {
          await ref.read(numbersNotifierProvider.notifier).attachProfileToNumber(
                profileId: profileId,
                phoneNumberId: numberId,
                vapiPhoneNumberId: numberId,
                forceMove: false,
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attached')));
          }
        } on ApiException catch (e) {
          if (e.statusCode == 409 && e.payload is Map && mounted) {
            final payload = e.payload as Map<dynamic, dynamic>;
            final inUseBy = payload['in_use_by'];
            final currentName = inUseBy is Map
                ? ((inUseBy['profile_name'] ?? inUseBy['profile_id']) ?? 'Another operator').toString()
                : 'Another operator';
            final selectedProfileName = data.profiles
                .cast<Map<String, dynamic>>()
                .where((p) => (p['profile_id'] ?? p['id']) == profileId)
                .map((p) => (p['profile_name'] ?? p['name'] ?? profileId).toString())
                .firstOrNull ?? profileId;
            final moveAnyway = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Number already in use'),
                content: Text(
                  'This number is in use by "$currentName". Move it to "$selectedProfileName" anyway?',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Move here')),
                ],
              ),
            );
            if (moveAnyway == true && mounted) {
              await ref.read(numbersNotifierProvider.notifier).attachProfileToNumber(
                    profileId: profileId,
                    phoneNumberId: numberId,
                    vapiPhoneNumberId: numberId,
                    forceMove: true,
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Number moved.')));
              }
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) ref.read(numbersAttachBusyProvider.notifier).setForNumber(numberId, false);
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
        final res = await ref.read(numbersNotifierProvider.notifier).searchNumbersForPurchase(
          country: 'US',
          type: type,
          limit: 20,
          areaCode: areaCodeCtrl.text.trim().isEmpty ? null : areaCodeCtrl.text.trim(),
          voiceEnabled: true,
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
        await ref.read(numbersNotifierProvider.notifier).purchaseNumberForOrg(
          phoneNumber: num,
          friendlyName: nameCtrl.text.trim().isEmpty ? 'Production Line' : nameCtrl.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Number purchased')));
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
