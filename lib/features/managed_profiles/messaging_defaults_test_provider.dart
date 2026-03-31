import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'managed_profile_api_service.dart';

part 'messaging_defaults_test_provider.g.dart';

/// UI state for operator Additional settings → test email/SMS sends.
class MessagingTestUiState {
  const MessagingTestUiState({
    required this.operatorId,
    this.emailSending = false,
    this.smsSending = false,
    this.lastEmailMessage,
    this.lastSmsMessage,
    this.lastError,
  });

  final String operatorId;
  final bool emailSending;
  final bool smsSending;
  final String? lastEmailMessage;
  final String? lastSmsMessage;
  final String? lastError;

  MessagingTestUiState copyWith({
    bool? emailSending,
    bool? smsSending,
    String? lastEmailMessage,
    String? lastSmsMessage,
    String? lastError,
    bool clearEmailMessage = false,
    bool clearSmsMessage = false,
    bool clearError = false,
  }) {
    return MessagingTestUiState(
      operatorId: operatorId,
      emailSending: emailSending ?? this.emailSending,
      smsSending: smsSending ?? this.smsSending,
      lastEmailMessage: clearEmailMessage ? null : (lastEmailMessage ?? this.lastEmailMessage),
      lastSmsMessage: clearSmsMessage ? null : (lastSmsMessage ?? this.lastSmsMessage),
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

@riverpod
class MessagingDefaultsTestCtrl extends _$MessagingDefaultsTestCtrl {
  @override
  MessagingTestUiState build(String operatorId) {
    return MessagingTestUiState(operatorId: operatorId);
  }

  Future<void> sendTestEmail({
    required String to,
    Map<String, dynamic>? variables,
    String? memberUserId,
    String? staffId,
    String? studentId,
  }) async {
    state = state.copyWith(emailSending: true, clearError: true, clearEmailMessage: true);
    try {
      final res = await ManagedProfileApiService.testMessagingEmail(
        operatorId,
        to: to,
        variables: variables,
        memberUserId: memberUserId,
        staffId: staffId,
        studentId: studentId,
      );
      final ok = res['ok'] == true;
      final msg = (res['message'] ?? '').toString();
      if (ok) {
        state = state.copyWith(
          emailSending: false,
          lastEmailMessage: msg,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          emailSending: false,
          lastError: msg,
        );
      }
    } catch (e) {
      state = state.copyWith(emailSending: false, lastError: e.toString());
    }
  }

  Future<void> sendTestSms({
    required String to,
    Map<String, dynamic>? variables,
    String? memberUserId,
    String? staffId,
    String? studentId,
  }) async {
    state = state.copyWith(smsSending: true, clearError: true, clearSmsMessage: true);
    try {
      final res = await ManagedProfileApiService.testMessagingSms(
        operatorId,
        to: to,
        variables: variables,
        memberUserId: memberUserId,
        staffId: staffId,
        studentId: studentId,
      );
      final ok = res['ok'] == true;
      final msg = (res['message'] ?? '').toString();
      if (ok) {
        state = state.copyWith(
          smsSending: false,
          lastSmsMessage: msg,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          smsSending: false,
          lastError: msg,
        );
      }
    } catch (e) {
      state = state.copyWith(smsSending: false, lastError: e.toString());
    }
  }

  void clearFeedback() {
    state = state.copyWith(clearEmailMessage: true, clearSmsMessage: true, clearError: true);
  }
}
