import 'package:flutter/material.dart';

import '../../../neyvo_pulse_api.dart';
import '../../../api/neyvo_api.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/glass/neyvo_glass_panel.dart';

class IntegrationsPage extends StatefulWidget {
  const IntegrationsPage({super.key});

  @override
  State<IntegrationsPage> createState() => _IntegrationsPageState();
}

class _IntegrationsPageState extends State<IntegrationsPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _slateConfig = {};
  Map<String, dynamic> _calendlyConfig = {};

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
      final slateRes = await NeyvoPulseApi.getSlateIntegration();
      final s = slateRes['config'] as Map<String, dynamic>? ?? slateRes;
      final calendlyRes = await NeyvoPulseApi.getCalendlyIntegration();
      final c = calendlyRes['config'] as Map<String, dynamic>? ?? calendlyRes;
      if (!mounted) return;
      setState(() {
        _slateConfig = Map<String, dynamic>.from(s);
        _calendlyConfig = Map<String, dynamic>.from(c);
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

    final slateEnabled = _slateConfig['enabled'] == true;
    final slateLastSent = _slateConfig['last_sent_at']?.toString();
    final slateLastError = _slateConfig['last_error']?.toString();

    final calendlyEnabled = _calendlyConfig['enabled'] == true;
    final calendlyUpdatedAt = _calendlyConfig['updated_at']?.toString();
    final calendlyLastError = _calendlyConfig['last_error']?.toString();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Integrations', style: NeyvoTextStyles.title.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('CRM integrations', style: NeyvoTextStyles.heading),
                const SizedBox(height: 10),
                NeyvoGlassPanel(
                  child: _integrationCard(
                    context,
                    title: 'Slate CRM',
                    subtitle: 'Send call events to Slate via webhook',
                    enabled: slateEnabled,
                    lastSentAt: slateLastSent,
                    lastError: slateLastError,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SlateIntegrationPage(initialConfig: _slateConfig),
                        ),
                      );
                      if (!mounted) return;
                      await _load();
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Text('Calendar integrations', style: NeyvoTextStyles.heading),
                const SizedBox(height: 10),
                NeyvoGlassPanel(
                  child: _integrationCard(
                    context,
                    title: 'Calendly',
                    subtitle: 'Let clients connect Calendly; book during calls via tools',
                    enabled: calendlyEnabled,
                    lastSentAt: calendlyUpdatedAt,
                    lastError: calendlyLastError,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CalendlyIntegrationPage(initialConfig: _calendlyConfig),
                        ),
                      );
                      if (!mounted) return;
                      await _load();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _integrationCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool enabled,
    required String? lastSentAt,
    required String? lastError,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final hasErr = lastError != null && lastError.trim().isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    NeyvoColors.ubPurple.withOpacity(0.95),
                    NeyvoColors.ubLightBlue.withOpacity(0.95),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  'S',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: enabled ? NeyvoColors.teal.withOpacity(0.14) : NeyvoColors.borderSubtle.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: enabled ? NeyvoColors.teal.withOpacity(0.35) : NeyvoColors.borderSubtle),
                        ),
                        child: Text(
                          enabled ? 'Enabled' : 'Disabled',
                          style: NeyvoTextStyles.micro.copyWith(
                            color: enabled ? NeyvoColors.teal : NeyvoColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: NeyvoColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: NeyvoTextStyles.micro),
                  const SizedBox(height: 8),
                  Text(
                    hasErr ? 'Last error: $lastError' : 'Last sent: ${lastSentAt ?? '—'}',
                    style: NeyvoTextStyles.micro.copyWith(color: hasErr ? NeyvoColors.warning : NeyvoColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SlateIntegrationPage extends StatefulWidget {
  final Map<String, dynamic> initialConfig;

  const SlateIntegrationPage({super.key, required this.initialConfig});

  @override
  State<SlateIntegrationPage> createState() => _SlateIntegrationPageState();
}

class _SlateIntegrationPageState extends State<SlateIntegrationPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _slateConfig = {};
  bool _enabled = false;
  bool _saving = false;
  bool _testing = false;
  final _webhookUrl = TextEditingController();
  final _authToken = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyConfig(widget.initialConfig);
    _refresh();
  }

  @override
  void dispose() {
    _webhookUrl.dispose();
    _authToken.dispose();
    super.dispose();
  }

  void _applyConfig(Map<String, dynamic> cfg) {
    _slateConfig = Map<String, dynamic>.from(cfg);
    _enabled = _slateConfig['enabled'] == true;
    _webhookUrl.text = _slateConfig['webhook_url']?.toString() ?? '';
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slateRes = await NeyvoPulseApi.getSlateIntegration();
      final s = slateRes['config'] as Map<String, dynamic>? ?? slateRes;
      if (!mounted) return;
      setState(() {
        _applyConfig(s);
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await NeyvoPulseApi.setSlateIntegration(
        enabled: _enabled,
        webhookUrl: _webhookUrl.text.trim(),
        authToken: _authToken.text.trim(),
      );
      if (!mounted) return;
      _authToken.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slate saved')));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Slate save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      final res = await NeyvoPulseApi.testSlateIntegration();
      if (!mounted) return;
      final ok = res['ok'] == true;
      final status = res['status_code']?.toString() ?? '';
      final msg = ok ? 'Test payload sent (HTTP $status)' : 'Test failed: ${res['error'] ?? res['response'] ?? ''}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Test failed: $e')));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastSent = _slateConfig['last_sent_at']?.toString();
    final lastError = _slateConfig['last_error']?.toString();
    final tokenSet = _slateConfig['auth_token_set'] == true;

    return Scaffold(
      backgroundColor: NeyvoTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: NeyvoTheme.bgSurface,
        title: Text('Slate CRM', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
        actions: [
          TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_loading) ...[
            const Center(child: CircularProgressIndicator(color: NeyvoColors.teal)),
            const SizedBox(height: 16),
          ],
          if (_error != null && _error!.trim().isNotEmpty) ...[
            Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.warning)),
            const SizedBox(height: 16),
          ],
          NeyvoGlassPanel(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configuration', style: NeyvoTextStyles.heading),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    title: const Text('Enable Slate webhook'),
                    subtitle: Text('Send inbound/outbound call events to Slate', style: NeyvoTextStyles.micro),
                    activeColor: NeyvoColors.teal,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _webhookUrl,
                    decoration: const InputDecoration(
                      labelText: 'Slate webhook URL',
                      hintText: 'https://...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _authToken,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Auth token (optional)',
                      hintText: tokenSet ? 'Token is set (enter to replace)' : 'Bearer token',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SizedBox(
                        width: 180,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 200,
                        child: OutlinedButton(
                          onPressed: _testing ? null : _test,
                          child: _testing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Send test payload'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Last sent: ${lastSent ?? '—'}${lastError != null && lastError.trim().isNotEmpty ? ' · Last error: $lastError' : ''}',
                    style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          NeyvoGlassPanel(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payload', style: NeyvoTextStyles.heading),
                  const SizedBox(height: 8),
                  Text('Slate receives a lead with a nested call object.', style: NeyvoTextStyles.micro),
                  const SizedBox(height: 10),
                  SelectableText(
                    '''{
  "lead": {
    "created_at": "2026-03-16T12:00:00Z",
    "display_name": "Test User",
    "event_type": "Call",
    "contact": {
      "first_name": "Test",
      "last_name": "User",
      "email": "test@example.com",
      "phone_work": "555-0199"
    },
    "chat": {
      "summary": "Short call summary"
    },
    "call": {
      "vapi_call_id": "xxxxxxxx",
      "status": "completed",
      "duration_seconds": 60,
      "recording_url": "https://..."
    }
  }
}''',
                    style: NeyvoTextStyles.micro.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CalendlyIntegrationPage extends StatefulWidget {
  final Map<String, dynamic> initialConfig;

  const CalendlyIntegrationPage({super.key, required this.initialConfig});

  @override
  State<CalendlyIntegrationPage> createState() => _CalendlyIntegrationPageState();
}

class _CalendlyIntegrationPageState extends State<CalendlyIntegrationPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _cfg = {};
  bool _enabled = false;
  bool _saving = false;
  bool _fetchingTypes = false;

  final _connectionId = TextEditingController();
  final _eventTypeUri = TextEditingController();

  List<Map<String, dynamic>> _eventTypes = const [];

  @override
  void initState() {
    super.initState();
    _apply(widget.initialConfig);
    _refresh();
  }

  @override
  void dispose() {
    _connectionId.dispose();
    _eventTypeUri.dispose();
    super.dispose();
  }

  void _apply(Map<String, dynamic> cfg) {
    _cfg = Map<String, dynamic>.from(cfg);
    _enabled = _cfg['enabled'] == true;
    _connectionId.text = ''; // no longer used (OAuth-based)
    _eventTypeUri.text = _cfg['event_type_uri']?.toString() ?? '';
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await NeyvoPulseApi.getCalendlyIntegration();
      final c = res['config'] as Map<String, dynamic>? ?? res;
      if (!mounted) return;
      setState(() {
        _apply(c);
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await NeyvoPulseApi.setCalendlyIntegration(
        enabled: _enabled,
        eventTypeUri: _eventTypeUri.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calendly saved')));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calendly save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _connect() async {
    try {
      final res = await NeyvoPulseApi.startCalendlyOAuth();
      final url = (res['auth_url'] ?? res['authUrl'] ?? '').toString();
      if (url.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No auth URL returned')));
        return;
      }
      await NeyvoApi.launchExternal(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connect failed: $e')));
    }
  }

  Future<void> _disconnect() async {
    try {
      await NeyvoPulseApi.disconnectCalendly();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calendly disconnected')));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disconnect failed: $e')));
    }
  }

  Future<void> _loadEventTypes() async {
    setState(() => _fetchingTypes = true);
    try {
      final res = await NeyvoPulseApi.listCalendlyEventTypes();
      final list = (res['event_types'] ?? res['eventTypes'] ?? res['data']) as List<dynamic>? ?? const [];
      final parsed = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) parsed.add(Map<String, dynamic>.from(item));
      }
      if (!mounted) return;
      setState(() => _eventTypes = parsed);
      if (parsed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No event types returned')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load event types failed: $e')));
    } finally {
      if (mounted) setState(() => _fetchingTypes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final updatedAt = _cfg['updated_at']?.toString();
    final lastError = _cfg['last_error']?.toString();
    final connected = _cfg['connected'] == true;
    return Scaffold(
      backgroundColor: NeyvoTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: NeyvoTheme.bgSurface,
        title: Text('Calendly', style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary)),
        actions: [
          TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_loading) ...[
            const Center(child: CircularProgressIndicator(color: NeyvoColors.teal)),
            const SizedBox(height: 16),
          ],
          if (_error != null && _error!.trim().isNotEmpty) ...[
            Text(_error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.warning)),
            const SizedBox(height: 16),
          ],
          NeyvoGlassPanel(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configuration', style: NeyvoTextStyles.heading),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    title: const Text('Enable Calendly'),
                    subtitle: Text('Used for availability + booking during calls', style: NeyvoTextStyles.micro),
                    activeColor: NeyvoColors.teal,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: FilledButton(
                          onPressed: connected ? null : _connect,
                          style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                          child: Text(connected ? 'Connected' : 'Connect Calendly'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 200,
                        child: OutlinedButton(
                          onPressed: connected ? _disconnect : null,
                          child: const Text('Disconnect'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _eventTypeUri,
                    decoration: const InputDecoration(
                      labelText: 'Calendly event_type_uri',
                      hintText: 'https://api.calendly.com/event_types/...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SizedBox(
                        width: 180,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 200,
                        child: OutlinedButton(
                          onPressed: _fetchingTypes ? null : _loadEventTypes,
                          child: _fetchingTypes
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Load event types'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Updated: ${updatedAt ?? '—'}${lastError != null && lastError.trim().isNotEmpty ? ' · Last error: $lastError' : ''}',
                    style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          if (_eventTypes.isNotEmpty) ...[
            const SizedBox(height: 18),
            NeyvoGlassPanel(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Event types', style: NeyvoTextStyles.heading),
                    const SizedBox(height: 10),
                    for (final e in _eventTypes.take(20)) ...[
                      Text(
                        (e['name']?.toString() ?? 'Event type'),
                        style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        e['uri']?.toString() ?? '',
                        style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
                      ),
                      const Divider(height: 18),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

