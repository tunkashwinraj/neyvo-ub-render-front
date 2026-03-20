import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _calendlyCtrl = TextEditingController();
  final _smtpHostCtrl = TextEditingController();
  final _smtpPortCtrl = TextEditingController();
  final _smtpUserCtrl = TextEditingController();
  final _smtpPassCtrl = TextEditingController();

  @override
  void dispose() {
    _calendlyCtrl.dispose();
    _smtpHostCtrl.dispose();
    _smtpPortCtrl.dispose();
    _smtpUserCtrl.dispose();
    _smtpPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(settingsNotifierProvider);
    return asyncValue.when(
      data: (data) {
        _calendlyCtrl.text = _calendlyCtrl.text.isEmpty ? data.calendlyUrl : _calendlyCtrl.text;
        _smtpHostCtrl.text = _smtpHostCtrl.text.isEmpty ? data.smtpHost : _smtpHostCtrl.text;
        _smtpPortCtrl.text = _smtpPortCtrl.text.isEmpty ? '${data.smtpPort}' : _smtpPortCtrl.text;
        _smtpUserCtrl.text = _smtpUserCtrl.text.isEmpty ? data.smtpUsername : _smtpUserCtrl.text;
        _smtpPassCtrl.text = _smtpPassCtrl.text.isEmpty ? data.smtpPassword : _smtpPassCtrl.text;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Calendly'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _calendlyCtrl,
                      decoration: const InputDecoration(labelText: 'Calendly URL'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await ref.read(settingsNotifierProvider.notifier).updateSettings({
                            'calendly_url': _calendlyCtrl.text.trim(),
                          });
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calendly settings saved')));
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SMTP Configuration'),
                    const SizedBox(height: 12),
                    TextField(controller: _smtpHostCtrl, decoration: const InputDecoration(labelText: 'SMTP Host')),
                    const SizedBox(height: 8),
                    TextField(controller: _smtpPortCtrl, decoration: const InputDecoration(labelText: 'SMTP Port')),
                    const SizedBox(height: 8),
                    TextField(controller: _smtpUserCtrl, decoration: const InputDecoration(labelText: 'SMTP Username')),
                    const SizedBox(height: 8),
                    TextField(controller: _smtpPassCtrl, decoration: const InputDecoration(labelText: 'SMTP Password')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () async {
                            try {
                              await ref.read(settingsNotifierProvider.notifier).updateSettings({
                                'smtp_host': _smtpHostCtrl.text.trim(),
                                'smtp_port': int.tryParse(_smtpPortCtrl.text.trim()) ?? 0,
                                'smtp_username': _smtpUserCtrl.text.trim(),
                                'smtp_password': _smtpPassCtrl.text.trim(),
                              });
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMTP settings saved')));
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
                            }
                          },
                          child: const Text('Save'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () async {
                            final ok = await ref.read(settingsNotifierProvider.notifier).sendTestEmail();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'Test email sent' : 'Test email failed')),
                            );
                          },
                          child: const Text('Send Test Email'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
