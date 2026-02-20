// lib/screens/integration_page.dart
// Data integration: connect school DB → Firestore (webhook, CSV, API pull)

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../theme/spearia_theme.dart';

class IntegrationPage extends StatefulWidget {
  const IntegrationPage({super.key});

  @override
  State<IntegrationPage> createState() => _IntegrationPageState();
}

class _IntegrationPageState extends State<IntegrationPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _config = {};
  final _apiPullUrl = TextEditingController();
  final _webhookSecret = TextEditingController();
  bool _enabled = false;
  List<String> _modes = [];
  bool _saving = false;
  bool _syncing = false;
  String? _csvError;
  final _csvController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiPullUrl.dispose();
    _webhookSecret.dispose();
    _csvController.dispose();
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
      if (mounted) {
        _config = Map<String, dynamic>.from(c);
        _enabled = c['enabled'] == true;
        _modes = List<String>.from(c['modes'] as List? ?? []);
        _apiPullUrl.text = c['api_pull_url']?.toString() ?? '';
        setState(() => _loading = false);
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

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    try {
      await NeyvoPulseApi.setIntegrationConfig(
        enabled: _enabled,
        modes: _modes.isEmpty ? null : _modes,
        webhookSecret: _webhookSecret.text.trim().isEmpty ? null : _webhookSecret.text.trim(),
        apiPullUrl: _apiPullUrl.text.trim().isEmpty ? null : _apiPullUrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Integration config saved')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final res = await NeyvoPulseApi.triggerIntegrationSync();
      if (mounted) {
        final ok = res['ok'] == true;
        final summary = res['summary'] as Map<String, dynamic>?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Sync done. Students: ${summary?['students_upserted'] ?? '?'}, Payments created: ${summary?['payments_created'] ?? '?'}'
                  : (res['error']?.toString() ?? 'Sync failed'),
            ),
            backgroundColor: ok ? SpeariaAura.success : SpeariaAura.error,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: SpeariaAura.error),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _ingestCsv() async {
    final csv = _csvController.text.trim();
    if (csv.isEmpty) {
      setState(() => _csvError = 'Paste CSV content (header row required)');
      return;
    }
    setState(() => _csvError = null);
    try {
      final res = await NeyvoPulseApi.ingestCsv(csv: csv);
      final summary = res['summary'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ingested. Students: ${summary['students_upserted'] ?? 0}, Payments created: ${summary['payments_created'] ?? 0}',
            ),
            backgroundColor: SpeariaAura.success,
          ),
        );
        _csvController.clear();
        _load();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _csvError = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Data integration')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(SpeariaSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _error!,
                  style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpeariaSpacing.lg),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final lastSync = _config['last_sync_at'];
    final lastStatus = _config['last_sync_status']?.toString() ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data integration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        children: [
          Text(
            'Connect your school database',
            style: SpeariaType.headlineSmall,
          ),
          const SizedBox(height: SpeariaSpacing.xs),
          Text(
            'Sync students and payments from your SIS/ERP via webhook, CSV upload, or API pull.',
            style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
          ),
          const SizedBox(height: SpeariaSpacing.xl),

          // Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SpeariaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status', style: SpeariaType.titleMedium),
                  const SizedBox(height: SpeariaSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        _enabled ? Icons.check_circle : Icons.cancel,
                        color: _enabled ? SpeariaAura.success : SpeariaAura.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: SpeariaSpacing.sm),
                      Text(
                        _enabled ? 'Integration enabled' : 'Integration disabled',
                        style: SpeariaType.bodyMedium,
                      ),
                    ],
                  ),
                  if (_modes.isNotEmpty) ...[
                    const SizedBox(height: SpeariaSpacing.xs),
                    Text(
                      'Modes: ${_modes.join(", ")}',
                      style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary),
                    ),
                  ],
                  if (lastSync != null) ...[
                    const SizedBox(height: SpeariaSpacing.sm),
                    Text(
                      'Last sync: $lastStatus',
                      style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: SpeariaSpacing.xl),

          // Config
          Text('Configuration', style: SpeariaType.titleLarge),
          const SizedBox(height: SpeariaSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SpeariaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Enable integration'),
                    subtitle: const Text('Allow webhook, CSV, and API pull'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const Divider(),
                  CheckboxListTile(
                    title: const Text('Webhook'),
                    subtitle: const Text('Real-time: their system POSTs to our URL'),
                    value: _modes.contains('webhook'),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          if (!_modes.contains('webhook')) _modes.add('webhook');
                        } else {
                          _modes.remove('webhook');
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('API pull'),
                    subtitle: const Text('We call their API on a schedule or when you click Sync'),
                    value: _modes.contains('api_pull'),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          if (!_modes.contains('api_pull')) _modes.add('api_pull');
                        } else {
                          _modes.remove('api_pull');
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('File ingest (CSV)'),
                    subtitle: const Text('Upload or paste CSV below'),
                    value: _modes.contains('file_ingest'),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          if (!_modes.contains('file_ingest')) _modes.add('file_ingest');
                        } else {
                          _modes.remove('file_ingest');
                        }
                      });
                    },
                  ),
                  const SizedBox(height: SpeariaSpacing.md),
                  TextField(
                    controller: _apiPullUrl,
                    decoration: const InputDecoration(
                      labelText: 'API pull URL',
                      hintText: 'https://their-api.example.com/students-payments',
                      helperText: 'Optional. Used when you click Sync now.',
                    ),
                  ),
                  const SizedBox(height: SpeariaSpacing.sm),
                  TextField(
                    controller: _webhookSecret,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Webhook secret (HMAC)',
                      hintText: 'Optional; for signature verification',
                    ),
                  ),
                  const SizedBox(height: SpeariaSpacing.lg),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveConfig,
                    icon: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: Text(_saving ? 'Saving...' : 'Save config'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SpeariaSpacing.xl),

          // Sync now
          Text('Sync now', style: SpeariaType.titleLarge),
          const SizedBox(height: SpeariaSpacing.sm),
          Text(
            'Pull data from the API pull URL (if configured). Run on a schedule via cron, or click below.',
            style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary),
          ),
          const SizedBox(height: SpeariaSpacing.md),
          FilledButton.tonalIcon(
            onPressed: (_syncing || _apiPullUrl.text.trim().isEmpty) ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 18),
            label: Text(_syncing ? 'Syncing...' : 'Sync now'),
          ),
          const SizedBox(height: SpeariaSpacing.xl),

          // CSV ingest
          Text('Upload CSV', style: SpeariaType.titleLarge),
          const SizedBox(height: SpeariaSpacing.sm),
          Text(
            'Paste CSV with header row. Columns: external_id, name, phone, email, balance, due_date, late_fee, notes (or map in backend).',
            style: SpeariaType.bodySmall.copyWith(color: SpeariaAura.textSecondary),
          ),
          const SizedBox(height: SpeariaSpacing.md),
          TextField(
            controller: _csvController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'external_id,name,phone,balance\nstu-001,Jane Doe,+15551234567,100.00',
              errorText: _csvError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: SpeariaSpacing.md),
          FilledButton.tonalIcon(
            onPressed: _ingestCsv,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Ingest CSV'),
          ),
        ],
      ),
    );
  }
}
