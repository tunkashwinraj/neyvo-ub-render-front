import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../neyvo_pulse_api.dart';
import '../../../pulse_route_names.dart';
import 'aria_operator_providers.dart';
import 'aria_vapi_bridge.dart';
import 'aria_vapi_iframe.dart';

// Screen: /operators/new
class OperatorsCreateScreen extends ConsumerStatefulWidget {
  const OperatorsCreateScreen({super.key});

  @override
  ConsumerState<OperatorsCreateScreen> createState() => _OperatorsCreateScreenState();
}

class _OperatorsCreateScreenState extends ConsumerState<OperatorsCreateScreen> {
  ProviderSubscription<AriaCreateSessionState>? _sessionSub;
  late final String _sessionId = AriaVapiSessionIframe.createSessionId();

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
  }

  @override
  void dispose() {
    _sessionSub?.close();
    _sessionSub = null;
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
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (session.errorMessage != null)
                    Material(
                      color: Colors.red.shade900.withValues(alpha: 0.92),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade100, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SelectableText(
                                session.errorMessage!,
                                style: TextStyle(color: Colors.red.shade50, height: 1.35, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: kIsWeb
                        ? _AriaCreatorCallPanel(
                            sessionId: _sessionId,
                            accountId: accountId,
                            operatorId: session.operatorId!,
                            creatorAssistantId: session.ariaCreatorAssistantId!,
                            vapiPublicKey: session.vapiPublicKey!,
                          )
                        : const _AriaNonWebPlaceholder(),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AriaNonWebPlaceholder extends StatelessWidget {
  const _AriaNonWebPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.web_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'ARIA voice creation runs in the browser',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Open Neyvo Pulse in Chrome or Edge (Flutter web) to continue with the microphone and Vapi assistant.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AriaCreatorCallPanel extends ConsumerStatefulWidget {
  const _AriaCreatorCallPanel({
    required this.sessionId,
    required this.accountId,
    required this.operatorId,
    required this.creatorAssistantId,
    required this.vapiPublicKey,
  });

  final String sessionId;
  final String accountId;
  final String operatorId;
  final String creatorAssistantId;
  final String vapiPublicKey;

  @override
  ConsumerState<_AriaCreatorCallPanel> createState() => _AriaCreatorCallPanelState();
}

class _AriaCreatorCallPanelState extends ConsumerState<_AriaCreatorCallPanel> {
  bool _connecting = false;
  bool _callActive = false;
  bool _muted = false;
  String? _inlineStatus;

  @override
  void dispose() {
    ariaVapiBridgeStop();
    super.dispose();
  }

  void _navigateToAriaError(String msg) {
    if (!mounted) return;
    ref.read(ariaCreateSessionProvider.notifier).setErrorMessage(msg);
    final nav = Navigator.of(context, rootNavigator: true);
    final route = ModalRoute.of(context);
    final inDialog = route is DialogRoute || route is RawDialogRoute;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (inDialog && nav.canPop()) {
        nav.pop();
      }
      if (inDialog) {
        nav.pushNamed(PulseRouteNames.operatorsAriaError, arguments: msg);
      } else {
        nav.pushReplacementNamed(PulseRouteNames.operatorsAriaError, arguments: msg);
      }
    });
  }

  void _onBridgeEvent(String type, Map<String, dynamic>? d) {
    if (!mounted) return;
    switch (type) {
      case 'transcript':
        final who = d?['who']?.toString() ?? 'ARIA';
        final text = d?['text']?.toString() ?? '';
        if (text.isNotEmpty) {
          ref.read(ariaTranscriptLinesProvider.notifier).addOrUpdateStreamingTranscript(who, text);
        }
        break;
      case 'call-end':
        ref.read(ariaCreateSessionProvider.notifier).markCallEnded();
        setState(() {
          _callActive = false;
        });
        break;
      case 'call-start':
        setState(() {
          _callActive = true;
          _inlineStatus = null;
        });
        break;
      case 'error':
        final msg = d?['message']?.toString() ?? 'Unknown error';
        _navigateToAriaError(msg);
        break;
      default:
        break;
    }
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _inlineStatus = 'Preparing microphone and Vapi…';
    });
    try {
      await ariaVapiBridgeStart(
        publicKey: widget.vapiPublicKey,
        assistantId: widget.creatorAssistantId,
        sessionId: widget.sessionId,
        accountId: widget.accountId,
        operatorId: widget.operatorId,
        onEvent: _onBridgeEvent,
      );
      if (mounted) {
        setState(() {
          _connecting = false;
          // Active state is set from onEvent('call-start'), not when the bridge call returns.
          _inlineStatus = null;
        });
      }
    } catch (e, st) {
      debugPrint('ariaVapiBridgeStart failed: $e\n$st');
      if (mounted) {
        setState(() {
          _connecting = false;
          _inlineStatus = e.toString();
        });
        _navigateToAriaError(e.toString());
      }
    }
  }

  void _toggleMute() {
    final next = !_muted;
    setState(() => _muted = next);
    ariaVapiBridgeSetMuted(next);
  }

  Future<void> _endSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End session?'),
        content: const Text('Your operator draft will move to the building step. You can stop the voice session now.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('End session')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    ariaVapiBridgeStop();
    ref.read(ariaCreateSessionProvider.notifier).markCallEnded();
    setState(() {
      _callActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(ariaTranscriptLinesProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ARIA session',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the button below in this page (same tab) so the browser can use your microphone and play assistant audio.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    if (!_callActive) ...[
                      FilledButton.icon(
                        onPressed: _connecting ? null : _connect,
                        icon: _connecting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.mic_rounded),
                        label: Text(_connecting ? 'Connecting…' : 'Connect microphone & start ARIA'),
                      ),
                      if (_inlineStatus != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _inlineStatus!,
                          style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                        ),
                      ],
                    ] else ...[
                      Row(
                        children: [
                          Icon(Icons.record_voice_over_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Call active — speak naturally; ARIA will ask short questions.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _toggleMute,
                            child: Text(_muted ? 'Unmute' : 'Mute'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                            onPressed: _endSession,
                            child: const Text('End session'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Live transcript', style: theme.textTheme.labelLarge),
                        Text('${lines.length} lines', style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: lines.isEmpty
                        ? Center(
                            child: Text(
                              'Transcripts appear here after you connect.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: lines.length,
                            itemBuilder: (context, i) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SelectableText(
                                  lines[i],
                                  style: const TextStyle(fontSize: 13, height: 1.35),
                                ),
                              );
                            },
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
