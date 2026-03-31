// Riverpod state for ARIA Operators UI.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/neyvo_api.dart';
import '../../../core/providers/account_provider.dart';
import '../../../neyvo_pulse_api.dart';
import 'aria_operator_api_service.dart';
import 'aria_operator_models.dart';
import 'vapi_public_key_guard.dart';

final ariaOperatorsListProvider = FutureProvider.autoDispose<List<AriaOperatorCard>>(
  (ref) async {
    final res = await AriaOperatorApiService.startOrGetOperatorsList();
    final raw = res['operators'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((e) => AriaOperatorCard.fromJson(e))
        .toList();
  },
);

final ariaOperatorDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, operatorId) async {
    final res = await AriaOperatorApiService.getOperator(operatorId);
    final op = res['operator'];
    if (op is Map<String, dynamic>) {
      return op;
    }
    return <String, dynamic>{};
  },
);

final operatorMessagingDefaultsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, operatorId) async {
  return AriaOperatorApiService.getMessagingDefaults(operatorId);
});

class AriaCreateSessionState {
  final bool isStarting;
  final bool callEnded;
  final String? operatorId;
  final String? ariaCreatorAssistantId;
  final String? vapiPublicKey;
  final String? errorMessage;

  const AriaCreateSessionState({
    required this.isStarting,
    required this.callEnded,
    required this.operatorId,
    required this.ariaCreatorAssistantId,
    required this.vapiPublicKey,
    required this.errorMessage,
  });

  factory AriaCreateSessionState.idle() => const AriaCreateSessionState(
        isStarting: false,
        callEnded: false,
        operatorId: null,
        ariaCreatorAssistantId: null,
        vapiPublicKey: null,
        errorMessage: null,
      );

