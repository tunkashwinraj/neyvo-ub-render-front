import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/managed_profiles/managed_profile_api_service.dart';
import '../../neyvo_pulse_api.dart';
import '../../utils/phone_util.dart';

part 'dialer_page_provider.g.dart';

enum DialerOverlayState { connecting, listening, processing, speaking, success, error }

class DialerUiState {
  const DialerUiState({
    this.loading = true,
    this.error,
    this.capacity,
    this.agents = const [],
    this.selectedAgentId,
    this.numbers = const [],
    this.selectedNumberId,
    this.numberCapacity,
    this.students = const [],
    this.selectedStudentId,
    this.starting = false,
    this.overlay,
  });

  final bool loading;
  final String? error;
  final Map<String, dynamic>? capacity;
  final List<Map<String, dynamic>> agents;
  final String? selectedAgentId;
  final List<Map<String, dynamic>> numbers;
  final String? selectedNumberId;
  final Map<String, dynamic>? numberCapacity;
  final List<Map<String, dynamic>> students;
  final String? selectedStudentId;
  final bool starting;
  final DialerOverlayState? overlay;

  DialerUiState copyWith({
    bool? loading,
    String? error,
    Map<String, dynamic>? capacity,
    List<Map<String, dynamic>>? agents,
    String? selectedAgentId,
    List<Map<String, dynamic>>? numbers,
    String? selectedNumberId,
    Map<String, dynamic>? numberCapacity,
    List<Map<String, dynamic>>? students,
    String? selectedStudentId,
    bool? starting,
    DialerOverlayState? overlay,
    bool clearError = false,
    bool clearOverlay = false,
    bool clearNumberCapacity = false,
  }) {
    return DialerUiState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      capacity: capacity ?? this.capacity,
      agents: agents ?? this.agents,
      selectedAgentId: selectedAgentId ?? this.selectedAgentId,
      numbers: numbers ?? this.numbers,
      selectedNumberId: selectedNumberId ?? this.selectedNumberId,
      numberCapacity: clearNumberCapacity ? null : (numberCapacity ?? this.numberCapacity),
      students: students ?? this.students,
      selectedStudentId: selectedStudentId ?? this.selectedStudentId,
      starting: starting ?? this.starting,
      overlay: clearOverlay ? null : (overlay ?? this.overlay),
    );
  }
}

@riverpod
class DialerPageCtrl extends _$DialerPageCtrl {
  @override
  DialerUiState build() => const DialerUiState();

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        NeyvoPulseApi.getOutboundCapacity(),
        ManagedProfileApiService.listProfiles(),
        NeyvoPulseApi.listNumbers(),
        NeyvoPulseApi.listStudents().catchError((_) => <String, dynamic>{'students': []}),
      ]);
      final cap = results[0] as Map<String, dynamic>;
      final prof = results[1] as Map<String, dynamic>;
      final nums = results[2] as Map<String, dynamic>;
      final studentsRes = results[3] as Map<String, dynamic>;
      final list = (prof['profiles'] as List?)?.cast<dynamic>() ?? const [];
      final agents = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final first = agents.isNotEmpty ? (agents.first['profile_id']?.toString()) : null;
      final rawNums = (nums['numbers'] as List?)?.cast<dynamic>() ?? const [];
      final numbers = rawNums.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final firstNum = numbers.isNotEmpty
          ? (numbers.first['phone_number_id'] ?? numbers.first['number_id'] ?? numbers.first['id'])?.toString()
          : null;
      final rawStudents = (studentsRes['students'] as List?)?.cast<dynamic>() ?? const [];
      final students = rawStudents.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      state = state.copyWith(
        loading: false,
        capacity: cap,
        agents: agents,
        selectedAgentId: state.selectedAgentId ?? first,
        numbers: numbers,
        selectedNumberId: state.selectedNumberId ?? firstNum,
        students: students,
      );
      await loadNumberCapacity();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadNumberCapacity() async {
    final id = (state.selectedNumberId ?? '').trim();
    if (id.isEmpty) {
      state = state.copyWith(clearNumberCapacity: true);
      return;
    }
    try {
      final cap = await NeyvoPulseApi.getNumberCapacity(id);
      state = state.copyWith(numberCapacity: cap);
    } catch (_) {}
  }

  void setSelectedAgentId(String? v) {
    state = state.copyWith(selectedAgentId: v);
  }

  Future<void> setSelectedNumberId(String? v) async {
    state = state.copyWith(selectedNumberId: v, clearNumberCapacity: true);
    await loadNumberCapacity();
  }

  void setSelectedStudentId(String? v) {
    state = state.copyWith(selectedStudentId: v);
  }

  Future<void> animateOverlay() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (state.overlay != DialerOverlayState.connecting) return;
    state = state.copyWith(overlay: DialerOverlayState.listening);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (state.overlay != DialerOverlayState.listening) return;
    state = state.copyWith(overlay: DialerOverlayState.processing);
  }

  Future<void> startCall(
    BuildContext context, {
    required String contactPhoneRaw,
    required String contactName,
    required String structuredContext,
  }) async {
    final agentId = (state.selectedAgentId ?? '').trim();
    final numberId = (state.selectedNumberId ?? '').trim();
    final phone = normalizeToE164Us(contactPhoneRaw.trim());
    if (agentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an agent.')));
      return;
    }
    if (numberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a number.')));
      return;
    }
    if (phone.isEmpty || !RegExp(r'^\+[0-9]{8,15}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Enter a valid US phone (e.g. 123-456-7890, (123) 456-7890, +12035551234).',
        ),
      ));
      return;
    }

    try {
      final wallet = await NeyvoPulseApi.getBillingWallet();
      final credits = (wallet['credits'] as num?)?.toInt() ??
          (wallet['wallet_credits'] as num?)?.toInt() ??
          0;
      if (credits <= 0) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient credits. Add credits to start a call.')),
        );
        return;
      }
    } catch (_) {}

    final remaining = (state.capacity?['remaining_today'] as num?)?.toInt();
    if (remaining != null && remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No remaining outbound capacity today.')),
      );
      return;
    }
    try {
      final cap = await NeyvoPulseApi.getNumberCapacity(numberId);
      final nRemaining = (cap['remaining_today'] as num?)?.toInt();
      final warning = cap['warning'] == true;
      if (nRemaining != null && nRemaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected number reached its daily cap. Choose another number.')),
        );
        return;
      }
      if (warning) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warm-up / carrier risk warning for this number. Consider using another number.')),
        );
      }
    } catch (_) {}

    state = state.copyWith(starting: true, overlay: DialerOverlayState.connecting);
    unawaited(animateOverlay());

    try {
      final overrides = <String, dynamic>{};
      final name = contactName.trim();
      if (name.isNotEmpty) overrides['clientName'] = name;
      final ctx = structuredContext.trim();
      if (ctx.isNotEmpty) overrides['context'] = ctx;
      overrides['phone_number_id'] = numberId;

      await ManagedProfileApiService.makeOutboundCall(
        profileId: agentId,
        customerPhone: phone,
        studentId: (state.selectedStudentId ?? '').trim().isEmpty ? null : state.selectedStudentId,
        overrides: overrides,
      );

      state = state.copyWith(starting: false, overlay: DialerOverlayState.speaking);
      await Future<void>.delayed(const Duration(seconds: 2));
      state = state.copyWith(overlay: DialerOverlayState.success);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      state = state.copyWith(clearOverlay: true);
    } catch (e) {
      state = state.copyWith(starting: false, overlay: DialerOverlayState.error);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      state = state.copyWith(clearOverlay: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start call: $e')));
      }
    }
  }
}
