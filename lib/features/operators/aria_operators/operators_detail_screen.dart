import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../neyvo_pulse_api.dart';
import '../../../pulse_route_names.dart';
import 'aria_operator_api_service.dart';
import 'aria_operator_providers.dart';
import 'aria_vapi_iframe.dart';

// Screen: /operators/{operator_id}
class OperatorsDetailScreen extends ConsumerStatefulWidget {
  final String operatorId;
  const OperatorsDetailScreen({required this.operatorId, super.key});

  @override
  ConsumerState<OperatorsDetailScreen> createState() => _OperatorsDetailScreenState();
}

class _OperatorsDetailScreenState extends ConsumerState<OperatorsDetailScreen> {
  StreamSubscription? _callMessageSub;

  @override
  void dispose() {
    _callMessageSub?.cancel();
    _callMessageSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(ariaOperatorDetailProvider(widget.operatorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Operator')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Failed to load operator: $e')),
        data: (doc) {
          final op = doc;
          final personaName = (op['persona_name'] ?? '').toString();
          final industry = (op['industry'] ?? '').toString();
          final operatorRole = (op['operator_role'] ?? '').toString();
          final summary = (op['operator_summary'] ?? '').toString();
          final status = (op['status'] ?? 'building').toString();
          final assistantId = (op['vapi_assistant_id'] ?? '').toString();
          final vapiPublicKey = (op['vapi_public_key'] ?? '').toString();

          final toneProfile = op['tone_profile'];
          final descriptors = (toneProfile is Map)
              ? (toneProfile['descriptors'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[]
              : const <String>[];

          final ariaExtractedProfile = op['aria_extracted_profile'];
          final operatorRoleDetail =
              (ariaExtractedProfile is Map && ariaExtractedProfile['operator_role_detail'] != null)
                  ? ariaExtractedProfile['operator_role_detail'].toString()
                  : '';

          final systemPromptFinal = (op['system_prompt_final'] ?? '').toString();

          final statusColor = status == 'live'
              ? const Color(0xFF22C55E)
              : status == 'error'
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF94A3B8);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 10, backgroundColor: statusColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        personaName.isEmpty ? 'Operator' : personaName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white12),
                        color: Colors.white.withOpacity(0.04),
                      ),
                      child: Text(industry.isEmpty ? 'Industry' : industry),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Text(
                  operatorRole.isEmpty ? operatorRoleDetail : operatorRole,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Card(
                  color: const Color(0xFF0B1225),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      summary.isEmpty ? '—' : summary,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.call_rounded),
                        onPressed: status == 'live' && assistantId.isNotEmpty && vapiPublicKey.isNotEmpty
                            ? () => _startOperatorCall(
                                  context: context,
                                  assistantId: assistantId,
                                  vapiPublicKey: vapiPublicKey,
                                )
                            : null,
                        label: const Text('Call this operator'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edit flow coming soon')),
                        );
                      },
                      child: const Text('Edit'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                      ),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete operator?'),
                            content: const Text('This permanently removes the operator assistant and its configuration.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await AriaOperatorApiService.deleteOperator(widget.operatorId);
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(context, PulseRouteNames.operatorsRoot);
                          }
                        }
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFF0B1225),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        const Text('Tone profile', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: descriptors.isEmpty
                              ? const [Text('—')]
                              : descriptors.map((d) => Chip(label: Text(d))).toList(),
                        ),
                        const SizedBox(height: 14),
                        const Text('Primary role', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text(operatorRole.isEmpty ? '—' : operatorRole),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Card(
                  color: const Color(0xFF0B1225),
                  child: ExpansionTile(
                    title: const Text('System prompt (advanced)'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          systemPromptFinal.isEmpty ? '—' : systemPromptFinal,
                          style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _startOperatorCall({
    required BuildContext context,
    required String assistantId,
    required String vapiPublicKey,
  }) async {
    final sessionId = AriaVapiSessionIframe.createSessionId();
    final viewType = 'operator-iframe-$sessionId';

    final htmlSrcDoc = AriaVapiSessionIframe.operatorCallHtml(
      sessionId: sessionId,
      operatorAssistantId: assistantId,
      publicKey: vapiPublicKey,
      accountId: NeyvoPulseApi.defaultAccountId,
      operatorId: widget.operatorId,
    );

    _callMessageSub?.cancel();
    // ignore: avoid_web_libraries_in_flutter
    final htmlWindow = (html.window);
    _callMessageSub = htmlWindow.onMessage.listen((event) {
      final data = event.data;
      if (data is! Map) return;
      final type = data['type']?.toString() ?? '';
      final msgSessionId = data['session_id']?.toString() ?? '';
      if (msgSessionId != sessionId) return;
      if (type == 'aria_call_end') {
        _callMessageSub?.cancel();
        _callMessageSub = null;
        if (context.mounted) Navigator.of(context).pop();
      }
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          child: SizedBox(
            width: 900,
            height: 620,
            child: AriaIframeView(htmlSrcDoc: htmlSrcDoc, viewType: viewType),
          ),
        );
      },
    );
  }
}

