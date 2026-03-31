import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../neyvo_pulse_api.dart';
import '../../screens/pulse_shell.dart';
import '../../ui/screens/business_interview/business_setup_interview_page.dart';

part 'onboarding_flow_provider.g.dart';

const String kOnboardingCompletedPrefsKey = 'neyvo_pulse_onboarding_completed';

class OnboardingFlowUiState {
  const OnboardingFlowUiState({
    this.pageIndex = 0,
    this.initializing = false,
    this.initStepIndex = 0,
    this.error,
  });

  final int pageIndex;
  final bool initializing;
  final int initStepIndex;
  final String? error;

  OnboardingFlowUiState copyWith({
    int? pageIndex,
    bool? initializing,
    int? initStepIndex,
    String? error,
    bool clearError = false,
  }) {
    return OnboardingFlowUiState(
      pageIndex: pageIndex ?? this.pageIndex,
      initializing: initializing ?? this.initializing,
      initStepIndex: initStepIndex ?? this.initStepIndex,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@riverpod
class OnboardingFlowCtrl extends _$OnboardingFlowCtrl {
  static const List<String> initMessages = [
    'Initializing Neyvo Voice OS…',
    'Loading voice engine…',
    'Preparing routing layer…',
    'Calibrating business intelligence…',
  ];

  @override
  OnboardingFlowUiState build() => const OnboardingFlowUiState();

  void setPageIndex(int index) {
    state = state.copyWith(pageIndex: index);
  }

  Future<void> completeOnboarding(BuildContext context) async {
    try {
      final body = <String, dynamic>{
        'onboarding_completed': true,
        'active_surface': 'comms',
        'surfaces_enabled': ['comms'],
      };
      await NeyvoPulseApi.updateAccountInfo(body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOnboardingCompletedPrefsKey, true);
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const PulseShell()),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      state = state.copyWith(error: e.toString(), initializing: false);
    }
  }

  Future<void> startInitializationAndInterview(BuildContext context) async {
    if (state.initializing) {
      return;
    }
    state = state.copyWith(initializing: true, initStepIndex: 0, clearError: true);

    try {
      for (var i = 0; i < initMessages.length; i++) {
        if (!context.mounted) {
          return;
        }
        state = state.copyWith(initStepIndex: i);
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }

      if (!context.mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const BusinessSetupInterviewPage()),
      );

      if (!context.mounted) {
        return;
      }
      await completeOnboarding(context);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      state = state.copyWith(initializing: false, error: e.toString());
    }
  }
}
