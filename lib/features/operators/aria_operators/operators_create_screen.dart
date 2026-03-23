import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../neyvo_pulse_api.dart';
import '../../../pulse_route_names.dart';
import 'aria_operator_providers.dart';
import 'aria_vapi_iframe.dart';

// Screen: /operators/new
class OperatorsCreateScreen extends ConsumerStatefulWidget {
  const OperatorsCreateScreen({super.key});

  @override
  ConsumerState<OperatorsCreateScreen> createState() => _OperatorsCreateScreenState();
}

class _OperatorsCreateScreenState extends ConsumerState<OperatorsCreateScreen> {
  StreamSubscription? _messageSub;
  ProviderSubscription<AriaCreateSessionState>? _sessionSub;
  late final String _sessionId = AriaVapiSessionIframe.createSessionId();
  late final String _viewType = 'aria-iframe-${_sessionId}';

  @override
  void initState() {
    super.initState();
    _sessionSub = ref.listenManual<AriaCreateSessionState>(ariaCreateSessionProvider, (prev, next) {
      if (prev != null && !prev.callEnded && next.callEnded && next.operatorId != null) {
        Navigator.pushReplacementNamed(
          context,
          '${PulseRouteNames.operatorsRoot}/building/${next.operatorId}',
        );
      }
    });
    // Listen for postMessage events from inside the iframe.
    _messageSub = html.window.onMessage.listen((event) {
      final data = event.data;
      if (data is! Map) return;
      final type = data['type']?.toString() ?? '';
      final msgSessionId = data['session_id']?.toString() ?? '';
      if (msgSessionId != _sessionId) return;

      if (type == 'aria_call_end') {
        ref.read(ariaCreateSessionProvider.notifier).markCallEnded();
      } else if (type == 'aria_call_error') {
        final msg = data['message']?.toString() ?? 'Unknown error';
        ref.read(ariaCreateSessionProvider.notifier).setErrorMessage(msg);
      } else if (type == 'aria_transcript') {
        final who = data['who']?.toString() ?? 'ARIA';
        final text = data['text']?.toString() ?? '';
        if (text.isNotEmpty) {
          ref.read(ariaTranscriptLinesProvider.notifier).addLine('$who: $text');
        }
      }
    });
  }

  @override
  void dispose() {
    _sessionSub?.close();
    _sessionSub = null;
    _messageSub?.cancel();
    _messageSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(ariaCreateSessionProvider);

    final accountId = NeyvoPulseApi.defaultAccountId;

    return Scaffold(
      appBar: AppBar(title: const Text('Create operator')),
      body: Center(
        child: session.operatorId == null
            ? Padding(
                padding: const EdgeInsets.all(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Let\'s build your operator',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'ARIA will guide you through a 5-8 minute conversation. By the end, you\'ll have an AI operator ready to handle calls for your business.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton.icon(
                        icon: session.isStarting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.mic_none_rounded),
                        onPressed: session.isStarting
                            ? null
                            : () {
                                ref.read(ariaCreateSessionProvider.notifier).startSession();
                              },
                        label: Text(session.isStarting ? 'Starting…' : 'Start conversation with ARIA'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                      ),
                      if (session.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          session.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: _AriaLiveIframe(
                  sessionId: _sessionId,
                  viewType: _viewType,
                  accountId: accountId,
                  operatorId: session.operatorId!,
                  creatorAssistantId: session.ariaCreatorAssistantId!,
                  vapiPublicKey: session.vapiPublicKey!,
                ),
              ),
      ),
    );
  }
}

class _AriaLiveIframe extends StatelessWidget {
  const _AriaLiveIframe({
    required this.sessionId,
    required this.viewType,
    required this.accountId,
    required this.operatorId,
    required this.creatorAssistantId,
    required this.vapiPublicKey,
  });

  final String sessionId;
  final String viewType;
  final String accountId;
  final String operatorId;
  final String creatorAssistantId;
  final String vapiPublicKey;

  @override
  Widget build(BuildContext context) {
    final htmlSrcDoc = AriaVapiSessionIframe.creatorHtml(
      sessionId: sessionId,
      creatorAssistantId: creatorAssistantId,
      publicKey: vapiPublicKey,
      accountId: accountId,
      operatorId: operatorId,
    );
    return AriaIframeView(
      htmlSrcDoc: htmlSrcDoc,
      viewType: viewType,
    );
  }
}

