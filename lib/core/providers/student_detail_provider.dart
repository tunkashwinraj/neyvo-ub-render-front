import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/spearia_api.dart';
import '../../neyvo_pulse_api.dart';

part 'student_detail_provider.g.dart';

class StudentDetailUiState {
  const StudentDetailUiState({
    this.loading = true,
    this.error,
    this.student,
    this.payments = const [],
    this.calls = const [],
    this.pastCallsSummary = '',
    this.saving = false,
    this.calling = false,
    this.cancelingCallback = false,
    this.agents = const [],
    this.selectedAgentId,
  });

  final bool loading;
  final String? error;
  final Map<String, dynamic>? student;
  final List<dynamic> payments;
  final List<dynamic> calls;
  final String pastCallsSummary;
  final bool saving;
  final bool calling;
  final bool cancelingCallback;
  final List<Map<String, dynamic>> agents;
  final String? selectedAgentId;

  StudentDetailUiState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    Map<String, dynamic>? student,
    List<dynamic>? payments,
    List<dynamic>? calls,
    String? pastCallsSummary,
    bool? saving,
    bool? calling,
    bool? cancelingCallback,
    List<Map<String, dynamic>>? agents,
    String? selectedAgentId,
    bool clearSelectedAgentId = false,
  }) {
    return StudentDetailUiState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      student: student ?? this.student,
      payments: payments ?? this.payments,
      calls: calls ?? this.calls,
      pastCallsSummary: pastCallsSummary ?? this.pastCallsSummary,
      saving: saving ?? this.saving,
      calling: calling ?? this.calling,
      cancelingCallback: cancelingCallback ?? this.cancelingCallback,
      agents: agents ?? this.agents,
      selectedAgentId: clearSelectedAgentId ? null : (selectedAgentId ?? this.selectedAgentId),
    );
  }
}

@riverpod
class StudentDetailCtrl extends _$StudentDetailCtrl {
  @override
  StudentDetailUiState build(String studentId) {
    Future<void>.microtask(load);
    return const StudentDetailUiState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final futures = await Future.wait<dynamic>([
        NeyvoPulseApi.getStudent(studentId),
        NeyvoPulseApi.listPayments(studentId: studentId),
        NeyvoPulseApi.listCalls(studentId: studentId),
        NeyvoPulseApi.listAgents(),
      ]);
      final studentRes = futures[0] as Map<String, dynamic>;
      final paymentsRes = futures[1] as Map<String, dynamic>;
      final callsRes = futures[2] as Map<String, dynamic>;
      final agentsRes = futures[3] as Map<String, dynamic>;

      String pastSummary = '';
      List<dynamic> callsList = callsRes['calls'] as List? ?? const [];
      try {
        final historyRes = await NeyvoPulseApi.getStudentCallHistory(studentId);
        pastSummary = historyRes['past_calls_summary']?.toString() ?? '';
        final historyCalls = historyRes['calls'] as List? ?? const [];
        if (historyCalls.isNotEmpty) callsList = historyCalls;
      } catch (_) {}

      final s = studentRes['student'] as Map<String, dynamic>? ?? const {};
      final agents = (agentsRes['agents'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final selected = state.selectedAgentId ??
          (agents.isNotEmpty ? (agents.first['id'] ?? agents.first['agent_id'])?.toString() : null);

      state = state.copyWith(
        loading: false,
        student: s,
        payments: paymentsRes['payments'] as List? ?? const [],
        calls: callsList,
        pastCallsSummary: pastSummary,
        agents: agents,
        selectedAgentId: selected,
      );
    } catch (e) {
      if (isPulseRequestCancelled(e)) {
        state = state.copyWith(loading: false);
        return;
      }
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setSelectedAgentId(String? id) {
    state = state.copyWith(selectedAgentId: id);
  }

  Future<void> cancelCallback() async {
    state = state.copyWith(cancelingCallback: true);
    try {
      await NeyvoPulseApi.cancelStudentCallback(studentId);
      await load();
      state = state.copyWith(cancelingCallback: false);
    } catch (_) {
      state = state.copyWith(cancelingCallback: false);
      rethrow;
    }
  }

  Future<void> saveStudent({
    required String name,
    String? firstName,
    String? lastName,
    required String phone,
    String? email,
    String? advisorName,
    String? bookingUrl,
    String? balance,
    String? dueDate,
    String? lateFee,
    String? schoolStudentId,
    String? notes,
    Map<String, dynamic>? customFields,
    String? amount,
    String? fundName,
  }) async {
    state = state.copyWith(saving: true);
    try {
      await NeyvoPulseApi.updateStudent(
        studentId,
        name: name,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
        advisorName: advisorName,
        bookingUrl: bookingUrl,
        balance: balance,
        amount: amount,
        fundName: fundName,
        dueDate: dueDate,
        lateFee: lateFee,
        schoolStudentId: schoolStudentId,
        notes: notes,
        customFields: customFields,
      );
      await load();
      state = state.copyWith(saving: false);
    } catch (_) {
      state = state.copyWith(saving: false);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> startCall({
    required String agentId,
    required String studentPhone,
    required String studentName,
    String? balance,
    String? dueDate,
    String? lateFee,
    String? amount,
    String? fundName,
  }) async {
    state = state.copyWith(calling: true);
    try {
      final res = await NeyvoPulseApi.startOutboundCall(
        agentId: agentId,
        studentPhone: studentPhone,
        studentName: studentName,
        studentId: studentId,
        balance: balance,
        amount: amount,
        fundName: fundName,
        dueDate: dueDate,
        lateFee: lateFee,
      );
      await load();
      state = state.copyWith(calling: false);
      return res;
    } on ApiException {
      state = state.copyWith(calling: false);
      rethrow;
    } catch (_) {
      state = state.copyWith(calling: false);
      rethrow;
    }
  }

  Future<void> deleteStudent() => NeyvoPulseApi.deleteStudent(studentId);

  Future<void> addPayment({
    required String amount,
    String? method,
    String? note,
  }) async {
    await NeyvoPulseApi.addPayment(
      studentId: studentId,
      amount: amount,
      method: method,
      note: note,
    );
    await load();
  }
}
