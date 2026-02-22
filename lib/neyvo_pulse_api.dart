// lib/neyvo_pulse/neyvo_pulse_api.dart
// Neyvo Pulse – API client. All data is keyed by business_id (clients are businesses).

import '../api/spearia_api.dart';

const String _defaultBusinessId = 'default-school';

class NeyvoPulseApi {
  static String get defaultBusinessId => _defaultBusinessId;

  static Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? params}) async {
    final p = Map<String, dynamic>.from(params ?? {});
    p['business_id'] = p['business_id'] ?? _defaultBusinessId;
    return SpeariaApi.getJsonMap(path, params: p);
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    body['business_id'] = body['business_id'] ?? _defaultBusinessId;
    return SpeariaApi.postJsonMap(path, body: body);
  }

  static Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    body['business_id'] = body['business_id'] ?? _defaultBusinessId;
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
      params: <String, dynamic>{'business_id': _defaultBusinessId},
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
      params: <String, dynamic>{'business_id': _defaultBusinessId},
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
    String? numberId,
    String? balance,
    String? dueDate,
    String? lateFee,
    String? schoolName,
  }) async {
    final body = <String, dynamic>{
      'business_id': _defaultBusinessId,
      'student_phone': studentPhone,
      'student_name': studentName,
      'message_type': 'balance_reminder',
    };
    if (studentId != null) body['student_id'] = studentId;
    if (phoneNumberId != null) body['phone_number_id'] = phoneNumberId;
    if (numberId != null) body['number_id'] = numberId;
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

  // -------------------------------------------------------------------------
  // Data integration (school DB → Firestore: webhook, CSV, API pull)
  // -------------------------------------------------------------------------

  /// GET integration config (modes, webhook_secret_set, api_pull_url, field_mapping, last_sync_at)
  static Future<Map<String, dynamic>> getIntegrationConfig() async =>
      _get('/api/pulse/integration/config');

  /// PUT/PATCH integration config (admin). Pass only fields to update.
  static Future<Map<String, dynamic>> setIntegrationConfig({
    bool? enabled,
    List<String>? modes,
    String? webhookSecret,
    String? apiPullUrl,
    Map<String, String>? apiPullHeaders,
    Map<String, String>? fieldMapping,
  }) async {
    final body = <String, dynamic>{};
    if (enabled != null) body['enabled'] = enabled;
    if (modes != null) body['modes'] = modes;
    if (webhookSecret != null) body['webhook_secret'] = webhookSecret;
    if (apiPullUrl != null) body['api_pull_url'] = apiPullUrl;
    if (apiPullHeaders != null) body['api_pull_headers'] = apiPullHeaders;
    if (fieldMapping != null) body['field_mapping'] = fieldMapping;
    return _patch('/api/pulse/integration/config', body);
  }

  /// Ingest CSV (admin/staff). Pass CSV string in body.
  static Future<Map<String, dynamic>> ingestCsv({
    required String csv,
    String? encoding,
  }) async =>
      _post('/api/pulse/integration/ingest/csv', {
        'csv': csv,
        if (encoding != null) 'encoding': encoding,
      });

  /// Trigger API pull sync for the school (admin/staff).
  static Future<Map<String, dynamic>> triggerIntegrationSync() async =>
      _post('/api/pulse/integration/sync', {});

  // -------------------------------------------------------------------------
  // Call templates (scripts for assistant)
  // -------------------------------------------------------------------------

  /// List call templates for the school.
  static Future<Map<String, dynamic>> listCallTemplates() async {
    try {
      return await _get('/api/pulse/call_templates');
    } catch (_) {
      return {'templates': []};
    }
  }

  /// Create a call template (name, body/script with placeholders).
  static Future<Map<String, dynamic>> createCallTemplate({
    required String name,
    required String body,
  }) async =>
      _post('/api/pulse/call_templates', {'name': name, 'body': body});

  /// Update a call template.
  static Future<Map<String, dynamic>> updateCallTemplate(
    String id, {
    String? name,
    String? body,
  }) async {
    final b = <String, dynamic>{};
    if (name != null) b['name'] = name;
    if (body != null) b['body'] = body;
    return _patch('/api/pulse/call_templates/$id', b);
  }

  /// Delete a call template.
  static Future<void> deleteCallTemplate(String id) async =>
      SpeariaApi.deleteJson('/api/pulse/call_templates/$id', params: {'business_id': _defaultBusinessId});

  // -------------------------------------------------------------------------
  // Campaigns (bulk outbound calls by filters)
  // -------------------------------------------------------------------------

  /// List campaigns for the school.
  static Future<Map<String, dynamic>> listCampaigns() async {
    try {
      return await _get('/api/pulse/campaigns');
    } catch (_) {
      return {'campaigns': []};
    }
  }

  /// Get a single campaign by id (full details).
  static Future<Map<String, dynamic>> getCampaign(String campaignId) async =>
      _get('/api/pulse/campaigns/$campaignId');

  /// List calls placed for a campaign.
  static Future<Map<String, dynamic>> getCampaignCalls(String campaignId, {int limit = 100}) async =>
      _get('/api/pulse/campaigns/$campaignId/calls', params: {'limit': limit});

  /// Create a campaign (name, audience filters or student_ids, template_id, scheduled_at).
  static Future<Map<String, dynamic>> createCampaign({
    required String name,
    String? templateId,
    List<String>? studentIds,
    Map<String, dynamic>? filters,
    DateTime? scheduledAt,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      if (templateId != null) 'template_id': templateId,
      if (studentIds != null) 'student_ids': studentIds,
      if (filters != null) 'filters': filters,
      if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
    };
    return _post('/api/pulse/campaigns', body);
  }

  /// Update campaign (name, template_id, student_ids, filters, scheduled_at). Only when status is draft or scheduled.
  static Future<Map<String, dynamic>> updateCampaign(
    String campaignId, {
    String? name,
    String? templateId,
    List<String>? studentIds,
    Map<String, dynamic>? filters,
    DateTime? scheduledAt,
  }) async {
    final body = <String, dynamic>{'business_id': _defaultBusinessId};
    if (name != null) body['name'] = name;
    if (templateId != null) body['template_id'] = templateId;
    if (studentIds != null) body['student_ids'] = studentIds;
    if (filters != null) body['filters'] = filters;
    if (scheduledAt != null) body['scheduled_at'] = scheduledAt.toIso8601String();
    return _patch('/api/pulse/campaigns/$campaignId', body);
  }

  /// Start a campaign (places outbound calls sequentially; may take a while). Can rerun completed campaigns.
  static Future<Map<String, dynamic>> startCampaign(String campaignId) async {
    final body = <String, dynamic>{'business_id': _defaultBusinessId};
    return SpeariaApi.postJsonMap(
      '/api/pulse/campaigns/$campaignId/start',
      body: body,
      timeout: const Duration(seconds: 120),
    );
  }

  // -------------------------------------------------------------------------
  // Billing (wallet, tier, usage)
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getBillingWallet() async =>
      _get('/api/billing/wallet');

  /// Create Stripe Checkout session for wallet pack. Returns { url }. Open url in browser to pay; credits applied via webhook.
  static Future<Map<String, dynamic>> createCheckoutSession(
    String pack, {
    String? successUrl,
    String? cancelUrl,
    String? customerEmail,
  }) async {
    final body = <String, dynamic>{
      'business_id': _defaultBusinessId,
      'pack': pack,
    };
    if (successUrl != null) body['success_url'] = successUrl;
    if (cancelUrl != null) body['cancel_url'] = cancelUrl;
    if (customerEmail != null) body['customer_email'] = customerEmail;
    return SpeariaApi.postJsonMap('/api/billing/wallet/create-checkout-session', body: body);
  }

  static Future<Map<String, dynamic>> purchaseCredits(String pack) async =>
      SpeariaApi.postJsonMap('/api/billing/wallet/purchase', body: {
        'business_id': _defaultBusinessId,
        'pack': pack,
      });

  static Future<Map<String, dynamic>> getBillingTransactions({
    int limit = 50,
    int offset = 0,
    String type = 'all',
  }) async =>
      _get('/api/billing/transactions', params: {
        'limit': limit,
        'offset': offset,
        'type': type,
      });

  static Future<Map<String, dynamic>> getBillingUsage({
    String? from,
    String? to,
  }) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return _get('/api/billing/usage', params: params.isEmpty ? null : params);
  }

  static Future<Map<String, dynamic>> getBillingTier() async =>
      _get('/api/billing/tier');

  static Future<Map<String, dynamic>> setBillingTier(String tier) async {
    final v = await SpeariaApi.putJson('/api/billing/tier', body: {
      'business_id': _defaultBusinessId,
      'tier': tier,
    });
    return Map<String, dynamic>.from(v as Map);
  }

  // -------------------------------------------------------------------------
  // Subscription (plan selector: subscribe, cancel, upgrade)
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getSubscription() async =>
      _get('/api/billing/subscription');

  static Future<Map<String, dynamic>> subscribe(String plan) async =>
      _post('/api/billing/subscribe', {'plan': plan});

  static Future<Map<String, dynamic>> cancelSubscription() async {
    final v = await SpeariaApi.deleteJson('/api/billing/subscribe', params: {'business_id': _defaultBusinessId});
    return Map<String, dynamic>.from(v as Map);
  }

  static Future<Map<String, dynamic>> upgradeSubscription(String plan) async {
    final v = await SpeariaApi.putJson('/api/billing/subscription/upgrade', body: {'business_id': _defaultBusinessId, 'plan': plan});
    return Map<String, dynamic>.from(v as Map);
  }

  // -------------------------------------------------------------------------
  // Add-ons (Shield, HIPAA)
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> setAddonShield({required String numberId, required bool enabled}) async =>
      _patch('/api/billing/addons/shield', {'number_id': numberId, 'enabled': enabled});

  static Future<Map<String, dynamic>> setAddonHipaa({required bool enabled}) async =>
      _patch('/api/billing/addons/hipaa', {'enabled': enabled});

  // -------------------------------------------------------------------------
  // Outbound capacity (Part 2: phone numbers, primary vs campaign)
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getOutboundPhoneNumbers({String? date}) async =>
      _get('/api/pulse/outbound/phone-numbers', params: date != null ? {'date': date} : null);

  static Future<Map<String, dynamic>> getOutboundCapacity() async =>
      _get('/api/pulse/outbound/capacity');

  static Future<Map<String, dynamic>> setOutboundPrimary(String phoneNumberId) async {
    final v = await SpeariaApi.putJson('/api/pulse/outbound/primary', body: {
      'business_id': _defaultBusinessId,
      'phone_number_id': phoneNumberId,
    });
    return Map<String, dynamic>.from(v as Map);
  }

  static Future<Map<String, dynamic>> addOutboundCampaignNumber(String phoneNumberId, {String? label}) async =>
      _post('/api/pulse/outbound/phone-numbers', {
        'phone_number_id': phoneNumberId,
        if (label != null) 'label': label,
      });

  static Future<void> removeOutboundCampaignNumber(String phoneNumberId) async =>
      SpeariaApi.deleteJson(
        '/api/pulse/outbound/phone-numbers/$phoneNumberId',
        params: {'business_id': _defaultBusinessId},
      );

  // -------------------------------------------------------------------------
  // Outbound number management (Twilio: buy, roles, warm-up, daily limits)
  // -------------------------------------------------------------------------

  /// GET /api/numbers – list owned numbers with daily capacity
  static Future<Map<String, dynamic>> listNumbers() async =>
      _get('/api/numbers');

  /// GET /api/numbers/search?area_code=585&country=US
  static Future<Map<String, dynamic>> searchNumbers({
    required String areaCode,
    String country = 'US',
  }) async =>
      SpeariaApi.getJsonMap(
        '/api/numbers/search',
        params: {'area_code': areaCode, 'country': country, 'business_id': _defaultBusinessId},
      );

  /// POST /api/numbers/purchase – buy number (phone_number, friendly_name, role)
  static Future<Map<String, dynamic>> purchaseNumber({
    required String phoneNumber,
    required String friendlyName,
    String role = 'campaign',
  }) async =>
      _post('/api/numbers/purchase', {
        'phone_number': phoneNumber,
        'friendly_name': friendlyName,
        'role': role,
      });

  /// PUT /api/numbers/<number_id> – update friendly_name, role, registered_freecaller
  static Future<Map<String, dynamic>> updateNumber(
    String numberId, {
    String? friendlyName,
    String? role,
    bool? registeredFreecaller,
  }) async {
    final body = <String, dynamic>{'business_id': _defaultBusinessId};
    if (friendlyName != null) body['friendly_name'] = friendlyName;
    if (role != null) body['role'] = role;
    if (registeredFreecaller != null) body['registered_freecaller'] = registeredFreecaller;
    final v = await SpeariaApi.putJson('/api/numbers/$numberId', body: body);
    return Map<String, dynamic>.from(v as Map);
  }

  /// DELETE /api/numbers/<number_id>
  static Future<void> releaseNumber(String numberId) async =>
      SpeariaApi.deleteJson(
        '/api/numbers/$numberId',
        params: {'business_id': _defaultBusinessId},
      );

  /// POST /api/numbers/<number_id>/register-freecaller
  static Future<Map<String, dynamic>> registerFreecaller(String numberId) async =>
      SpeariaApi.postJsonMap(
        '/api/numbers/$numberId/register-freecaller',
        body: {'business_id': _defaultBusinessId},
      );

  /// GET /api/numbers/<number_id>/warm-up/status
  static Future<Map<String, dynamic>> getWarmUpStatus(String numberId) async =>
      _get('/api/numbers/$numberId/warm-up/status');

  /// POST /api/numbers/<number_id>/warm-up/advance (manual from dev console)
  static Future<Map<String, dynamic>> advanceWarmUp(String numberId) async =>
      SpeariaApi.postJsonMap(
        '/api/numbers/$numberId/warm-up/advance',
        body: {'business_id': _defaultBusinessId},
      );

  /// POST /api/pulse/campaigns/estimate – estimate days for contacts + number ids
  static Future<Map<String, dynamic>> campaignEstimate({
    required int totalContacts,
    required List<String> assignedNumberIds,
  }) async =>
      _post('/api/pulse/campaigns/estimate', {
        'total_contacts': totalContacts,
        'assigned_number_ids': assignedNumberIds,
      });

  /// GET /api/pulse/campaigns/estimate/quick?contacts=1000
  static Future<Map<String, dynamic>> campaignEstimateQuick({required int contacts}) async =>
      _get('/api/pulse/campaigns/estimate/quick', params: {'contacts': contacts});
}
