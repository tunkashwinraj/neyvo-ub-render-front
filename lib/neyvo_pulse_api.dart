// lib/neyvo_pulse/neyvo_pulse_api.dart
// Neyvo Pulse – API client.

import '../api/spearia_api.dart';

const String _defaultSchoolId = 'default-school';

class NeyvoPulseApi {
  static String get defaultSchoolId => _defaultSchoolId;

  static Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? params}) async {
    final p = Map<String, dynamic>.from(params ?? {});
    p['school_id'] = p['school_id'] ?? _defaultSchoolId;
    return SpeariaApi.getJsonMap(path, params: p);
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    body['school_id'] = body['school_id'] ?? _defaultSchoolId;
    return SpeariaApi.postJsonMap(path, body: body);
  }

  static Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    body['school_id'] = body['school_id'] ?? _defaultSchoolId;
    final v = await SpeariaApi.patchJson(path, body: body);
    return Map<String, dynamic>.from(v as Map);
  }

  static Future<Map<String, dynamic>> health() async =>
      SpeariaApi.getJsonMap('/api/pulse/health');

  // Students
  static Future<Map<String, dynamic>> listStudents() async =>
      _get('/api/pulse/students');

  static Future<Map<String, dynamic>> getStudent(String studentId) async =>
      _get('/api/pulse/students/$studentId');

  static Future<Map<String, dynamic>> createStudent({
    required String name,
    required String phone,
    String? email,
    String? balance,
    String? dueDate,
    String? lateFee,
    String? notes,
  }) async =>
      _post('/api/pulse/students', {
        'name': name,
        'phone': phone,
        if (email != null) 'email': email,
        if (balance != null) 'balance': balance,
        if (dueDate != null) 'due_date': dueDate,
        if (lateFee != null) 'late_fee': lateFee,
        if (notes != null) 'notes': notes,
      });

  static Future<Map<String, dynamic>> updateStudent(
    String studentId, {
    String? name,
    String? phone,
    String? email,
    String? balance,
    String? dueDate,
    String? lateFee,
    String? notes,
  }) async =>
      _patch('/api/pulse/students/$studentId', {
        'student_id': studentId,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (balance != null) 'balance': balance,
        if (dueDate != null) 'due_date': dueDate,
        if (lateFee != null) 'late_fee': lateFee,
        if (notes != null) 'notes': notes,
      });

  static Future<void> deleteStudent(String studentId) async {
    await SpeariaApi.deleteJson(
      '/api/pulse/students/$studentId',
      params: <String, dynamic>{'school_id': _defaultSchoolId},
    );
  }

  // Payments
  static Future<Map<String, dynamic>> listPayments({String? studentId}) async =>
      _get('/api/pulse/payments', params: studentId != null ? {'student_id': studentId} : null);

  static Future<Map<String, dynamic>> addPayment({
    required String studentId,
    required String amount,
    String? method,
    String? note,
  }) async =>
      _post('/api/pulse/payments', {
        'student_id': studentId,
        'amount': amount,
        if (method != null) 'method': method,
        if (note != null) 'note': note,
      });

  // Reminders
  static Future<Map<String, dynamic>> listReminders({String? studentId}) async =>
      _get('/api/pulse/reminders', params: studentId != null ? {'student_id': studentId} : null);

  static Future<Map<String, dynamic>> createReminder({
    required String studentId,
    String? reminderType,
    String? scheduledAt,
    String? message,
  }) async =>
      _post('/api/pulse/reminders', {
        'student_id': studentId,
        if (reminderType != null) 'reminder_type': reminderType,
        if (scheduledAt != null) 'scheduled_at': scheduledAt,
        if (message != null) 'message': message,
      });

  // Calls
  static Future<Map<String, dynamic>> listCalls({String? studentId}) async =>
      _get('/api/pulse/calls', params: studentId != null ? {'student_id': studentId} : null);

  /// Phase D: Resolution/success summary for dashboard
  static Future<Map<String, dynamic>> getCallsSuccessSummary() async =>
      _get('/api/pulse/calls/success-summary');

  // Knowledge (Phase C: training – FAQ + policy)
  static Future<Map<String, dynamic>> getKnowledgePolicy() async =>
      _get('/api/pulse/knowledge/policy');

  static Future<Map<String, dynamic>> updateKnowledgePolicy({
    String? paymentPolicy,
    String? lateFeePolicy,
    String? contactInfo,
    String? defaultDueDays,
    String? notes,
  }) async =>
      _patch('/api/pulse/knowledge/policy', {
        if (paymentPolicy != null) 'payment_policy': paymentPolicy,
        if (lateFeePolicy != null) 'late_fee_policy': lateFeePolicy,
        if (contactInfo != null) 'contact_info': contactInfo,
        if (defaultDueDays != null) 'default_due_days': defaultDueDays,
        if (notes != null) 'notes': notes,
      });

  static Future<Map<String, dynamic>> listKnowledgeFaq() async =>
      _get('/api/pulse/knowledge/faq');

  static Future<Map<String, dynamic>> addKnowledgeFaq({
    required String question,
    required String answer,
    int? order,
  }) async =>
      _post('/api/pulse/knowledge/faq', {
        'question': question,
        'answer': answer,
        if (order != null) 'order': order,
      });

  static Future<Map<String, dynamic>> updateKnowledgeFaq(
    String faqId, {
    String? question,
    String? answer,
    int? order,
  }) async =>
      _patch('/api/pulse/knowledge/faq/$faqId', {
        if (question != null) 'question': question,
        if (answer != null) 'answer': answer,
        if (order != null) 'order': order,
      });

  static Future<void> deleteKnowledgeFaq(String faqId) async {
    await SpeariaApi.deleteJson(
      '/api/pulse/knowledge/faq/$faqId',
      params: <String, dynamic>{'school_id': _defaultSchoolId},
    );
  }

  /// Phase D: Audit log (who viewed/edited what)
  static Future<Map<String, dynamic>> getAuditLog({
    String? resource,
    int limit = 100,
  }) async =>
      _get(
        '/api/pulse/audit-log',
        params: <String, dynamic>{
          if (resource != null) 'resource': resource,
          'limit': limit,
        },
      );

  /// Phase D RBAC: list members and their roles
  static Future<Map<String, dynamic>> listMembers() async =>
      _get('/api/pulse/members');

  /// Phase D RBAC: set role for a member (admin only)
  static Future<Map<String, dynamic>> setMemberRole(String userId, String role) async =>
      _patch('/api/pulse/members/$userId', {'role': role});

  /// Phase D RBAC: get current user's role
  static Future<Map<String, dynamic>> getMyRole() async =>
      _get('/api/pulse/members/me');

  static Future<Map<String, dynamic>> startOutboundCall({
    required String studentPhone,
    required String studentName,
    String? studentId,
    String? phoneNumberId,
    String? balance,
    String? dueDate,
    String? lateFee,
    String? schoolName,
  }) async {
    final body = <String, dynamic>{
      'business_id': _defaultSchoolId,
      'student_phone': studentPhone,
      'student_name': studentName,
      'message_type': 'balance_reminder',
    };
    if (studentId != null) body['student_id'] = studentId;
    if (phoneNumberId != null) body['phone_number_id'] = phoneNumberId;
    if (balance != null) body['balance'] = balance;
    if (dueDate != null) body['due_date'] = dueDate;
    if (lateFee != null) body['late_fee'] = lateFee;
    if (schoolName != null) body['school_name'] = schoolName;
    return SpeariaApi.postJsonMap('/api/pulse/outbound/call', body: body);
  }

  // Settings
  static Future<Map<String, dynamic>> getSettings() async =>
      _get('/api/pulse/settings');

  static Future<Map<String, dynamic>> updateSettings({
    String? schoolName,
    String? defaultLateFee,
    String? currency,
  }) async =>
      _patch('/api/pulse/settings', {
        if (schoolName != null) 'school_name': schoolName,
        if (defaultLateFee != null) 'default_late_fee': defaultLateFee,
        if (currency != null) 'currency': currency,
      });

  // Reports
  static Future<Map<String, dynamic>> reportsSummary() async =>
      _get('/api/pulse/reports/summary');

  // AI Insights (optional backend endpoint; falls back to deriving from calls)
  static Future<Map<String, dynamic>> getInsights() async {
    try {
      return await _get('/api/pulse/insights');
    } catch (_) {
      return {};
    }
  }
}
