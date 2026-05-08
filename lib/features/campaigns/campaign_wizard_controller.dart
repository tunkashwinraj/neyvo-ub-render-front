import 'package:flutter/material.dart';
import '../../neyvo_pulse_api.dart';

/// Lightweight controller holding state for the multi-step campaign wizard.
class CampaignWizardController extends ChangeNotifier {
  String? campaignId;

  // Basics
  String name = '';
  String? agentId;
  String? profileId;
  String? templateId;
  int? maxConcurrent;
  int? maxAttempts;
  DateTime? scheduledAt;
  String? notes;

  // Audience
  String? audienceMode; // 'FILTERS' | 'MANUAL'
  Map<String, dynamic>? audienceFilters;
  List<String> manualStudentIds = [];

  // Snapshot / validation
  String snapshotStatus = 'none';
  int snapshotAudienceSize = 0;
  Map<String, dynamic>? validationReport;

  bool get canProceedToAudience => campaignId != null && name.trim().isNotEmpty;
  bool get canPrepare => campaignId != null && audienceMode != null;
  bool get canLaunch =>
      snapshotStatus == 'complete' &&
      (validationReport != null && validationReport!['ok'] == true);

  /// Reset state for a new campaign (e.g. when opening create wizard).
  void reset() {
    campaignId = null;
    name = '';
    agentId = null;
    profileId = null;
    templateId = null;
    maxConcurrent = null;
    maxAttempts = null;
    scheduledAt = null;
    notes = null;
    audienceMode = null;
    audienceFilters = null;
    manualStudentIds = [];
    snapshotStatus = 'none';
    snapshotAudienceSize = 0;
    validationReport = null;
    notifyListeners();
  }

  Future<void> createBasics() async {
    final res = await NeyvoPulseApi.createCampaignBasics(
      name: name,
      agentId: agentId,
      profileId: profileId,
      templateId: templateId,
      maxConcurrent: maxConcurrent,
      maxAttempts: maxAttempts,
      scheduledAt: scheduledAt,
      notes: notes,
    );
    final c = (res['campaign'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    campaignId = (c['id'] ?? '').toString().trim();
    notifyListeners();
  }

  Future<void> updateBasicsIfNeeded() async {
    if (campaignId == null) return;
    await NeyvoPulseApi.updateCampaignBasics(
      campaignId!,
      name: name,
      agentId: agentId,
      profileId: profileId,
      templateId: templateId,
      maxConcurrent: maxConcurrent,
      maxAttempts: maxAttempts,
      scheduledAt: scheduledAt,
      notes: notes,
    );
  }

  Future<void> saveAudienceFilters(Map<String, dynamic> filters) async {
    if (campaignId == null) return;
    audienceMode = 'FILTERS';
    audienceFilters = filters;
    manualStudentIds = [];
    await NeyvoPulseApi.updateCampaignAudience(
      campaignId!,
      audienceMode: 'FILTERS',
      audienceFilters: filters,
    );
    notifyListeners();
  }

  Future<void> saveAudienceManual(List<String> studentIds) async {
    if (campaignId == null) return;
    audienceMode = 'MANUAL';
    manualStudentIds = List<String>.from(studentIds);
    audienceFilters = null;
    await NeyvoPulseApi.updateCampaignAudience(
      campaignId!,
      audienceMode: 'MANUAL',
      studentIds: manualStudentIds,
    );
    notifyListeners();
  }

  Future<void> prepareSnapshot() async {
    if (campaignId == null) return;
    final res = await NeyvoPulseApi.prepareCampaign(campaignId!);
    validationReport = res;
    // Fetch authoritative snapshot status / size from backend.
    // Prepare may be asynchronous, so poll briefly for completion.
    Map<String, dynamic>? v;
    Future<Map<String, dynamic>?> fetch() async {
      try {
        final vv = await NeyvoPulseApi.getCampaignValidation(campaignId!);
        return Map<String, dynamic>.from(vv as Map);
      } catch (_) {
        return null;
      }
    }

    v = await fetch();
    String status = (v?['snapshot_status'] ?? 'none').toString().toLowerCase().trim();
    if (status != 'complete') {
      final delays = <Duration>[
        const Duration(milliseconds: 800),
        const Duration(milliseconds: 1200),
        const Duration(milliseconds: 1800),
        const Duration(milliseconds: 2500),
        const Duration(milliseconds: 3500),
        const Duration(milliseconds: 5000),
        const Duration(milliseconds: 6500),
        const Duration(milliseconds: 8000),
      ];
      for (final d in delays) {
        await Future.delayed(d);
        v = await fetch() ?? v;
        status = (v?['snapshot_status'] ?? status).toString().toLowerCase().trim();
        if (status == 'complete' || status == 'invalid') break;
      }
    }

    snapshotStatus = (v?['snapshot_status'] ?? 'none').toString();
    snapshotAudienceSize = (v?['snapshot_audience_size'] as int?) ?? 0;
    validationReport = (v?['validation_report'] as Map?)?.cast<String, dynamic>() ?? validationReport;
    notifyListeners();
  }

  Future<void> refreshValidation() async {
    if (campaignId == null) return;
    final v = await NeyvoPulseApi.getCampaignValidation(campaignId!);
    snapshotStatus = (v['snapshot_status'] ?? snapshotStatus).toString();
    snapshotAudienceSize = (v['snapshot_audience_size'] as int?) ?? snapshotAudienceSize;
    validationReport = (v['validation_report'] as Map?)?.cast<String, dynamic>() ?? validationReport;
    notifyListeners();
  }

  Future<Map<String, dynamic>> launch({String? phoneNumberId}) async {
    if (campaignId == null) {
      throw StateError('Cannot launch campaign: campaignId is null');
    }
    final res = await NeyvoPulseApi.startCampaignSnapshotRun(
      campaignId!,
      phoneNumberId: phoneNumberId,
    );
    return res;
  }

  Future<void> rebuildAudience() async {
    if (campaignId == null) return;
    await NeyvoPulseApi.rebuildCampaignAudience(campaignId!);
    snapshotStatus = 'none';
    snapshotAudienceSize = 0;
    validationReport = null;
    notifyListeners();
  }
}