  AriaCreateSessionState copyWith({
    bool? isStarting,
    bool? callEnded,
    String? operatorId,
    String? ariaCreatorAssistantId,
    String? vapiPublicKey,
    String? errorMessage,
    bool resetError = false,
  }) {
    return AriaCreateSessionState(
      isStarting: isStarting ?? this.isStarting,
      callEnded: callEnded ?? this.callEnded,
      operatorId: operatorId ?? this.operatorId,
      ariaCreatorAssistantId: ariaCreatorAssistantId ?? this.ariaCreatorAssistantId,
      vapiPublicKey: vapiPublicKey ?? this.vapiPublicKey,
      errorMessage: resetError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AriaCreateSessionController extends StateNotifier<AriaCreateSessionState> {
  AriaCreateSessionController(this.ref) : super(AriaCreateSessionState.idle());
  final Ref ref;

  /// Pulse may not have set [NeyvoPulseApi.defaultAccountId] yet (race with shell load).
  /// Backend POST /initiate-aria-call requires `account_id` in the JSON body.
  Future<void> _ensureAccountIdForAria() async {
    if (NeyvoPulseApi.defaultAccountId.isNotEmpty) return;

    void applyFrom(Map<String, dynamic> r) {
      if (r['ok'] == true) {
        final id = (r['account_id'] ?? r['accountId'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          NeyvoPulseApi.setDefaultAccountId(id);
          NeyvoApi.setDefaultAccountId(id);
        }
      }
    }

    try {
      final res = await ref.read(accountInfoProvider.future);
      applyFrom(res);
    } catch (_) {}

    if (NeyvoPulseApi.defaultAccountId.isNotEmpty) return;

    try {
      final res = await NeyvoPulseApi.getAccountInfo();
      applyFrom(res);
    } catch (_) {}
  }

  Future<void> startSession() async {
    if (state.isStarting) return;
    state = state.copyWith(isStarting: true, resetError: true);
    try {
      await _ensureAccountIdForAria();
      if (NeyvoPulseApi.defaultAccountId.isEmpty) {
        throw Exception(
          'account_id is required but none is loaded yet. '
          'Wait for the app to finish loading your organization, refresh the page, or sign in again. '
          'If this persists, your account may be missing from /api/pulse/account.',
        );
      }
      final res = await AriaOperatorApiService.initiateAriaCall();
      final opId = (res['operator_id'] ?? '').toString();
      final creatorAssistantId = (res['aria_operator_creator_assistant_id'] ?? '').toString();
      final publicKey = (res['vapi_public_key'] ?? '').toString();
      if (opId.isEmpty || creatorAssistantId.isEmpty || publicKey.isEmpty) {
        throw Exception('Backend returned missing session fields');
      }
      if (isPlaceholderVapiPublicKey(publicKey)) {
        throw Exception(
          'Vapi public key is still a placeholder (the text "vapi_public_key"). '
          'In Firestore: businesses/{account}/operators/aria_operator_creator → set field vapi_public_key '
          'to your real public key from the Vapi dashboard (not the field name), or set backend env VAPI_PUBLIC_KEY. '
          'Restart the app after fixing.',
        );
      }
      if (isLikelyMalformedVapiPublicKey(publicKey)) {
        throw Exception(
          'Vapi public key format is invalid for web calls. '
          'Save only the raw Vapi public key (no quotes/spaces/newlines) in '
          'Firestore businesses/{account}/operators/aria_operator_creator or backend env VAPI_PUBLIC_KEY.',
        );
      }
      state = state.copyWith(
        isStarting: false,
        operatorId: opId,
        ariaCreatorAssistantId: creatorAssistantId,
        vapiPublicKey: publicKey,
      );
    } catch (e) {
      state = state.copyWith(
        isStarting: false,
        errorMessage: e.toString(),
      );
    }
  }

  void markCallEnded() {
    if (!state.callEnded) {
      state = state.copyWith(callEnded: true);
    }
  }

  void setErrorMessage(String message) {
    state = state.copyWith(
      isStarting: false,
      errorMessage: message,
    );
  }
}

final ariaCreateSessionProvider =
    StateNotifierProvider<AriaCreateSessionController, AriaCreateSessionState>(
  (ref) => AriaCreateSessionController(ref),
);

class OperatorBuildStatusController extends StateNotifier<AsyncValue<AriaOperatorStatus>> {
  OperatorBuildStatusController(this.ref, this.operatorId) : super(const AsyncValue.loading());

  final Ref ref;
  final String operatorId;
  Timer? _timer;

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final res = await AriaOperatorApiService.getOperatorStatus(operatorId);
        final statusJson = res is Map<String, dynamic> ? res : <String, dynamic>{'status': res};
        final status = AriaOperatorStatus.fromJson(statusJson);
        state = AsyncValue.data(status);
        if (status.status == 'live' || status.status == 'error') {
          _timer?.cancel();
          _timer = null;
        }
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

final ariaOperatorBuildStatusProvider =
    StateNotifierProvider.autoDispose.family<OperatorBuildStatusController, AsyncValue<AriaOperatorStatus>, String>(
  (ref, operatorId) {
    final c = OperatorBuildStatusController(ref, operatorId);
    // Start immediately after provider creation.
    scheduleMicrotask(() => c.startPolling());
    return c;
  },
);

class SessionTimerController extends StateNotifier<int> {
  SessionTimerController() : super(0);
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state + 1;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

final sessionTimerProvider = StateNotifierProvider.autoDispose<SessionTimerController, int>(
  (ref) => SessionTimerController(),
);

final ariaTranscriptLinesProvider =
    StateNotifierProvider.autoDispose<AriaTranscriptLinesController, List<String>>(
  (ref) => AriaTranscriptLinesController(),
);

class AriaTranscriptLinesController extends StateNotifier<List<String>> {
  AriaTranscriptLinesController() : super(const []);

  void addLine(String line) {
    state = [...state, line];
  }

  /// Replaces the last line when [who]'s text is still growing (partial ASR/TTS
  /// chunks); appends when the speaker changes or a new utterance starts.
  void addOrUpdateStreamingTranscript(String who, String text) {
    final prefix = '$who: ';
    if (state.isNotEmpty) {
      final last = state.last;
      if (last.startsWith(prefix)) {
        final prevBody = last.substring(prefix.length);
        if (text.startsWith(prevBody) || prevBody.startsWith(text)) {
          state = [...state.sublist(0, state.length - 1), '$prefix$text'];
          return;
        }
      }
    }
    state = [...state, '$prefix$text'];
  }
}

