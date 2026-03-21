// lib/ui/screens/calls/test_call_page.dart
// Dedicated Test Call page – make the first successful call obvious.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/providers/account_provider.dart';
import '../../../neyvo_pulse_api.dart';
import '../../../pulse_route_names.dart';
import '../../../screens/pulse_shell.dart';
import '../../../theme/neyvo_theme.dart';
import '../../components/glass/neyvo_glass_panel.dart';
import '../../activation/activation_service.dart';

class TestCallPage extends ConsumerStatefulWidget {
  const TestCallPage({super.key});

  @override
  ConsumerState<TestCallPage> createState() => _TestCallPageState();
}

class _TestCallPageState extends ConsumerState<TestCallPage> {
  bool _loading = true;
  String? _error;
  String? _trainingNumber;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _startPollingActivation();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ref.read(accountInfoProvider.future),
        NeyvoPulseApi.listNumbers(),
      ]);
      final account = results[0] as Map<String, dynamic>;
      final numbersRes = results[1] as Map<String, dynamic>;
      final numbers = (numbersRes['numbers'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

      String? e164 = (account['primary_phone_e164'] ?? account['primary_phone'])?.toString().trim();
      if (e164 == null || e164.isEmpty) {
        final primary = numbers.firstWhere(
          (n) => (n['role']?.toString().toLowerCase() ?? '') == 'primary',
          orElse: () => const {},
        );
        if (primary.isNotEmpty) {
          e164 = (primary['phone_number_e164'] ?? primary['phone_number'])?.toString().trim();
        } else if (numbers.isNotEmpty) {
          final any = numbers.first;
          e164 = (any['phone_number_e164'] ?? any['phone_number'])?.toString().trim();
        }
      }

      if (!mounted) return;
      setState(() {
        _trainingNumber = (e164 != null && e164.isNotEmpty) ? e164 : null;
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

  void _startPollingActivation() {
    // Initial snapshot.
    activationService.refresh();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await activationService.refresh();
      if (!mounted) return;
      if (activationService.isLive) {
        _pollTimer?.cancel();
      }
    });
  }

  void _copyNumber() {
    final n = _trainingNumber;
    if (n == null || n.isEmpty) return;
    Clipboard.setData(ClipboardData(text: n));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Number copied')));
  }

  @override
  Widget build(BuildContext context) {
    final status = activationService.status;
    final live = activationService.isLive || (status?.firstCallCompleted == true);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
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

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        await activationService.refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    live ? 'Test call complete' : 'Make your first test call',
                    style: NeyvoTextStyles.title.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    live
                        ? 'Your Voice OS has handled its first call. You are now live.'
                        : 'Call your training number once from any phone to confirm your Voice OS is wired correctly.',
                    style: NeyvoTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  NeyvoGlassPanel(
                    glowing: !live,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.phone_in_talk_outlined, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 10),
                            Text('Training number', style: NeyvoTextStyles.heading),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: NeyvoColors.bgRaised.withOpacity(0.7),
                            border: Border.all(color: NeyvoColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _trainingNumber ?? 'No number connected yet',
                                  style: NeyvoTextStyles.title.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: NeyvoColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (_trainingNumber != null)
                                OutlinedButton.icon(
                                  onPressed: _copyNumber,
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Copy'),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!live) ...[
                          Text(
                            '1. From your real phone, dial the training number.\n'
                            '2. Talk to your agent for at least 30 seconds.\n'
                            '3. Hang up and wait a few seconds – this page will update automatically.',
                            style: NeyvoTextStyles.body,
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Waiting for first completed call…',
                                  style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              const Icon(Icons.verified_outlined, color: NeyvoColors.success),
                              const SizedBox(width: 8),
                              Text(
                                'First call detected · Activation complete',
                                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.success),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => PulseShellController.navigatePulse(context, PulseRouteNames.dashboard),
                              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                              child: const Text('Go to Home'),
                            ),
                          ),
                        ],
                      ],
                    ),
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

