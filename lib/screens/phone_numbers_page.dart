// lib/screens/phone_numbers_page.dart
// Neyvo Pulse – Outbound number management: buy, roles, warm-up, daily limits.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../neyvo_pulse_api.dart';
import '../api/spearia_api.dart';
import '../theme/spearia_theme.dart';

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
  final _linkE164Controller = TextEditingController();
  final _linkNumberIdController = TextEditingController();
  final _linkFriendlyNameController = TextEditingController();
  bool _linkLoading = false;
  bool _linkExpanded = false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await NeyvoPulseApi.listNumbers();
      if (mounted) {
        setState(() {
          _data = res;
          _loading = false;
        });
      }
      // Load account label so user can confirm which account they're viewing
      try {
        final accountRes = await NeyvoPulseApi.getAccountInfo();
        if (mounted && accountRes['ok'] == true) {
          setState(() {
            _accountIdDisplay = accountRes['account_id']?.toString();
            _accountName = (accountRes['account_name'] as String?)?.trim();
            if (_accountName != null && _accountName!.isEmpty) _accountName = null;
          });
        }
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : e.toString();
          _loading = false;
        });
      }
    }
  }

  bool get _hasUnregisteredFreecaller {
    final numbers = _data?['numbers'] as List? ?? [];
    return numbers.any((n) => (n['registered_freecaller'] as bool? ?? false) == false);
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
            Text('Loading numbers…', style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textMuted)),
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

    final numbers = (_data?['numbers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalNumbers = (_data?['total_numbers'] as num?)?.toInt() ?? numbers.length;
    final totalDailyCapacity = (_data?['total_daily_capacity'] as num?)?.toInt() ?? 0;
    final monthlyCost = _data?['monthly_number_cost']?.toString() ?? '\$0.00';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        children: [
          // Freecaller banner
          if (_hasUnregisteredFreecaller) _buildFreecallerBanner(),
          Text('Phone Numbers', style: SpeariaType.headlineLarge),
          const SizedBox(height: 4),
          Text(
            'Manage Twilio numbers for outbound campaigns. Daily limits protect your number reputation.',
            style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
          ),
          if (_accountIdDisplay != null || _accountName != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (_accountName != null && _accountName!.isNotEmpty) _accountName,
                if (_accountIdDisplay != null && _accountIdDisplay!.isNotEmpty) 'ID: $_accountIdDisplay',
              ].join(' · '),
              style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted),
            ),
          ],
          const SizedBox(height: SpeariaSpacing.xl),
          // Overview bar
          _buildOverviewBar(
            totalNumbers: totalNumbers,
            totalDailyCapacity: totalDailyCapacity,
            monthlyCost: monthlyCost,
          ),
          const SizedBox(height: SpeariaSpacing.lg),
          // Number cards or empty state
          if (numbers.isEmpty)
            _buildEmptyState()
          else
            ...numbers.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: SpeariaSpacing.md),
                  child: _NumberCard(
                    number: n,
                    onUpdated: _load,
                    formatPhone: _formatPhone,
                  ),
                )),
          const SizedBox(height: SpeariaSpacing.lg),
          // Warm-up explanation
          _buildWarmUpPanel(),
        ],
      ),
    );
  }

  Widget _buildFreecallerBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: SpeariaSpacing.lg),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SpeariaAura.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpeariaAura.warning.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: SpeariaAura.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Enable Neyvo Shield in Add-ons for spam protection on your numbers.',
              style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textPrimary),
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
        side: BorderSide(color: SpeariaAura.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$totalNumbers number${totalNumbers == 1 ? '' : 's'}', style: SpeariaType.titleMedium),
                  Text('Total numbers', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$totalDailyCapacity/day', style: SpeariaType.titleMedium),
                  Text('Daily capacity', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(monthlyCost, style: SpeariaType.titleMedium),
                  Text('Monthly cost', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
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
            side: BorderSide(color: SpeariaAura.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(SpeariaSpacing.xl * 2),
            child: Column(
              children: [
                Icon(Icons.phone_in_talk_outlined, size: 48, color: SpeariaAura.textMuted),
                const SizedBox(height: 16),
                Text(
                  "You don't have any phone numbers yet.",
                  style: SpeariaType.titleMedium.copyWith(color: SpeariaAura.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Buy a new number or link an existing one (e.g. from VAPI or a campaign).',
                  style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pull down to refresh after linking.',
                  style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _openBuyNumberFlow(context),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Buy New Number'),
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
            side: BorderSide(color: SpeariaAura.border),
          ),
          child: ExpansionTile(
            initiallyExpanded: _linkExpanded,
            onExpansionChanged: (v) => setState(() => _linkExpanded = v),
            title: Text('Link existing number', style: SpeariaType.titleMedium),
            subtitle: Text('Have a number in VAPI or a campaign? Link it so it appears here.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted)),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Phone number (E.164)', style: SpeariaType.labelLarge),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _linkE164Controller,
                      decoration: const InputDecoration(hintText: 'e.g. +12296006675', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Text('Phone number ID (VAPI / Twilio)', style: SpeariaType.labelLarge),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _linkNumberIdController,
                      decoration: const InputDecoration(hintText: 'e.g. f59a5394-59dd-489b-999a-5c1ebec6f9dd', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Text('Friendly name (optional)', style: SpeariaType.labelLarge),
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Number linked. Refreshing.')));
          _load();
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

  Widget _buildWarmUpPanel() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: SpeariaAura.border),
      ),
      child: ExpansionTile(
        title: Text(
          'Why are there daily limits?',
          style: SpeariaType.titleMedium.copyWith(fontWeight: FontWeight.w600),
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
                  style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
                ),
                const SizedBox(height: 12),
                Text(
                  'Neyvo automatically warms up every new number over 4 weeks, gradually increasing your daily limit from 40 → 80 → 120 → 140 reaches/day. This protects your number\'s reputation so your reaches get answered.',
                  style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
                ),
                const SizedBox(height: 12),
                Text(
                  'To speed things up, add more numbers — each one runs its own limit independently.',
                  style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
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
    backgroundColor: SpeariaAura.surface,
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

class _NumberCard extends StatefulWidget {
  final Map<String, dynamic> number;
  final VoidCallback onUpdated;
  final String Function(String?) formatPhone;

  const _NumberCard({required this.number, required this.onUpdated, required this.formatPhone});

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
    final numberId = n['number_id']?.toString() ?? '';
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: SpeariaAura.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_outlined, color: SpeariaAura.primary, size: 22),
                const SizedBox(width: 8),
                Text(phoneDisplay, style: SpeariaType.titleMedium.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPrimary ? SpeariaAura.primary.withOpacity(0.15) : SpeariaAura.bgDark,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isPrimary ? SpeariaAura.primary : SpeariaAura.border),
                  ),
                  child: Text(
                    isPrimary ? 'PRIMARY' : 'CAMPAIGN',
                    style: SpeariaType.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isPrimary ? SpeariaAura.primary : SpeariaAura.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'active' ? SpeariaAura.statusActive.withOpacity(0.15)
                        : status == 'warming' ? SpeariaAura.warning.withOpacity(0.15)
                        : SpeariaAura.bgDark,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: SpeariaAura.border),
                  ),
                  child: Text(
                    status == 'active' ? 'Active' : status == 'warming' ? 'Warming' : status,
                    style: SpeariaType.labelSmall.copyWith(color: SpeariaAura.textSecondary),
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
                      style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary)),
                  IconButton(
                    icon: Icon(Icons.edit, size: 18, color: SpeariaAura.iconMuted),
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
                      Icon(Icons.check_circle, size: 18, color: SpeariaAura.success),
                      const SizedBox(width: 6),
                      Text('Fully Warmed ✓', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.success)),
                    ],
                  )
                else
                  Text(
                    'Week $warmUpWeek of 4 — $dailyLimit calls/day',
                    style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted),
                  ),
                const SizedBox(width: 24),
                Text(
                  '$callsToday / $dailyLimit calls used today',
                  style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Freecaller
            if (!registeredFreecaller)
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: SpeariaAura.warning),
                  const SizedBox(width: 6),
                  Text(
                    'Not registered — higher spam risk',
                    style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.warning),
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
                  Icon(Icons.check_circle, size: 18, color: SpeariaAura.success),
                  const SizedBox(width: 6),
                  Text('Registered with carrier networks', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.success)),
                ],
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (!isPrimary)
                  TextButton(
                    onPressed: () => _setPrimary(numberId),
                    child: const Text('Set as Primary'),
                  ),
                OutlinedButton(
                  onPressed: () => _confirmRelease(context, numberId, phoneDisplay),
                  child: const Text('Release'),
                ),
              ],
            ),
          ],
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
      await NeyvoPulseApi.updateNumber(numberId, role: 'primary');
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

  void _confirmRelease(BuildContext context, String numberId, String phone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release number?'),
        content: Text('Release $phone from your account? You will stop being charged and the number will be released from Twilio.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SpeariaAura.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await NeyvoPulseApi.releaseNumber(numberId);
                widget.onUpdated();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Release'),
          ),
        ],
      ),
    );
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
  String _areaCode = '';
  bool _searching = false;
  List<Map<String, dynamic>> _available = [];
  String? _selectedPhone;
  String _friendlyName = 'Campaign Line';
  final _friendlyNameController = TextEditingController(text: 'Campaign Line');
  String _role = 'campaign';
  bool _purchasing = false;
  String? _purchaseError;

  @override
  void initState() {
    super.initState();
    _friendlyNameController.addListener(() => setState(() => _friendlyName = _friendlyNameController.text));
  }

  @override
  void dispose() {
    _friendlyNameController.dispose();
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

  Future<void> _search() async {
    if (_areaCode.length != 3) return;
    setState(() {
      _searching = true;
      _available = [];
    });
    try {
      final res = await NeyvoPulseApi.searchNumbers(areaCode: _areaCode);
      final list = (res['available'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() {
        _searching = false;
        _available = list;
      });
    } catch (e) {
      if (mounted) setState(() {
        _searching = false;
        _available = [];
      });
    }
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
                FilledButton(
                  onPressed: _areaCode.length == 3 && !_searching ? _search : null,
                  child: _searching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Search'),
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
        Text('Enter area code (3 digits)', style: SpeariaType.titleMedium),
        const SizedBox(height: 8),
        TextField(
          keyboardType: TextInputType.number,
          maxLength: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. 585',
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _areaCode = v.replaceAll(RegExp(r'\D'), '').substring(0, v.replaceAll(RegExp(r'\D'), '').length.clamp(0, 3))),
        ),
        const SizedBox(height: 16),
        if (_available.isEmpty && !_searching)
          Text('Results will appear here after search.', style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted))
        else if (_available.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else
          ..._available.map((a) {
            final p = a['phone_number']?.toString() ?? '';
            final friendly = a['friendly_name']?.toString() ?? _formatPhone(p);
            final locality = a['locality']?.toString() ?? '';
            final region = a['region']?.toString() ?? '';
            final selected = _selectedPhone == p;
            return ListTile(
              title: Text(friendly),
              subtitle: Text(locality.isNotEmpty ? '$locality, $region' : p),
              trailing: selected ? const Icon(Icons.check_circle, color: SpeariaAura.primary) : null,
              selected: selected,
              onTap: () => setState(() => _selectedPhone = p),
            );
          }),
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
        Text('Friendly name', style: SpeariaType.titleMedium),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            hintText: 'e.g. Campaign Line 2',
            border: OutlineInputBorder(),
          ),
          controller: _friendlyNameController,
        ),
        const SizedBox(height: 16),
        Text('Role', style: SpeariaType.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'primary', label: Text('Primary'), icon: Icon(Icons.star_outline, size: 18)),
            ButtonSegment(value: 'campaign', label: Text('Campaign'), icon: Icon(Icons.campaign_outlined, size: 18)),
          ],
          selected: {_role},
          onSelectionChanged: (s) => setState(() => _role = s.first),
        ),
        const SizedBox(height: 8),
        Text(
          'Primary = your recognized school number. Campaign = extra capacity for faster outreach.',
          style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted),
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
            decoration: BoxDecoration(color: SpeariaAura.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(_purchaseError!, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.error)),
          ),
          const SizedBox(height: 16),
        ],
        _row('Number', _formatPhone(_selectedPhone)),
        _row('Friendly name', name),
        _row('Role', _role),
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
          SizedBox(width: 140, child: Text(label, style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted))),
          Expanded(child: Text(value, style: SpeariaType.bodyMedium)),
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
        role: _role,
      );
      if (mounted) {
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _purchasing = false;
          _purchaseError = e is ApiException ? e.message : e.toString();
        });
      }
    }
  }
}
