import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

<<<<<<< HEAD
=======
import '../../../features/settings/settings_screen.dart';
import '../../../neyvo_pulse_api.dart';
>>>>>>> origin/Twinkle
import '../../../api/neyvo_api.dart';
import '../../../neyvo_pulse_api.dart';
import '../../../providers/sendgrid_providers.dart';
import '../../../providers/sms_providers.dart';
import '../../../services/sendgrid_api.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/glass/neyvo_glass_panel.dart';

class IntegrationsPage extends ConsumerStatefulWidget {
  const IntegrationsPage({super.key});

  @override
  ConsumerState<IntegrationsPage> createState() => _IntegrationsPageState();
}

class _IntegrationsPageState extends ConsumerState<IntegrationsPage> {
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
      ref.invalidate(sendgridConfigProvider);
      ref.invalidate(smsConfigProvider);
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

    final sendgridAsync = ref.watch(sendgridConfigProvider);

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
                      onPressed: () {
                        ref.invalidate(sendgridConfigProvider);
                        ref.invalidate(smsConfigProvider);
                        _load();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                NeyvoGlassPanel(
                  child: ListTile(
                    leading: Icon(Icons.settings_suggest_outlined, color: NeyvoColors.teal),
                    title: const Text('Pulse integration settings'),
                    subtitle: Text(
                      'Calendly URL, SMTP, and test email',
                      style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary, fontSize: 13),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            backgroundColor: NeyvoColors.bgVoid,
                            appBar: AppBar(
                              title: const Text('Integration settings'),
                              backgroundColor: NeyvoColors.bgBase,
                            ),
                            body: const SettingsScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
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
                    leadingLetter: 'S',
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
                    leadingLetter: 'C',
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
                const SizedBox(height: 18),
                Text('Email delivery', style: NeyvoTextStyles.heading),
                const SizedBox(height: 10),
                sendgridAsync.when(
                  loading: () => const NeyvoGlassPanel(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator(color: NeyvoColors.teal)),
                    ),
                  ),
                  error: (e, _) => NeyvoGlassPanel(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'SendGrid: $e',
                        style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.warning),
                      ),
                    ),
                  ),
                  data: (cfg) {
                    final connected = cfg.connected;
                    final from = cfg.fromEmail ?? '';
                    return NeyvoGlassPanel(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                  child: const Center(
                                    child: Icon(Icons.email_outlined, color: Colors.white, size: 22),
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
                                              'SendGrid',
                                              style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: connected
                                                  ? const Color(0xFF22C55E).withOpacity(0.14)
                                                  : NeyvoColors.borderSubtle.withOpacity(0.4),
                                              borderRadius: BorderRadius.circular(999),
                                              border: Border.all(
                                                color: connected
                                                    ? const Color(0xFF22C55E).withOpacity(0.45)
                                                    : NeyvoColors.borderSubtle,
                                              ),
                                            ),
                                            child: Text(
                                              connected ? 'Connected' : 'Not connected',
                                              style: NeyvoTextStyles.micro.copyWith(
                                                color: connected ? const Color(0xFF22C55E) : NeyvoColors.textMuted,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Transactional email for voice tools (sendEmail)',
                                        style: NeyvoTextStyles.micro,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        connected ? 'From: ${from.isEmpty ? '—' : from}' : 'Connect your SendGrid API key',
                                        style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: () async {
                                    await showModalBottomSheet<void>(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: NeyvoTheme.bgSurface,
                                      builder: (ctx) => ConnectSendGridSheet(
                                        onDone: () {
                                          ref.invalidate(sendgridConfigProvider);
                                          Navigator.pop(ctx);
                                        },
                                      ),
                                    );
                                  },
                                  style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                                  child: Text(connected ? 'Update connection' : 'Connect'),
                                ),
                                if (connected)
                                  OutlinedButton(
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Disconnect SendGrid?'),
                                          content: const Text('Voice email tools will stop until you connect again.'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Disconnect')),
                                          ],
                                        ),
                                      );
                                      if (ok == true && context.mounted) {
                                        try {
                                          await SendgridApi.disconnect();
                                          ref.invalidate(sendgridConfigProvider);
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                          }
                                        }
                                      }
                                    },
                                    child: const Text('Disconnect'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Text('Messaging', style: NeyvoTextStyles.heading),
                const SizedBox(height: 10),
                ref.watch(smsConfigProvider).when(
                  loading: () => const NeyvoGlassPanel(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator(color: NeyvoColors.teal)),
                    ),
                  ),
                  error: (e, _) => NeyvoGlassPanel(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'SMS (Twilio): $e',
                        style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.warning),
                      ),
                    ),
                  ),
                  data: (smsCfg) {
                    final active = smsCfg.configured;
                    final masked = smsCfg.fromMasked ?? '';
                    return NeyvoGlassPanel(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  colors: [
                                    NeyvoColors.teal.withOpacity(0.9),
                                    NeyvoColors.ubLightBlue.withOpacity(0.9),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(
                                child: Icon(Icons.sms_outlined, color: Colors.white, size: 22),
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
                                          'SMS via Twilio',
                                          style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: active
                                              ? const Color(0xFF22C55E).withOpacity(0.14)
                                              : NeyvoColors.borderSubtle.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                            color: active
                                                ? const Color(0xFF22C55E).withOpacity(0.45)
                                                : NeyvoColors.borderSubtle,
                                          ),
                                        ),
                                        child: Text(
                                          active ? 'Active' : 'Setup required',
                                          style: NeyvoTextStyles.micro.copyWith(
                                            color: active ? const Color(0xFF22C55E) : NeyvoColors.textMuted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Outbound SMS for ARIA operators (sendSMS tool)',
                                    style: NeyvoTextStyles.micro,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    active
                                        ? 'From: ${masked.isEmpty ? 'configured' : masked}'
                                        : 'Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_PHONE_NUMBER on the API server.',
                                    style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
    String leadingLetter = 'S',
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
                  leadingLetter,
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

/// Bottom sheet: API key (obscured) + from email, 1s debounced SendGrid key validation, inline errors only.
class ConnectSendGridSheet extends StatefulWidget {
  final VoidCallback onDone;

  const ConnectSendGridSheet({super.key, required this.onDone});

  @override
  State<ConnectSendGridSheet> createState() => _ConnectSendGridSheetState();
}

class _ConnectSendGridSheetState extends State<ConnectSendGridSheet> {
  final _apiKey = TextEditingController();
  final _fromEmail = TextEditingController();
  bool _obscure = true;
  bool _validating = false;
  bool? _keyOk;
  String? _keyInlineError;
  Timer? _debounce;
  bool _saving = false;
  String? _formError;

  @override
  void dispose() {
    _debounce?.cancel();
    _apiKey.dispose();
    _fromEmail.dispose();
    super.dispose();
  }

  void _scheduleValidate() {
    _debounce?.cancel();
    setState(() {
      _keyOk = null;
      _keyInlineError = null;
    });
    final v = _apiKey.text.trim();
    if (v.isEmpty) return;
    _debounce = Timer(const Duration(seconds: 1), () async {
      if (!mounted) return;
      setState(() {
        _validating = true;
        _keyInlineError = null;
      });
      final r = await SendgridApi.validateApiKey(v);
      if (!mounted) return;
      setState(() {
        _validating = false;
        _keyOk = r.valid;
        _keyInlineError = r.valid ? null : (r.errorMessage ?? 'Invalid key');
      });
    });
  }

  Future<void> _connect() async {
    setState(() => _formError = null);
    final key = _apiKey.text.trim();
    final from = _fromEmail.text.trim();
    if (key.isEmpty || from.isEmpty) {
      setState(() => _formError = 'API key and from email are required.');
      return;
    }
    if (from.contains('@') == false) {
      setState(() => _formError = 'Enter a valid from email.');
      return;
    }
    setState(() => _saving = true);
    try {
      await SendgridApi.connect(apiKey: key, fromEmail: from);
      if (!mounted) return;
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      setState(() => _formError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Connect SendGrid', style: NeyvoTextStyles.heading),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fromEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'From email (verified sender)',
                hintText: 'hello@yourdomain.com',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKey,
              obscureText: _obscure,
              onChanged: (_) => _scheduleValidate(),
              decoration: InputDecoration(
                labelText: 'SendGrid API key',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_validating)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_keyOk == true)
                      const Icon(Icons.check_circle, color: Color(0xFF22C55E))
                    else if (_keyOk == false)
                      const Icon(Icons.cancel, color: Color(0xFFEF4444)),
                    IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ],
                ),
              ),
            ),
            if (_keyInlineError != null && _keyInlineError!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(_keyInlineError!, style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.error)),
            ],
            if (_formError != null && _formError!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_formError!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.warning)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _connect,
              style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save connection'),
            ),
          ],
        ),
      ),
    );
  }
}

