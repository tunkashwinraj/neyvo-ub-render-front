import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';
import '../../ui/screens/ub/ub_model_overview_page.dart';

part 'ub_onboarding_provider.g.dart';

class UbOnboardingUiState {
  const UbOnboardingUiState({
    this.pageIndex = 0,
    this.initializing = false,
    this.initStepIndex = 0,
    this.error,
  });

  final int pageIndex;
  final bool initializing;
  final int initStepIndex;
  final String? error;

  UbOnboardingUiState copyWith({
    int? pageIndex,
    bool? initializing,
    int? initStepIndex,
    String? error,
    bool clearError = false,
  }) {
    return UbOnboardingUiState(
      pageIndex: pageIndex ?? this.pageIndex,
      initializing: initializing ?? this.initializing,
      initStepIndex: initStepIndex ?? this.initStepIndex,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@riverpod
class UbOnboardingCtrl extends _$UbOnboardingCtrl {
  static const List<String> initMessages = [
    'Initializing UB Voice OS…',
    'Analyzing bridgeport.edu…',
    'Building University Model…',
  ];

  @override
  UbOnboardingUiState build() => const UbOnboardingUiState();

  void setPageIndex(int index) {
    state = state.copyWith(pageIndex: index);
  }

  Future<void> initializeAndGoToOverview(BuildContext context, String websiteRaw) async {
    if (state.initializing) return;
    final website = websiteRaw.trim();
    if (website.isEmpty) {
      state = state.copyWith(error: 'Please enter the UB website URL.');
      return;
    }
    state = state.copyWith(initializing: true, initStepIndex: 0, clearError: true);

    for (var i = 0; i < initMessages.length; i++) {
      if (!context.mounted) return;
      state = state.copyWith(initStepIndex: i);
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }

    try {
      final res = await NeyvoPulseApi.initializeUb(website: website);
      if (!context.mounted) return;
      final ok = res['ok'] == true;
      final status = (res['status'] as String?)?.toLowerCase();
      state = state.copyWith(initializing: false);
      if (ok && (status == 'ready' || status == 'building' || status == 'error')) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const UbModelOverviewPage()),
        );
        return;
      }
      state = state.copyWith(error: res['error']?.toString() ?? 'Initialization failed.');
    } catch (e) {
      if (!context.mounted) return;
      state = state.copyWith(initializing: false, error: e.toString());
    }
  }
}
