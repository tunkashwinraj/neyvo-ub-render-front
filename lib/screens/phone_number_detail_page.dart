// lib/screens/phone_number_detail_page.dart
// "Who answers this number?" — simple inbound handling config.

import 'package:flutter/material.dart';

import '../theme/neyvo_theme.dart';
import '../features/business_intelligence/routing_api_service.dart';
import '../features/managed_profiles/managed_profile_api_service.dart';

class PhoneNumberDetailPage extends StatefulWidget {
  const PhoneNumberDetailPage({
    super.key,
    required this.numberId,
    required this.number,
  });

  final String numberId;
  final Map<String, dynamic> number;

  @override
  State<PhoneNumberDetailPage> createState() => _PhoneNumberDetailPageState();
}

class _PhoneNumberDetailPageState extends State<PhoneNumberDetailPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _mode = 'single'; // single | silent_intent
  String _defaultProfileId = '';
  final Map<String, String> _intentMap = {};
  double _confidenceThreshold = 0.75;
  bool _advancedExpanded = false;

  List<Map<String, dynamic>> _profiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        RoutingApiService.getConfig(),
        ManagedProfileApiService.listProfiles(),
      ]);
      final configRes = results[0] as Map<String, dynamic>;
      final profRes = results[1] as Map<String, dynamic>;

      if (configRes['ok'] == true && configRes['config'] != null) {
        final config = Map<String, dynamic>.from(configRes['config'] as Map);
        setState(() {
          _mode = (config['mode'] as String? ?? 'single').toString();
          _defaultProfileId = (config['defaultProfileId'] ?? '').toString();
          final im = Map<String, dynamic>.from(config['intentMap'] as Map? ?? {});
          _intentMap['sales'] = (im['sales'] ?? '').toString();
          _intentMap['support'] = (im['support'] ?? '').toString();
          _intentMap['booking'] = (im['booking'] ?? '').toString();
          _intentMap['billing'] = (im['billing'] ?? '').toString();
          _confidenceThreshold = (config['confidenceThreshold'] as num?)?.toDouble() ?? 0.75;
        });
      }
      final list = (profRes['profiles'] as List?)?.cast<dynamic>() ?? [];
      setState(() {
        _profiles = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final intentMap = <String, String>{};
      for (final e in _intentMap.entries) {
        if (e.value.isNotEmpty) intentMap[e.key] = e.value;
      }
      await RoutingApiService.updateConfig({
        'mode': _mode,
        'defaultProfileId': _defaultProfileId.trim(),
        'intentMap': intentMap,
        'confidenceThreshold': _confidenceThreshold,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Routing updated'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() => _saving = false);
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

  List<DropdownMenuItem<String>> _profileItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('— None —')),
    ];
    for (final p in _profiles) {
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: NeyvoColors.teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Text(phone, style: NeyvoTextStyles.title),
                      if (label.isNotEmpty)
                        Text(label, style: NeyvoTextStyles.body),
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

                      // Who answers this number?
                      Text('Who answers this number?', style: NeyvoTextStyles.heading),
                      const SizedBox(height: 12),
                      _radio('single', 'Single agent', 'One agent handles all calls'),
                      _radio('silent_intent', 'Smart routing (recommended)', 'Route by intent from first sentence'),
                      const SizedBox(height: 16),

                      if (_mode == 'single') ...[
                        _dropdown('Choose agent', _defaultProfileId, (v) => setState(() => _defaultProfileId = v ?? '')),
                      ] else ...[
                        _dropdown('Default agent', _defaultProfileId, (v) => setState(() => _defaultProfileId = v ?? '')),
                        const SizedBox(height: 12),
                        Text('Intent mapping', style: NeyvoTextStyles.label),
                        const SizedBox(height: 4),
                        _intentDropdown('Sales', _intentMap['sales'] ?? '', (v) => setState(() => _intentMap['sales'] = v ?? '')),
                        _intentDropdown('Support', _intentMap['support'] ?? '', (v) => setState(() => _intentMap['support'] = v ?? '')),
                        _intentDropdown('Booking', _intentMap['booking'] ?? '', (v) => setState(() => _intentMap['booking'] = v ?? '')),
                        _intentDropdown('Billing', _intentMap['billing'] ?? '', (v) => setState(() => _intentMap['billing'] = v ?? '')),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: NeyvoColors.bgBase,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: NeyvoColors.borderDefault),
                          ),
                          child: Text(
                            'We listen to the first sentence of the call and automatically route to the right agent based on intent (Sales, Support, Booking, Billing).',
                            style: NeyvoTextStyles.body.copyWith(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ExpansionTile(
                          title: Text('Advanced', style: NeyvoTextStyles.label),
                          initiallyExpanded: _advancedExpanded,
                          onExpansionChanged: (v) => setState(() => _advancedExpanded = v),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Confidence threshold', style: NeyvoTextStyles.label),
                                  Slider(
                                    value: _confidenceThreshold,
                                    min: 0.5,
                                    max: 0.95,
                                    divisions: 9,
                                    label: _confidenceThreshold.toStringAsFixed(2),
                                    onChanged: (v) => setState(() => _confidenceThreshold = v),
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

                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: NeyvoColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _saving ? null : () => _showTestRoutingDialog(),
                            child: const Text('Test routing'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                            child: _saving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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

  Widget _radio(String value, String title, String subtitle) {
    final selected = _mode == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _mode = value),
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
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v ?? value),
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

  Widget _dropdown(String label, String value, void Function(String?) onChanged) {
    final valid = _profiles.any((p) => (p['profile_id'] ?? '').toString() == value);
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
            items: _profileItems(),
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

  Widget _intentDropdown(String label, String value, void Function(String?) onChanged) {
    final valid = _profiles.any((p) => (p['profile_id'] ?? '').toString() == value);
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
        items: _profileItems(),
        onChanged: onChanged,
      ),
    );
  }

  void _showTestRoutingDialog() {
    showDialog(
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
