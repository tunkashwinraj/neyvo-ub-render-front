// lib/screens/phone_numbers_page.dart
// Neyvo Pulse – Outbound number management: buy, link, warm-up, daily limits.
// Numbers from GET /api/numbers merged with locally stored linked numbers so linked numbers always appear.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';
import '../features/business_intelligence/routing_api_service.dart';
import '../features/managed_profiles/managed_profile_api_service.dart';
import '../features/managed_profiles/profile_detail_page.dart';
import 'phone_number_detail_page.dart';

const String _kLinkedNumbersKey = 'neyvo_pulse_linked_numbers';

class PhoneNumbersPage extends StatefulWidget {
  const PhoneNumbersPage({super.key});

  @override
  State<PhoneNumbersPage> createState() => _PhoneNumbersPageState();
}

class _PhoneNumbersPageState extends State<PhoneNumbersPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _warmUpExpanded = false;
  String? _accountIdDisplay;
  String? _accountName;
  String? _primaryPhoneE164;
  String? _primaryPhoneNumberId;
  final _linkE164Controller = TextEditingController();
  final _linkNumberIdController = TextEditingController();
  final _linkFriendlyNameController = TextEditingController();
  bool _linkLoading = false;
  bool _linkExpanded = false;
  bool _devAddExpanded = false;
  final _devE164Controller = TextEditingController();
  final _devIdController = TextEditingController();
  final _devNameController = TextEditingController();

  static Future<List<Map<String, dynamic>>> _getLinkedNumbersFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kLinkedNumbersKey);
      if (json == null || json.isEmpty) return [];
      final list = jsonDecode(json) as List<dynamic>?;
      return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveLinkedNumberToStorage(Map<String, dynamic> number) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getLinkedNumbersFromStorage();
      final id = (number['id'] ?? number['phone_number_id'])?.toString() ?? '';
      final filtered = existing.where((n) => (n['id'] ?? n['phone_number_id'])?.toString() != id).toList();
      filtered.add(number);
      await prefs.setString(_kLinkedNumbersKey, jsonEncode(filtered));
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _primaryPhoneE164 = null;
      _primaryPhoneNumberId = null;
    });
    try {
      final accountRes = await NeyvoPulseApi.getAccountInfo();
      if (mounted && accountRes['ok'] == true) {
        setState(() {
          _accountIdDisplay = accountRes['account_id']?.toString();
          _accountName = (accountRes['account_name'] as String?)?.trim();
          if (_accountName != null && _accountName!.isEmpty) _accountName = null;
          _primaryPhoneE164 = (accountRes['primary_phone_e164'] ?? accountRes['primary_phone'])?.toString().trim();
          _primaryPhoneNumberId = (accountRes['primary_phone_number_id'] ?? accountRes['vapi_phone_number_id'])?.toString().trim();
        });
      }
      final res = await NeyvoPulseApi.listNumbers();
      final rawList = res['numbers'] as List? ?? res['items'] as List? ?? [];
      final apiNumbers = List<Map<String, dynamic>>.from(rawList.map((e) => Map<String, dynamic>.from(e as Map)));
      final linked = await _getLinkedNumbersFromStorage();
      final seenIds = <String>{};
      for (final n in apiNumbers) {
        final id = (n['id'] ?? n['phone_number_id'])?.toString() ?? '';
        if (id.isNotEmpty) seenIds.add(id);
      }
      for (final n in linked) {
        final id = (n['id'] ?? n['phone_number_id'])?.toString() ?? '';
        if (id.isNotEmpty && !seenIds.contains(id)) {
          apiNumbers.add(n);
          seenIds.add(id);
        }
      }
      res['numbers'] = apiNumbers;
      if (mounted) {
        setState(() {
          _data = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool get _hasUnregisteredFreecaller {
    final numbers = _data?['numbers'] as List? ?? [];
    return numbers.any((n) => (n['registered_freecaller'] as bool? ?? false) == false);
  }

  Future<void> _openRoutingSettings() async {
    Map<String, dynamic>? config;
    List<Map<String, dynamic>> profiles = [];
    String? loadError;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final modeController = ValueNotifier<String>('single');
        final defaultProfileController = ValueNotifier<String>('');
        final salesController = ValueNotifier<String>('');
        final supportController = ValueNotifier<String>('');
        final bookingController = ValueNotifier<String>('');
        final billingController = ValueNotifier<String>('');
        final thresholdCtrl = TextEditingController(text: '0.75');

        Future<void> loadData() async {
          try {
            final results = await Future.wait([
              RoutingApiService.getConfig(),
              ManagedProfileApiService.listProfiles(),
            ]);
            final res = results[0] as Map<String, dynamic>;
            final profRes = results[1] as Map<String, dynamic>;
            if (res['ok'] == true) {
              config = Map<String, dynamic>.from(res['config'] as Map? ?? {});
              modeController.value = (config!['mode'] as String? ?? 'single').toString();
              defaultProfileController.value = (config!['defaultProfileId'] ?? '').toString();
              final intentMap = Map<String, dynamic>.from(config!['intentMap'] as Map? ?? {});
              salesController.value = (intentMap['sales'] ?? '').toString();
              supportController.value = (intentMap['support'] ?? '').toString();
              bookingController.value = (intentMap['booking'] ?? '').toString();
              billingController.value = (intentMap['billing'] ?? '').toString();
              thresholdCtrl.text = (config!['confidenceThreshold'] ?? 0.75).toString();
            }
            final list = (profRes['profiles'] as List? ?? []).cast<dynamic>();
            profiles = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          } catch (e) {
            loadError = e.toString();
          }
        }

        List<DropdownMenuItem<String>> _profileDropdownItems() {
          final items = <DropdownMenuItem<String>>[
            const DropdownMenuItem(value: '', child: Text('— None —')),
          ];
          for (final p in profiles) {
            final id = (p['profile_id'] ?? '').toString();
            final name = (p['profile_name'] ?? 'Unnamed').toString();
            if (id.isNotEmpty) {
              items.add(DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis)));
            }
          }
          return items;
        }

        return StatefulBuilder(
          builder: (ctx, setState) {
            if (config == null && loadError == null) {
              loadData().then((_) {
                if (ctx.mounted) setState(() {});
              });
            }
            return AlertDialog(
              backgroundColor: NeyvoColors.bgBase,
              title: const Text('Routing & Answering Rules'),
              content: SizedBox(
                width: 440,
                child: config == null && loadError == null
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (loadError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  loadError!,
                                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.error),
                                ),
                              ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Mode', style: NeyvoTextStyles.label),
                            ),
                            const SizedBox(height: 4),
                            ValueListenableBuilder<String>(
                              valueListenable: modeController,
                              builder: (context, mode, _) {
                                return DropdownButtonFormField<String>(
                                  value: mode,
                                  items: const [
                                    DropdownMenuItem(value: 'single', child: Text('Single profile')),
                                    DropdownMenuItem(value: 'silent_intent', child: Text('Silent AI routing')),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    modeController.value = v;
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: NeyvoSpacing.md),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Default profile', style: NeyvoTextStyles.label),
                            ),
                            const SizedBox(height: 4),
                            ValueListenableBuilder<String>(
                              valueListenable: defaultProfileController,
                              builder: (context, val, _) {
                                final valid = profiles.any((p) => (p['profile_id'] ?? '').toString() == val);
                                final v = valid ? val : '';
                                return DropdownButtonFormField<String>(
                                  value: v,
                                  items: _profileDropdownItems(),
                                  onChanged: (nv) => defaultProfileController.value = nv ?? '',
                                );
                              },
                            ),
                            const SizedBox(height: NeyvoSpacing.md),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Intent → Profile', style: NeyvoTextStyles.label),
                            ),
                            const SizedBox(height: 4),
                            _intentDropdown('Sales', salesController, profiles),
                            _intentDropdown('Support', supportController, profiles),
                            _intentDropdown('Booking', bookingController, profiles),
                            _intentDropdown('Billing', billingController, profiles),
                            const SizedBox(height: NeyvoSpacing.md),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Confidence threshold', style: NeyvoTextStyles.label),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: thresholdCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: '0.75'),
                            ),
                          ],
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() => saving = true);
                          try {
                            final intentMap = <String, String>{};
                            if (salesController.value.isNotEmpty) intentMap['sales'] = salesController.value;
                            if (supportController.value.isNotEmpty) intentMap['support'] = supportController.value;
                            if (bookingController.value.isNotEmpty) intentMap['booking'] = bookingController.value;
                            if (billingController.value.isNotEmpty) intentMap['billing'] = billingController.value;
                            final body = <String, dynamic>{
                              'mode': modeController.value,
                              'defaultProfileId': defaultProfileController.value.trim(),
                              'intentMap': intentMap,
                            };
                            final t = double.tryParse(thresholdCtrl.text.trim());
                            if (t != null) body['confidenceThreshold'] = t;
                            await RoutingApiService.updateConfig(body);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Routing updated'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                          } catch (e) {
                            setState(() {
                              saving = false;
                              loadError = e.toString();
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _intentDropdown(
    String label,
    ValueNotifier<String> controller,
    List<Map<String, dynamic>> profiles,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ValueListenableBuilder<String>(
        valueListenable: controller,
        builder: (context, val, _) {
          final items = <DropdownMenuItem<String>>[
            const DropdownMenuItem(value: '', child: Text('— None —')),
          ];
          for (final p in profiles) {
            final id = (p['profile_id'] ?? '').toString();
            final name = (p['profile_name'] ?? 'Unnamed').toString();
            if (id.isNotEmpty) {
              items.add(DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis)));
            }
          }
          final valid = profiles.any((p) => (p['profile_id'] ?? '').toString() == val);
          final v = valid ? val : '';
          return DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: label),
            value: v,
            items: items,
            onChanged: (nv) => controller.value = nv ?? '',
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _linkE164Controller.dispose();
    _linkNumberIdController.dispose();
    _linkFriendlyNameController.dispose();
    _devE164Controller.dispose();
    _devIdController.dispose();
    _devNameController.dispose();
    super.dispose();
  }

  static String _formatPhone(String? p) {
    if (p == null || p.isEmpty) return p ?? '';
    final digits = p.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 11 && digits.startsWith('1')) {
      final area = digits.substring(1, 4);
      final mid = digits.substring(4, 7);
      final last = digits.substring(7);
      return '+1 ($area) $mid-$last';
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading numbers…', style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textMuted)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    List<Map<String, dynamic>> numbers = (_data?['numbers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (numbers.isEmpty && _primaryPhoneE164 != null && _primaryPhoneE164!.isNotEmpty) {
      numbers = [
        {
          'phone_number': _primaryPhoneE164,
          'phone_number_e164': _primaryPhoneE164,
          'id': _primaryPhoneNumberId ?? 'primary',
          'phone_number_id': _primaryPhoneNumberId,
          'friendly_name': 'Primary',
          'is_primary': true,
        },
      ];
    }
    final totalNumbers = (_data?['total_numbers'] as num?)?.toInt() ?? numbers.length;
    final totalDailyCapacity = (_data?['total_daily_capacity'] as num?)?.toInt() ?? 0;
    final monthlyCost = _data?['monthly_number_cost']?.toString() ?? '\$0.00';
    final displayTotal = numbers.isEmpty ? totalNumbers : numbers.length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        children: [
          // Freecaller banner
          if (_hasUnregisteredFreecaller) _buildFreecallerBanner(),
          Text('Phone Numbers', style: NeyvoType.headlineLarge.copyWith(color: NeyvoTheme.textPrimary)),
          const SizedBox(height: NeyvoSpacing.xs),
          Text(
            'Manage numbers for your agents.',
            style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
          ),
          const SizedBox(height: NeyvoSpacing.sm),
          Text(
            'Click a number to configure who answers it.',
            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
          ),
          if (_accountName != null || (_accountIdDisplay != null && _accountIdDisplay!.isNotEmpty && _accountIdDisplay!.length <= 20)) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (_accountName != null && _accountName!.isNotEmpty) _accountName,
                if (_accountIdDisplay != null && _accountIdDisplay!.isNotEmpty && _accountIdDisplay!.length <= 20)
                  'ID: $_accountIdDisplay',
              ].join(' · '),
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
            ),
          ],
          const SizedBox(height: NeyvoSpacing.xl),
          _buildOverviewBar(
            totalNumbers: displayTotal,
            totalDailyCapacity: totalDailyCapacity,
            monthlyCost: monthlyCost,
          ),
          const SizedBox(height: NeyvoSpacing.lg),
          if (numbers.isEmpty && (_primaryPhoneE164 == null || _primaryPhoneE164!.isEmpty))
            _buildEmptyState()
          else
            ...numbers.map((n) {
                  final numberId = (n['id'] ?? n['phone_number_id'])?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: NeyvoSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NumberCard(
                          number: n,
                          onUpdated: _load,
                          formatPhone: _formatPhone,
                          onOpenDetail: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PhoneNumberDetailPage(
                                numberId: numberId,
                                number: n,
                              ),
                            ),
                          ),
                        ),
                        if (numberId.isNotEmpty) _CapacityBar(numberId: numberId),
                      ],
                    ),
                  );
                }),
          const SizedBox(height: NeyvoSpacing.lg),
          // Warm-up explanation
          _buildWarmUpPanel(),
        ],
      ),
    );
  }

  Widget _buildDeveloperAddCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: NeyvoTheme.border),
      ),
      child: ExpansionTile(
        initiallyExpanded: _devAddExpanded,
        onExpansionChanged: (v) => setState(() => _devAddExpanded = v),
        title: Text('Developer: Add number to list (no API)', style: NeyvoType.titleMedium),
        subtitle: Text('If Link number does not show the number above, add it here. Saves locally so it appears in the list immediately.', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Phone number (E.164)', style: NeyvoType.labelLarge),
                const SizedBox(height: 4),
                TextField(
                  controller: _devE164Controller,
                  decoration: const InputDecoration(hintText: 'e.g. +17753629344', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Text('Phone number ID (VAPI / Twilio)', style: NeyvoType.labelLarge),
                const SizedBox(height: 4),
                TextField(
                  controller: _devIdController,
                  decoration: const InputDecoration(hintText: 'e.g. f81fcba5-52ed-4832-97a5-202cf74e9434', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Text('Friendly name (optional)', style: NeyvoType.labelLarge),
                const SizedBox(height: 4),
                TextField(
                  controller: _devNameController,
                  decoration: const InputDecoration(hintText: 'e.g. myfirst', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _devAddNumberToList,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add to list'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreecallerBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: NeyvoSpacing.lg),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NeyvoTheme.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NeyvoTheme.warning.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: NeyvoTheme.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Enable Neyvo Shield in Add-ons for spam protection on your numbers.',
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/pulse/addons'),
            child: const Text('Open Add-ons'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewBar({
    required int totalNumbers,
    required int totalDailyCapacity,
    required String monthlyCost,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: NeyvoTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NeyvoSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$totalNumbers number${totalNumbers == 1 ? '' : 's'}', style: NeyvoType.titleMedium),
                  Text('Total numbers', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$totalDailyCapacity/day', style: NeyvoType.titleMedium),
                  Text('Daily capacity', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(monthlyCost, style: NeyvoType.titleMedium),
                  Text('Monthly cost', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _openBuyNumberFlow(context),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Buy New Number'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: NeyvoTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(NeyvoSpacing.xl * 2),
            child: Column(
              children: [
                Icon(Icons.phone_in_talk_outlined, size: 48, color: NeyvoTheme.textMuted),
                const SizedBox(height: 16),
                Text(
                  'No numbers yet',
                  style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Get a new number in under a minute or connect your existing number.',
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pull down to refresh after linking.',
                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _openBuyNumberFlow(context),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Get a number (1 min)'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: NeyvoTheme.border),
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            onExpansionChanged: (v) => setState(() => _linkExpanded = v),
            title: Text('Connect existing number', style: NeyvoType.titleMedium),
            subtitle: Text(
              'Have a number in Firestore or VAPI? Paste E.164 and Phone number ID below and click Link to show it here.',
              style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Phone number (E.164)', style: NeyvoType.labelLarge),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _linkE164Controller,
                      decoration: const InputDecoration(hintText: 'e.g. +12296006675', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Text('Phone number ID (VAPI / Twilio)', style: NeyvoType.labelLarge),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _linkNumberIdController,
                      decoration: const InputDecoration(hintText: 'e.g. f59a5394-59dd-489b-999a-5c1ebec6f9dd', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Text('Friendly name (optional)', style: NeyvoType.labelLarge),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _linkFriendlyNameController,
                      decoration: const InputDecoration(hintText: 'e.g. Primary', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _linkLoading ? null : _submitLinkNumber,
                      icon: _linkLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link, size: 18),
                      label: Text(_linkLoading ? 'Linking…' : 'Link number'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submitLinkNumber() async {
    final e164 = _linkE164Controller.text.trim();
    final numberId = _linkNumberIdController.text.trim();
    if (e164.isEmpty || numberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone number (E.164) and Phone number ID')));
      return;
    }
    setState(() => _linkLoading = true);
    try {
      final res = await NeyvoPulseApi.attachNumber(
        phoneNumberE164: e164,
        phoneNumberId: numberId,
        friendlyName: _linkFriendlyNameController.text.trim().isEmpty ? null : _linkFriendlyNameController.text.trim(),
      );
      if (mounted) {
        setState(() => _linkLoading = false);
        if (res['ok'] == true) {
          await _saveLinkedNumberToStorage({
            'id': numberId,
            'phone_number_id': numberId,
            'phone_number': e164,
            'phone_number_e164': e164,
            'friendly_name': _linkFriendlyNameController.text.trim().isEmpty ? null : _linkFriendlyNameController.text.trim(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Number linked. Refreshing list.')),
            );
            _load();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error']?.toString() ?? 'Failed')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _linkLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _devAddNumberToList() async {
    final e164 = _devE164Controller.text.trim();
    final id = _devIdController.text.trim();
    if (e164.isEmpty || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter E.164 and Phone number ID')));
      return;
    }
    try {
      final messenger = ScaffoldMessenger.of(context);
      final res = await NeyvoPulseApi.attachNumber(
        phoneNumberE164: e164,
        phoneNumberId: id,
        friendlyName: _devNameController.text.trim().isEmpty ? null : _devNameController.text.trim(),
      );
      if (!mounted) return;
      if (res['ok'] == true) {
        await _saveLinkedNumberToStorage({
          'id': id,
          'phone_number_id': id,
          'phone_number': e164,
          'phone_number_e164': e164,
          'friendly_name': _devNameController.text.trim().isNotEmpty ? _devNameController.text.trim() : null,
        });
        messenger.showSnackBar(const SnackBar(content: Text('Number linked via API. Refreshing.')));
        _load();
      } else {
        messenger.showSnackBar(SnackBar(content: Text(res['error']?.toString() ?? 'Failed')));
      }
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildWarmUpPanel() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: NeyvoTheme.border),
      ),
      child: ExpansionTile(
        title: Text(
          'Why are there daily limits?',
          style: NeyvoType.titleMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        initiallyExpanded: _warmUpExpanded,
        onExpansionChanged: (v) => setState(() => _warmUpExpanded = v),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phone carriers monitor reach volume per number. New numbers that reach too many people too fast get labeled as spam — and once flagged, contacts see "Spam Risk" before answering.',
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Text(
                  'Neyvo automatically warms up every new number over 4 weeks, gradually increasing your daily limit from 40 → 80 → 120 → 140 reaches/day. This protects your number\'s reputation so your reaches get answered.',
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Text(
                  'To speed things up, add more numbers — each one runs its own limit independently.',
                  style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openBuyNumberFlow(BuildContext context) {
    showBuyNumberModal(context, onDone: _load);
  }
}

/// Call from anywhere to open the Buy Number flow modal.
void showBuyNumberModal(BuildContext context, {VoidCallback? onDone}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: NeyvoTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 1,
      expand: false,
      builder: (_, scrollController) => _BuyNumberFlow(
        onDone: () {
          Navigator.of(ctx).pop();
          onDone?.call();
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
}

class _CapacityBar extends StatelessWidget {
  final String numberId;

  const _CapacityBar({required this.numberId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: NeyvoPulseApi.getNumberCapacity(numberId),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final d = snap.data!;
        final used = (d['used_today'] as num?)?.toInt() ?? 0;
        final limit = (d['daily_limit'] as num?)?.toInt() ?? 150;
        final warning = d['warning'] as bool? ?? false;
        if (limit <= 0) return const SizedBox.shrink();
        final pct = (used / limit).clamp(0.0, 1.0);
        Color fillColor = NeyvoTheme.teal;
        if (pct >= 0.95) fillColor = NeyvoTheme.error;
        else if (pct >= 0.8 || warning) fillColor = NeyvoTheme.warning;
        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: NeyvoColors.bgBase,
                      valueColor: AlwaysStoppedAnimation<Color>(fillColor),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$used/$limit calls today',
                    style: NeyvoTextStyles.micro.copyWith(color: NeyvoTheme.textMuted),
                  ),
                  if (warning) Icon(Icons.warning_amber, size: 14, color: NeyvoTheme.warning),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NumberCard extends StatefulWidget {
  final Map<String, dynamic> number;
  final VoidCallback onUpdated;
  final String Function(String?) formatPhone;
  final VoidCallback? onOpenDetail;

  const _NumberCard({
    required this.number,
    required this.onUpdated,
    required this.formatPhone,
    this.onOpenDetail,
  });

  @override
  State<_NumberCard> createState() => _NumberCardState();
}

class _NumberCardState extends State<_NumberCard> {
  bool _editingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.number['friendly_name']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.number;
    final numberId = (n['number_id'] ?? n['id'] ?? n['phone_number_id'])?.toString() ?? '';
    final rawPhone = n['phone_number']?.toString() ?? '';
    final phone = widget.formatPhone(rawPhone);
    final friendlyName = n['friendly_name']?.toString() ?? '';
    // Attached (org primary) numbers may have null/empty phone_number; show friendly_name or number_id
    final phoneDisplay = phone.trim().isNotEmpty
        ? phone
        : (friendlyName.trim().isNotEmpty ? friendlyName : (numberId.length >= 8 ? '${numberId.substring(0, 8)}…' : numberId));
    final role = (n['role']?.toString() ?? 'campaign').toLowerCase();
    final status = (n['status']?.toString() ?? 'active').toLowerCase();
    final warmUpWeek = (n['warm_up_week'] as num?)?.toInt() ?? 1;
    final dailyLimit = (n['daily_limit'] as num?)?.toInt() ?? 140;
    final callsToday = (n['calls_today'] as num?)?.toInt() ?? 0;
    final callsRemaining = (n['calls_remaining_today'] as num?)?.toInt() ?? 0;
    final registeredFreecaller = n['registered_freecaller'] as bool? ?? false;
    final isPrimary = role == 'primary';
    final attachedProfileId = n['attached_profile_id']?.toString();
    final attachedProfileName = n['attached_profile_name']?.toString();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: NeyvoTheme.border),
      ),
      child: InkWell(
        onTap: widget.onOpenDetail,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(NeyvoSpacing.lg),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_outlined, color: NeyvoTheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(phoneDisplay, style: NeyvoType.titleMedium.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPrimary ? NeyvoTheme.primary.withOpacity(0.15) : NeyvoTheme.bgCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isPrimary ? NeyvoTheme.primary : NeyvoTheme.border),
                  ),
                  child: Text(
                    isPrimary ? 'PRIMARY' : 'CAMPAIGN',
                    style: NeyvoType.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isPrimary ? NeyvoTheme.primary : NeyvoTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'active' ? NeyvoTheme.success.withOpacity(0.15)
                        : status == 'warming' ? NeyvoTheme.warning.withOpacity(0.15)
                        : NeyvoTheme.bgCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NeyvoTheme.border),
                  ),
                  child: Text(
                    status == 'active' ? 'Active' : status == 'warming' ? 'Warming' : status,
                    style: NeyvoType.labelSmall.copyWith(color: NeyvoTheme.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_editingName)
              Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        hintText: 'Friendly name',
                      ),
                      onSubmitted: (v) => _saveName(numberId, v),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () => _saveName(numberId, _nameController.text),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _editingName = false),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Text(friendlyName.isEmpty ? 'No name' : friendlyName,
                      style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary)),
                  IconButton(
                    icon: Icon(Icons.edit, size: 18, color: NeyvoTheme.textMuted),
                    onPressed: () => setState(() => _editingName = true),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            // Warm-up
            Row(
              children: [
                if (warmUpWeek >= 4)
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 18, color: NeyvoTheme.success),
                      const SizedBox(width: 6),
                      Text('Fully Warmed ✓', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.success)),
                    ],
                  )
                else
                  Text(
                    'Week $warmUpWeek of 4 — $dailyLimit calls/day',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                  ),
                const SizedBox(width: 24),
                Text(
                  '$callsToday / $dailyLimit calls used today',
                  style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Freecaller
            if (!registeredFreecaller)
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: NeyvoTheme.warning),
                  const SizedBox(width: 6),
                  Text(
                    'Not registered — higher spam risk',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.warning),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => _markRegistered(numberId),
                    child: const Text('Mark as Registered'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: NeyvoTheme.success),
                  const SizedBox(width: 6),
                  Text('Registered with carrier networks', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.success)),
                ],
              ),
            const SizedBox(height: 12),
            // Voice profile attachment
            if (attachedProfileId != null && attachedProfileId.isNotEmpty && attachedProfileName != null && attachedProfileName.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.record_voice_over, size: 18, color: NeyvoTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Voice Profile: $attachedProfileName',
                      style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textPrimary),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManagedProfileDetailPage(profileId: attachedProfileId),
                        ),
                      );
                    },
                    child: const Text(
                      'View Profile →',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(Icons.record_voice_over_outlined, size: 18, color: NeyvoTheme.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Not attached to any profile',
                      style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showAttachProfileSheet(n),
                    child: const Text(
                      'Attach to Profile →',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (!isPrimary)
              TextButton(
                onPressed: () => _setPrimary(numberId),
                child: const Text('Set as Primary'),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _saveName(String numberId, String name) async {
    setState(() => _editingName = false);
    try {
      await NeyvoPulseApi.updateNumber(numberId, friendlyName: name.trim().isEmpty ? null : name.trim());
      widget.onUpdated();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update name')));
    }
  }

  Future<void> _setPrimary(String numberId) async {
    try {
      final e164 = (widget.number['phone_number_e164'] ?? widget.number['phone_number'] ?? '').toString().trim();
      if (e164.isEmpty || !e164.startsWith('+')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing E.164 phone number.')));
        }
        return;
      }
      await NeyvoPulseApi.setOutboundPrimary(e164, phoneNumberE164: e164);
      widget.onUpdated();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to set primary')));
    }
  }

  Future<void> _markRegistered(String numberId) async {
    try {
      await NeyvoPulseApi.registerFreecaller(numberId);
      widget.onUpdated();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to mark registered')));
    }
  }

  Future<void> _showAttachProfileSheet(Map<String, dynamic> number) async {
    try {
      final profilesRes = await ManagedProfileApiService.listProfiles();
      final profilesList = (profilesRes['profiles'] as List?)?.cast<dynamic>() ?? [];
      if (!mounted) return;
      if (profilesList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No voice profiles yet. Go to Voice Profiles to create one.')),
        );
        return;
      }
      final numberId = (number['number_id'] ?? number['id'] ?? number['phone_number_id'])?.toString() ?? '';
      if (numberId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot attach this number – missing ID.')),
        );
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: NeyvoTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(NeyvoSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attach to Voice Profile',
                    style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
                  ),
                  const SizedBox(height: NeyvoSpacing.sm),
                  Text(
                    'Choose which managed profile should use this number.',
                    style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                  ),
                  const SizedBox(height: NeyvoSpacing.md),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: profilesList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = Map<String, dynamic>.from(profilesList[index] as Map);
                        final profileId = p['profile_id']?.toString() ?? '';
                        final name = p['profile_name']?.toString() ?? 'Voice Profile';
                        final industry = p['industry_id']?.toString() ?? '';
                        final status = p['status']?.toString() ?? '';
                        return ListTile(
                          title: Text(name, style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textPrimary)),
                          subtitle: Text(
                            [if (industry.isNotEmpty) industry, if (status.isNotEmpty) status].join(' · '),
                            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                          ),
                          onTap: () async {
                            Navigator.of(context).pop();
                            try {
                              await ManagedProfileApiService.attachPhoneNumber(
                                profileId: profileId,
                                phoneNumberId: numberId,
                                vapiPhoneNumberId: numberId,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Attached to $name')),
                                );
                                widget.onUpdated();
                              }
                            } catch (e) {
                              if (!mounted) return;
                              final msg = e.toString();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to attach number: $msg')),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profiles: $e')),
      );
    }
  }

}

// 3-step Buy Number flow: Search → Configure → Review & Purchase
class _BuyNumberFlow extends StatefulWidget {
  final VoidCallback onDone;
  final VoidCallback onCancel;

  const _BuyNumberFlow({required this.onDone, required this.onCancel});

  @override
  State<_BuyNumberFlow> createState() => _BuyNumberFlowState();
}

class _BuyNumberFlowState extends State<_BuyNumberFlow> {
  int _step = 0;
  bool _searching = false;
  List<Map<String, dynamic>> _available = [];
  String? _searchMessage;
  bool _suggestedShown = false;
  String? _selectedPhone;
  String _friendlyName = 'Campaign Line';
  final _friendlyNameController = TextEditingController(text: 'Campaign Line');
  String _role = 'campaign';
  bool _purchasing = false;
  String? _purchaseError;
  // Filters (user-controllable)
  String _filterCountry = 'US';
  String _filterType = 'local';
  final _filterAreaCodeController = TextEditingController();
  bool _filterVoice = true;
  bool _filterSms = false;
  bool _filterMms = false;
  int _filterLimit = 20;

  @override
  void initState() {
    super.initState();
    _friendlyNameController.addListener(() => setState(() => _friendlyName = _friendlyNameController.text));
    _loadAvailableNumbers();
  }

  @override
  void dispose() {
    _filterAreaCodeController.dispose();
    _friendlyNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableNumbers({bool suggestedOnly = false}) async {
    setState(() {
      _searching = true;
      _available = [];
      _searchMessage = null;
      _suggestedShown = false;
    });
    try {
      final res = await NeyvoPulseApi.searchNumbers(
        country: _filterCountry,
        type: suggestedOnly ? 'tollfree' : _filterType,
        limit: _filterLimit,
        areaCode: _filterAreaCodeController.text.trim().isEmpty ? null : _filterAreaCodeController.text.trim(),
        voiceEnabled: suggestedOnly ? true : _filterVoice,
        smsEnabled: suggestedOnly ? null : _filterSms,
        mmsEnabled: suggestedOnly ? null : _filterMms,
        includeSuggested: true,
      );
      final list = (res['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) {
        setState(() {
          _searching = false;
          _available = list;
          _searchMessage = res['message'] as String?;
          _suggestedShown = res['suggested'] == true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searching = false;
          _available = [];
          _searchMessage = e.toString();
        });
      }
    }
  }

  static String _formatPhone(String? p) {
    if (p == null || p.isEmpty) return p ?? '';
    final digits = p.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 11 && digits.startsWith('1')) {
      final area = digits.substring(1, 4);
      final mid = digits.substring(4, 7);
      final last = digits.substring(7);
      return '+1 ($area) $mid-$last';
    }
    return p;
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: Text(_step == 0 ? 'Search numbers' : _step == 1 ? 'Configure' : 'Review & purchase'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onCancel,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _step == 0 ? _buildStepSearch() : _step == 1 ? _buildStepConfigure() : _buildStepReview(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_step > 0)
                TextButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text('Back'),
                ),
              const SizedBox(width: 8),
              if (_step == 0) ...[
                TextButton.icon(
                  onPressed: _searching ? null : () => _loadAvailableNumbers(suggestedOnly: true),
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                  label: const Text('Suggested'),
                ),
                TextButton.icon(
                  onPressed: _searching ? null : () => _loadAvailableNumbers(),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search'),
                ),
                if (_selectedPhone != null) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => setState(() => _step = 1),
                    child: const Text('Continue'),
                  ),
                ],
              ] else if (_step == 1)
                FilledButton(
                  onPressed: () => setState(() => _step = 2),
                  child: const Text('Continue'),
                )
              else
                FilledButton(
                  onPressed: _purchasing ? null : _purchase,
                  child: _purchasing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Confirm Purchase'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Search & choose a number', style: NeyvoType.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Set filters below, then tap Search. Use Suggested for quick options. Tap a number to select.',
          style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted),
        ),
        const SizedBox(height: 16),
        // Filters
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: NeyvoTheme.border)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Filters', style: NeyvoType.labelLarge.copyWith(color: NeyvoTheme.textSecondary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterCountry,
                        decoration: const InputDecoration(labelText: 'Country', isDense: true, border: OutlineInputBorder()),
                        items: const [DropdownMenuItem(value: 'US', child: Text('US'))],
                        onChanged: (v) => setState(() => _filterCountry = v ?? 'US'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterType,
                        decoration: const InputDecoration(labelText: 'Type', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'local', child: Text('Local')),
                          DropdownMenuItem(value: 'mobile', child: Text('Mobile')),
                          DropdownMenuItem(value: 'tollfree', child: Text('Toll-Free')),
                        ],
                        onChanged: (v) => setState(() => _filterType = v ?? 'local'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _filterAreaCodeController,
                        keyboardType: TextInputType.number,
                        maxLength: 3,
                        decoration: const InputDecoration(
                          labelText: 'Area code (optional)',
                          hintText: 'e.g. 203',
                          counterText: '',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _filterLimit,
                        decoration: const InputDecoration(labelText: 'Limit', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 20, child: Text('20')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                        ],
                        onChanged: (v) => setState(() => _filterLimit = v ?? 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Capabilities (optional)', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Voice'),
                      selected: _filterVoice,
                      onSelected: (v) => setState(() => _filterVoice = v),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('SMS'),
                      selected: _filterSms,
                      onSelected: (v) => setState(() => _filterSms = v),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('MMS'),
                      selected: _filterMms,
                      onSelected: (v) => setState(() => _filterMms = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_searching && _available.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_searchMessage != null && _available.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_searchMessage!, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted)),
          )
        else if (_available.isEmpty)
          Text('Set filters and tap Search, or tap Suggested for numbers.', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted))
        else ...[
          if (_suggestedShown)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Suggested numbers (no match for your filters)', style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted, fontStyle: FontStyle.italic)),
            ),
          ..._available.map((a) {
            final e164 = a['e164']?.toString() ?? a['phone_number']?.toString() ?? '';
            final friendly = a['friendly']?.toString() ?? a['friendly_name']?.toString() ?? _formatPhone(e164);
            final locality = a['locality']?.toString() ?? '';
            final region = a['region']?.toString() ?? '';
            final numberType = a['number_type']?.toString() ?? '';
            final selected = _selectedPhone == e164;
            return ListTile(
              title: Text(friendly),
              subtitle: Text(locality.isNotEmpty ? '$locality, $region${numberType.isNotEmpty ? ' · $numberType' : ''}' : e164),
              trailing: selected ? const Icon(Icons.check_circle, color: NeyvoTheme.primary) : null,
              selected: selected,
              onTap: () => setState(() => _selectedPhone = e164),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildStepConfigure() {
    if (_friendlyNameController.text != _friendlyName && _friendlyName != 'Campaign Line') {
      _friendlyNameController.text = _friendlyName;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Friendly name', style: NeyvoType.titleMedium),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            hintText: 'e.g. Campaign Line 2',
            border: OutlineInputBorder(),
          ),
          controller: _friendlyNameController,
        ),
      ],
    );
  }

  Widget _buildStepReview() {
    final name = _friendlyNameController.text.trim().isEmpty ? 'Campaign Line' : _friendlyNameController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_purchaseError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: NeyvoTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(_purchaseError!, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.error)),
          ),
          const SizedBox(height: 16),
        ],
        _row('Number', _formatPhone(_selectedPhone)),
        _row('Friendly name', name),
        _row('Cost', '115 credits/month (\$1.15/month) — deducted from wallet'),
        _row('Starting daily limit', '40 calls/day (reaches 140/day after 4 weeks warm-up)'),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textMuted))),
          Expanded(child: Text(value, style: NeyvoType.bodyMedium)),
        ],
      ),
    );
  }

  Future<void> _purchase() async {
    if (_selectedPhone == null) return;
    setState(() {
      _purchasing = true;
      _purchaseError = null;
    });
    try {
      final name = _friendlyNameController.text.trim().isEmpty ? 'Campaign Line' : _friendlyNameController.text.trim();
      await NeyvoPulseApi.purchaseNumber(
        phoneNumber: _selectedPhone!,
        friendlyName: name,
      );
      if (mounted) {
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _purchasing = false;
          _purchaseError = e.toString();
        });
      }
    }
  }
}
