import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../neyvo_pulse_api.dart';
import '../../screens/pulse_shell.dart';

part 'ub_model_overview_provider.g.dart';

class UbModelOverviewUiState {
  const UbModelOverviewUiState({
    this.loading = true,
    this.error,
    this.status = 'missing',
    this.summary,
    this.departments = const [],
    this.faqTopics = const [],
    this.websiteUrl = 'bridgeport.edu',
  });

  final bool loading;
  final String? error;
  final String status;
  final Map<String, dynamic>? summary;
  final List<dynamic> departments;
  final List<dynamic> faqTopics;
  final String websiteUrl;

  UbModelOverviewUiState copyWith({
    bool? loading,
    String? error,
    String? status,
    Map<String, dynamic>? summary,
    List<dynamic>? departments,
    List<dynamic>? faqTopics,
    String? websiteUrl,
    bool clearError = false,
  }) {
    return UbModelOverviewUiState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      status: status ?? this.status,
      summary: summary ?? this.summary,
      departments: departments ?? this.departments,
      faqTopics: faqTopics ?? this.faqTopics,
      websiteUrl: websiteUrl ?? this.websiteUrl,
    );
  }
}

@riverpod
class UbModelOverviewCtrl extends _$UbModelOverviewCtrl {
  Timer? _pollTimer;

  @override
  UbModelOverviewUiState build() {
    ref.onDispose(() => _pollTimer?.cancel());
    return const UbModelOverviewUiState();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await load();
      final st = state.status.toLowerCase();
      if (st != 'building' && st != 'missing') {
        _pollTimer?.cancel();
      }
    });
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await NeyvoPulseApi.getUbStatus();
      final ok = res['ok'] == true;
      if (!ok) {
        state = state.copyWith(loading: false, error: res['error']?.toString() ?? 'Failed to load status');
        return;
      }
      final status = (res['status'] as String?)?.toLowerCase() ?? 'missing';
      state = state.copyWith(
        loading: false,
        status: status,
        summary: res['summary'] is Map ? Map<String, dynamic>.from(res['summary'] as Map) : null,
        departments: res['departments'] is List ? List<dynamic>.from(res['departments'] as List) : [],
        faqTopics: res['faqTopics'] is List ? List<dynamic>.from(res['faqTopics'] as List) : [],
        error: res['error']?.toString(),
      );
      if (status == 'building') {
        _startPolling();
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> completeAndGoToDashboard(BuildContext context) async {
    try {
      await NeyvoPulseApi.updateAccountInfo({
        'onboarding_completed': true,
        'active_surface': 'comms',
        'surfaces_enabled': ['comms'],
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('neyvo_pulse_onboarding_completed', true);
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const PulseShell()),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> rerunAnalysis() async {
    state = state.copyWith(loading: true);
    try {
      await NeyvoPulseApi.initializeUb(website: 'https://www.bridgeport.edu');
      state = state.copyWith(websiteUrl: 'bridgeport.edu');
      await load();
      if (state.status == 'building') {
        _startPolling();
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}
