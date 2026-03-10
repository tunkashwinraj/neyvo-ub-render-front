import 'package:flutter/material.dart';

import '../neyvo_pulse_api.dart';
import '../theme/neyvo_theme.dart';

class DeveloperConsolePage extends StatefulWidget {
  const DeveloperConsolePage({super.key});

  @override
  State<DeveloperConsolePage> createState() => _DeveloperConsolePageState();
}

class _DeveloperConsolePageState extends State<DeveloperConsolePage> {
  final _devPhoneNumberIdController = TextEditingController();
  final _devPhoneE164Controller = TextEditingController();
  bool _devWorking = false;

  @override
  void dispose() {
    _devPhoneNumberIdController.dispose();
    _devPhoneE164Controller.dispose();
    super.dispose();
  }

  Future<void> _devAttachNumber() async {
    final id = _devPhoneNumberIdController.text.trim();
    final e164 = _devPhoneE164Controller.text.trim();
    if (id.isEmpty || e164.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter phone_number_id and E.164 number')),
      );
      return;
    }
    setState(() => _devWorking = true);
    try {
      final res = await NeyvoPulseApi.attachNumber(
        phoneNumberId: id,
        phoneNumberE164: e164,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attached: ${res['phone_number_id'] ?? id}')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attach failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  Future<void> _devDetachNumber() async {
    final id = _devPhoneNumberIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter phone_number_id to detach')),
      );
      return;
    }
    setState(() => _devWorking = true);
    try {
      await NeyvoPulseApi.releaseNumber(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detached $id')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Detach failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  Future<void> _devSetPrimary() async {
    final id = _devPhoneNumberIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter phone_number_id to set primary')),
      );
      return;
    }
    setState(() => _devWorking = true);
    try {
      await NeyvoPulseApi.setOutboundPrimary(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Primary set to $id')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Set primary failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  Future<void> _devRegisterFreecaller() async {
    final id = _devPhoneNumberIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter phone_number_id to register')),
      );
      return;
    }
    setState(() => _devWorking = true);
    try {
      await NeyvoPulseApi.registerFreecaller(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registered freecaller for $id')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Register failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  Future<void> _devWarmupStatus() async {
    final id = _devPhoneNumberIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter phone_number_id to check warm-up')),
      );
      return;
    }
    setState(() => _devWorking = true);
    try {
      final res = await NeyvoPulseApi.getWarmUpStatus(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Warm-up: ${res['status'] ?? res}')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Warm-up check failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  Future<void> _devCapacity() async {
    final id = _devPhoneNumberIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter phone_number_id to check capacity')),
      );
      return;
    }
    setState(() => _devWorking = true);
    try {
      final res = await NeyvoPulseApi.getNumberCapacity(id);
      if (!mounted) return;
      final remaining = res['remaining_today'] ?? res['remaining'] ?? res;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capacity: $remaining calls remaining today')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capacity check failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  Future<void> _devAdvanceWarmup() async {
    final id = _devPhoneNumberIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter phone_number_id to advance warm-up')),
      );
      return;
    }
    setState(() => _devWorking = true);
    try {
      await NeyvoPulseApi.advanceWarmUp(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Warm-up advanced for $id')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Advance warm-up failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _devWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeyvoTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: NeyvoTheme.bgSurface,
        title: const Text('Developer Console – Telephony'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(NeyvoSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              color: NeyvoTheme.bgCard,
              child: Padding(
                padding: const EdgeInsets.all(NeyvoSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone numbers (admin‑only)',
                      style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary),
                    ),
                    const SizedBox(height: NeyvoSpacing.sm),
                    Text(
                      'Attach/detach numbers and run verification checks (warm-up, capacity, freecaller, primary). '
                      'This console is intended for internal admins only; normal customers should use the Numbers Hub.',
                      style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                    ),
                    const SizedBox(height: NeyvoSpacing.lg),
                    TextField(
                      controller: _devPhoneNumberIdController,
                      decoration: const InputDecoration(
                        labelText: 'phone_number_id',
                        hintText: 'Twilio/Vapi number id',
                      ),
                    ),
                    const SizedBox(height: NeyvoSpacing.sm),
                    TextField(
                      controller: _devPhoneE164Controller,
                      decoration: const InputDecoration(
                        labelText: 'Phone (E.164)',
                        hintText: '+1234567890',
                      ),
                    ),
                    const SizedBox(height: NeyvoSpacing.md),
                    Wrap(
                      spacing: NeyvoSpacing.sm,
                      runSpacing: NeyvoSpacing.sm,
                      children: [
                        FilledButton.tonal(
                          onPressed: _devWorking ? null : _devAttachNumber,
                          child: const Text('Attach'),
                        ),
                        FilledButton.tonal(
                          onPressed: _devWorking ? null : _devDetachNumber,
                          child: const Text('Detach'),
                        ),
                        FilledButton.tonal(
                          onPressed: _devWorking ? null : _devSetPrimary,
                          child: const Text('Set primary'),
                        ),
                        FilledButton.tonal(
                          onPressed: _devWorking ? null : _devRegisterFreecaller,
                          child: const Text('Register freecaller'),
                        ),
                        FilledButton.tonal(
                          onPressed: _devWorking ? null : _devWarmupStatus,
                          child: const Text('Warm-up status'),
                        ),
                        FilledButton.tonal(
                          onPressed: _devWorking ? null : _devCapacity,
                          child: const Text('Capacity'),
                        ),
                        FilledButton.tonal(
                          onPressed: _devWorking ? null : _devAdvanceWarmup,
                          child: const Text('Advance warm-up'),
                        ),
                      ],
                    ),
                    if (_devWorking) ...[
                      const SizedBox(height: NeyvoSpacing.sm),
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: NeyvoSpacing.sm),
                          Text(
                            'Running operation...',
                            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

