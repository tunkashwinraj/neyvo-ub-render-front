import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dialer_page_provider.dart';
import '../../../theme/neyvo_theme.dart';
import '../../../utils/phone_util.dart';
import '../../components/ai_orb/neyvo_ai_orb.dart';
import '../../components/glass/neyvo_glass_panel.dart';

class DialerPage extends ConsumerStatefulWidget {
  const DialerPage({super.key});

  @override
  ConsumerState<DialerPage> createState() => _DialerPageState();
}

class _DialerPageState extends ConsumerState<DialerPage> {
  final _contactPhone = TextEditingController();
  final _contactName = TextEditingController();
  final _structuredContext = TextEditingController();

  static String _toE164(String? p) => normalizePhoneInput(p);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dialerPageCtrlProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _contactPhone.dispose();
    _contactName.dispose();
    _structuredContext.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(dialerPageCtrlProvider);
    final primary = Theme.of(context).colorScheme.primary;
    if (d.loading) {
      return Center(child: CircularProgressIndicator(color: primary));
    }
    if (d.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(d.error!, style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.error)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(dialerPageCtrlProvider.notifier).load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final remaining = (d.capacity?['remaining_today'] as num?)?.toInt();
    final numbersCount = (d.capacity?['numbers_count'] as num?)?.toInt();
    final safePerNumber = (d.capacity?['safe_daily_per_number'] as num?)?.toInt();
    final perNumberRemaining = (d.numberCapacity?['remaining_today'] as num?)?.toInt();
    final perNumberLimit = (d.numberCapacity?['daily_limit'] as num?)?.toInt();
    final perNumberWarning = d.numberCapacity?['warning'] == true;
    final ctrl = ref.read(dialerPageCtrlProvider.notifier);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dialer',
                    style: NeyvoTextStyles.title.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => ctrl.load(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            NeyvoGlassPanel(
              child: Row(
                children: [
                  Icon(Icons.speed, color: primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Remaining capacity today: ${remaining ?? '—'}'
                      '${numbersCount != null ? ' · Numbers: $numbersCount' : ''}'
                      '${safePerNumber != null ? ' · Safe/number: $safePerNumber' : ''}',
                      style: NeyvoTextStyles.bodyPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if ((d.selectedNumberId ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              NeyvoGlassPanel(
                child: Row(
                  children: [
                    Icon(
                      perNumberWarning ? Icons.warning_amber_rounded : Icons.phone_outlined,
                      color: perNumberWarning ? NeyvoColors.warning : primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Selected number capacity: ${perNumberRemaining ?? '—'}'
                        '${perNumberLimit != null ? '/$perNumberLimit' : ''} remaining today',
                        style: NeyvoTextStyles.bodyPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NeyvoGlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Call setup', style: NeyvoTextStyles.heading),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: d.selectedAgentId,
                          decoration: const InputDecoration(labelText: 'Select agent'),
                          items: d.agents
                              .map((a) {
                                final id = (a['profile_id'] ?? '').toString();
                                final name = (a['profile_name'] ?? 'Operator').toString();
                                if (id.isEmpty) return null;
                                return DropdownMenuItem(value: id, child: Text(name));
                              })
                              .whereType<DropdownMenuItem<String>>()
                              .toList(),
                          onChanged: (v) => ctrl.setSelectedAgentId(v),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: d.selectedNumberId,
                          decoration: const InputDecoration(labelText: 'Select number'),
                          items: d.numbers
                              .map((n) {
                                final id = (n['phone_number_id'] ?? n['number_id'] ?? n['id'] ?? '').toString();
                                final e164 = (n['phone_number_e164'] ?? n['phone_number'] ?? n['e164'] ?? id).toString();
                                if (id.isEmpty) return null;
                                return DropdownMenuItem(value: id, child: Text(e164, overflow: TextOverflow.ellipsis));
                              })
                              .whereType<DropdownMenuItem<String>>()
                              .toList(),
                          onChanged: d.starting
                              ? null
                              : (v) async {
                                  await ctrl.setSelectedNumberId(v);
                                },
                        ),
                        if (d.students.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            value: d.selectedStudentId,
                            decoration: const InputDecoration(
                              labelText: 'Or select a student (auto-fills name & phone)',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('— Manual entry —')),
                              ...d.students.map((s) {
                                final id = s['id']?.toString() ?? '';
                                final name = s['name']?.toString() ?? '—';
                                final phone = s['phone']?.toString() ?? '';
                                final label = phone.isNotEmpty ? '$name ($phone)' : name;
                                if (id.isEmpty) return null;
                                return DropdownMenuItem(value: id, child: Text(label, overflow: TextOverflow.ellipsis));
                              }).whereType<DropdownMenuItem<String>>(),
                            ],
                            onChanged: d.starting
                                ? null
                                : (v) {
                                    ctrl.setSelectedStudentId(v);
                                    if (v != null) {
                                      final s = d.students.firstWhere(
                                        (e) => (e['id']?.toString()) == v,
                                        orElse: () => <String, dynamic>{},
                                      );
                                      if (s.isNotEmpty) {
                                        _contactName.text = s['name']?.toString() ?? '';
                                        _contactPhone.text = _toE164(s['phone']?.toString());
                                      }
                                    }
                                  },
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contactPhone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Contact phone',
                            hintText: '123-456-7890 or (123) 456-7890',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contactName,
                          decoration: const InputDecoration(
                            labelText: 'Contact name (optional)',
                            hintText: 'Alex',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _structuredContext,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Optional structured context',
                            hintText: 'e.g. {"goal":"book appointment","notes":"prefers mornings"}',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: d.starting
                                ? null
                                : () => ctrl.startCall(
                                      context,
                                      contactPhoneRaw: _contactPhone.text,
                                      contactName: _contactName.text,
                                      structuredContext: _structuredContext.text,
                                    ),
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: d.starting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Start Call'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 320,
                  child: NeyvoGlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Live', style: NeyvoTextStyles.heading),
                        const SizedBox(height: 12),
                        const Center(child: NeyvoAIOrb(state: NeyvoAIOrbState.idle, size: 140)),
                        const SizedBox(height: 12),
                        Text(
                          'Start a call to enter Live mode. Transcript will appear here when streaming is enabled.',
                          style: NeyvoTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (d.overlay != null) _DialerOverlay(state: d.overlay!),
      ],
    );
  }
}

class _DialerOverlay extends StatelessWidget {
  const _DialerOverlay({required this.state});

  final DialerOverlayState state;

  @override
  Widget build(BuildContext context) {
    final (orbState, label) = switch (state) {
      DialerOverlayState.connecting => (NeyvoAIOrbState.processing, 'Connecting call…'),
      DialerOverlayState.listening => (NeyvoAIOrbState.listening, 'Listening…'),
      DialerOverlayState.processing => (NeyvoAIOrbState.processing, 'Processing…'),
      DialerOverlayState.speaking => (NeyvoAIOrbState.speaking, 'Speaking…'),
      DialerOverlayState.success => (NeyvoAIOrbState.idle, 'Call started'),
      DialerOverlayState.error => (NeyvoAIOrbState.error, 'Call failed'),
    };

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: Center(
          child: NeyvoGlassPanel(
            glowing: state == DialerOverlayState.success,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NeyvoAIOrb(state: orbState, size: 160),
                  const SizedBox(height: 12),
                  Text(label, style: NeyvoTextStyles.heading.copyWith(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    'Neyvo is establishing audio and transcript streams.',
                    style: NeyvoTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
