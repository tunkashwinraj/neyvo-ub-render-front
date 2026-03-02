import 'package:flutter/material.dart';

import '../../../neyvo_pulse_api.dart';
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
  Map<String, dynamic> _config = {};

  bool _enabled = false;
  List<String> _modes = [];
  final _apiPullUrl = TextEditingController();
  final _webhookSecret = TextEditingController();
  bool _saving = false;
  bool _syncing = false;

  Map<String, dynamic>? _inboundHealth;
  bool _checkingHealth = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiPullUrl.dispose();
    _webhookSecret.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await NeyvoPulseApi.getIntegrationConfig();
      final c = res['config'] as Map<String, dynamic>? ?? res;
      if (!mounted) return;
      setState(() {
        _config = Map<String, dynamic>.from(c);
        _enabled = c['enabled'] == true;
        _modes = List<String>.from(c['modes'] as List? ?? const []);
        _apiPullUrl.text = c['api_pull_url']?.toString() ?? '';
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
      await NeyvoPulseApi.setIntegrationConfig(
        enabled: _enabled,
        modes: _modes.isEmpty ? null : _modes,
        webhookSecret: _webhookSecret.text.trim().isEmpty ? null : _webhookSecret.text.trim(),
        apiPullUrl: _apiPullUrl.text.trim().isEmpty ? null : _apiPullUrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Integrations saved')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _syncNow() async {
    if (_apiPullUrl.text.trim().isEmpty) return;
    setState(() => _syncing = true);
    try {
      final res = await NeyvoPulseApi.triggerIntegrationSync();
      if (!mounted) return;
      final ok = res['ok'] == true;
      final summary = res['summary'] as Map<String, dynamic>?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Sync done. Students: ${summary?['students_upserted'] ?? '?'}, Payments: ${summary?['payments_created'] ?? '?'}'
                : (res['error']?.toString() ?? 'Sync failed'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _checkInboundHealth() async {
    setState(() => _checkingHealth = true);
    try {
      final res = await NeyvoPulseApi.getInboundHealthCheck();
      if (!mounted) return;
      setState(() {
        _inboundHealth = res;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inbound health check complete')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Health check failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _checkingHealth = false);
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

    final lastSync = _config['last_sync_at']?.toString();
    final lastStatus = _config['last_sync_status']?.toString() ?? '—';

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
                Text('Inbound health check', style: NeyvoTextStyles.heading),
                const SizedBox(height: 10),
                NeyvoGlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Validate Twilio webhook + Vapi endpoint wiring.',
                        style: NeyvoTextStyles.body,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 260,
                        child: FilledButton.icon(
                          onPressed: _checkingHealth ? null : _checkInboundHealth,
                          icon: _checkingHealth
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.health_and_safety_outlined, size: 18),
                          label: const Text('Run health check'),
                          style: FilledButton.styleFrom(backgroundColor: NeyvoColors.teal),
                        ),
                      ),
                      if (_inboundHealth != null) ...[
                        const SizedBox(height: 12),
                        _kv('Twilio configured', '${_inboundHealth!['twilio_configured'] ?? '—'}'),
                        _kv('Vapi configured', '${_inboundHealth!['vapi_configured'] ?? '—'}'),
                        _kv('Numbers checked', '${_inboundHealth!['numbers_checked'] ?? '—'}'),
                        if (_inboundHealth!['issues'] is List && (_inboundHealth!['issues'] as List).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Issues', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textMuted)),
                          const SizedBox(height: 6),
                          ...(_inboundHealth!['issues'] as List).take(10).map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('- $e', style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.warning)),
                              )),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Data integration', style: NeyvoTextStyles.heading),
                const SizedBox(height: 10),
                NeyvoGlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                        title: const Text('Enable integration'),
                        subtitle: Text(
                          'Webhook, CSV ingest, or API pull',
                          style: NeyvoTextStyles.micro,
                        ),
                        activeColor: NeyvoColors.teal,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _modeChip('webhook', 'Webhook'),
                          _modeChip('api_pull', 'API pull'),
                          _modeChip('file_ingest', 'CSV ingest'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _apiPullUrl,
                        decoration: const InputDecoration(
                          labelText: 'API pull URL',
                          hintText: 'https://their-api.example.com/...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _webhookSecret,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Webhook secret (HMAC)',
                          hintText: 'Optional',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 220,
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
                            width: 220,
                            child: OutlinedButton(
                              onPressed: _syncing ? null : _syncNow,
                              child: _syncing
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Sync now'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Last sync: ${lastSync ?? '—'} · Status: $lastStatus',
                        style: NeyvoTextStyles.micro,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(k, style: NeyvoTextStyles.micro)),
          Expanded(child: Text(v, style: NeyvoTextStyles.bodyPrimary)),
        ],
      ),
    );
  }

  Widget _modeChip(String key, String label) {
    final selected = _modes.contains(key);
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (v) {
        setState(() {
          if (v) {
            if (!_modes.contains(key)) _modes.add(key);
          } else {
            _modes.remove(key);
          }
        });
      },
      selectedColor: NeyvoColors.teal.withOpacity(0.18),
      checkmarkColor: NeyvoColors.teal,
      side: BorderSide(color: selected ? NeyvoColors.teal.withOpacity(0.5) : NeyvoColors.borderSubtle),
    );
  }
}

