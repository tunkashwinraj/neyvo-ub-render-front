import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/settings_model.dart';
import '../../core/providers/settings_provider.dart';
import '../../theme/neyvo_theme.dart';
import '../../ui/components/glass/neyvo_glass_panel.dart';

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

  bool _appliedFromServer = false;

  @override
  void dispose() {
    _calendlyCtrl.dispose();
    _smtpHostCtrl.dispose();
    _smtpPortCtrl.dispose();
    _smtpUserCtrl.dispose();
    _smtpPassCtrl.dispose();
    super.dispose();
  }

  void _applyFromModel(SettingsModel data) {
    _calendlyCtrl.text = data.calendlyUrl;
    _smtpHostCtrl.text = data.smtpHost;
    _smtpPortCtrl.text = data.smtpPort == 0 ? '' : '${data.smtpPort}';
    _smtpUserCtrl.text = data.smtpUsername;
    _smtpPassCtrl.text = data.smtpPassword;
    _appliedFromServer = true;
  }

  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(settingsNotifierProvider);
    return asyncValue.when(
      data: (data) {
        if (!_appliedFromServer) {
          _applyFromModel(data);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Calendly', style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
            const SizedBox(height: 12),
            NeyvoGlassPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          _appliedFromServer = false;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Calendly settings saved')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Save failed: $e')),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('SMTP configuration', style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
            const SizedBox(height: 12),
            NeyvoGlassPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _smtpHostCtrl,
                      decoration: const InputDecoration(labelText: 'SMTP Host'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _smtpPortCtrl,
                      decoration: const InputDecoration(labelText: 'SMTP Port'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _smtpUserCtrl,
                      decoration: const InputDecoration(labelText: 'SMTP Username'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _smtpPassCtrl,
                      decoration: const InputDecoration(labelText: 'SMTP Password'),
                      obscureText: true,
                    ),
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
                              _appliedFromServer = false;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('SMTP settings saved')),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Save failed: $e')),
                              );
                            }
                          },
                          child: const Text('Save'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () async {
                            try {
                              final ok = await ref.read(settingsNotifierProvider.notifier).sendTestEmail();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok ? 'Test email sent' : 'Test email failed'),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Test email failed: $e')),
                              );
                            }
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
