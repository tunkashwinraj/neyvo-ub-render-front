// lib/screens/phone_number_detail_page.dart
// "Who answers this number?" — simple inbound handling config.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/phone_number_routing_provider.dart';
import '../theme/neyvo_theme.dart';

class PhoneNumberDetailPage extends ConsumerStatefulWidget {
  const PhoneNumberDetailPage({
    super.key,
    required this.numberId,
    required this.number,
  });

  final String numberId;
  final Map<String, dynamic> number;

  @override
  ConsumerState<PhoneNumberDetailPage> createState() => _PhoneNumberDetailPageState();
}

class _PhoneNumberDetailPageState extends ConsumerState<PhoneNumberDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(phoneNumberRoutingCtrlProvider(widget.numberId).notifier).load();
    });
  }

  Future<void> _save() async {
    await ref.read(phoneNumberRoutingCtrlProvider(widget.numberId).notifier).save();
    if (!mounted) return;
    final ui = ref.read(phoneNumberRoutingCtrlProvider(widget.numberId));
    if (ui.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Routing updated'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  static String _formatPhone(String? p) {
    if (p == null || p.isEmpty) {
      return p ?? '';
    }
    final digits = p.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 11 && digits.startsWith('1')) {
      final area = digits.substring(1, 4);
      final mid = digits.substring(4, 7);
      final last = digits.substring(7);
      return '+1 ($area) $mid-$last';
    }
    return p;
  }

  List<DropdownMenuItem<String>> _profileItems(PhoneNumberRoutingUiState ui) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('— None —')),
    ];
    for (final p in ui.profiles) {
      final id = (p['profile_id'] ?? '').toString();
      final name = (p['profile_name'] ?? 'Unnamed').toString();
      if (id.isNotEmpty) {
        items.add(DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis)));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(phoneNumberRoutingCtrlProvider(widget.numberId));
    final ctrl = ref.read(phoneNumberRoutingCtrlProvider(widget.numberId).notifier);

    final rawPhone = widget.number['phone_number']?.toString() ?? '';
    final phone = _formatPhone(rawPhone);
    final label = widget.number['friendly_name']?.toString() ?? '';
    final status = (widget.number['status'] ?? 'active').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Number settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ui.loading
          ? const Center(child: CircularProgressIndicator(color: NeyvoColors.teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(phone, style: NeyvoTextStyles.title),
                      if (label.isNotEmpty) Text(label, style: NeyvoTextStyles.body),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: NeyvoColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(status, style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.success)),
                      ),
                      const SizedBox(height: 24),
                      Text('Who answers this number?', style: NeyvoTextStyles.heading),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Simple business routing'),
                            selected: ui.routingPreset == 'simple',
                            onSelected: (v) {
                              if (!v) {
                                return;
                              }
                              ctrl.setRoutingPreset('simple');
                              ctrl.applySimplePreset();
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Custom (advanced)'),
                            selected: ui.routingPreset == 'custom',
                            onSelected: (v) {
                              if (!v) {
                                return;
                              }
                              ctrl.setRoutingPreset('custom');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _radio(ui, ctrl, 'single', 'Single agent', 'One agent handles all calls'),
                      _radio(ui, ctrl, 'silent_intent', 'Smart routing (recommended)',
                          'Route by intent from first sentence'),
                      const SizedBox(height: 16),
                      if (ui.mode == 'single') ...[
                        _dropdown(ui, 'Choose agent', ui.defaultProfileId, _profileItems(ui),
                            (v) => ctrl.setDefaultProfileId(v ?? '')),
                      ] else ...[
                        _dropdown(ui, 'Default agent', ui.defaultProfileId, _profileItems(ui),
                            (v) => ctrl.setDefaultProfileId(v ?? '')),
                        const SizedBox(height: 12),
                        if (ui.routingPreset == 'custom') ...[
                          Text('Intent mapping', style: NeyvoTextStyles.label),
                          const SizedBox(height: 4),
                          _intentDropdown(ui, 'Sales', ui.intentMap['sales'] ?? '', _profileItems(ui),
                              (v) => ctrl.setIntent('sales', v ?? '')),
                          _intentDropdown(ui, 'Support', ui.intentMap['support'] ?? '', _profileItems(ui),
                              (v) => ctrl.setIntent('support', v ?? '')),
                          _intentDropdown(ui, 'Booking', ui.intentMap['booking'] ?? '', _profileItems(ui),
                              (v) => ctrl.setIntent('booking', v ?? '')),
                          _intentDropdown(ui, 'Billing', ui.intentMap['billing'] ?? '', _profileItems(ui),
                              (v) => ctrl.setIntent('billing', v ?? '')),
                          const SizedBox(height: 12),
                        ],
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: NeyvoColors.bgBase,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: NeyvoColors.borderDefault),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'We listen to the first sentence of the call and automatically route to the right agent based on intent (Sales, Support, Booking, Billing).',
                                style: NeyvoTextStyles.body.copyWith(fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Example: “I want to book” → Booking agent\n'
                                'Example: “I need help with my order” → Support agent',
                                style: NeyvoTextStyles.micro,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ExpansionTile(
                          title: Text('Advanced', style: NeyvoTextStyles.label),
                          initiallyExpanded: ui.advancedExpanded,
                          onExpansionChanged: ctrl.setAdvancedExpanded,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Confidence threshold', style: NeyvoTextStyles.label),
                                  Slider(
                                    value: ui.confidenceThreshold,
                                    min: 0.5,
                                    max: 0.95,
                                    divisions: 9,
                                    label: ui.confidenceThreshold.toStringAsFixed(2),
                                    onChanged: ctrl.setConfidenceThreshold,
                                  ),
                                  Text(
                                    'Higher = fewer unsure routes. Lower = more flexibility.',
                                    style: NeyvoTextStyles.micro,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (ui.error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: NeyvoColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(ui.error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: ui.saving ? null : () => _showTestRoutingDialog(),
                            child: const Text('Test routing'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: ui.saving ? null : _save,
                            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                            child: ui.saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Save'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Recent routed calls', style: NeyvoTextStyles.label),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: NeyvoColors.bgBase,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: NeyvoColors.borderDefault),
                        ),
                        child: Text(
                          'No recent routed calls yet.',
                          style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _radio(
    PhoneNumberRoutingUiState ui,
    PhoneNumberRoutingCtrl ctrl,
    String value,
    String title,
    String subtitle,
  ) {
    final selected = ui.mode == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => ctrl.setMode(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? NeyvoColors.teal.withOpacity(0.1) : NeyvoColors.bgBase,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? NeyvoColors.teal : NeyvoColors.borderDefault,
            ),
          ),
          child: Row(
            children: [
              Radio<String>(
                value: value,
                groupValue: ui.mode,
                onChanged: (v) => ctrl.setMode(v ?? value),
                activeColor: NeyvoColors.teal,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: NeyvoTextStyles.bodyPrimary),
                    Text(subtitle, style: NeyvoTextStyles.micro),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown(
    PhoneNumberRoutingUiState ui,
    String label,
    String value,
    List<DropdownMenuItem<String>> items,
    void Function(String?) onChanged,
  ) {
    final valid = ui.profiles.any((p) => (p['profile_id'] ?? '').toString() == value);
    final v = valid ? value : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: NeyvoTextStyles.label),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: v,
            items: items,
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _intentDropdown(
    PhoneNumberRoutingUiState ui,
    String label,
    String value,
    List<DropdownMenuItem<String>> items,
    void Function(String?) onChanged,
  ) {
    final valid = ui.profiles.any((p) => (p['profile_id'] ?? '').toString() == value);
    final v = valid ? value : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        value: v,
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  void _showTestRoutingDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Test routing'),
        content: const Text(
          'Call this number and say something like "I want to book an appointment" or "I have a billing question" to test how calls are routed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
