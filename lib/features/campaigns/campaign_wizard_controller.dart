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
    // Fetch authoritative snapshot status / size from backend
    final v = await NeyvoPulseApi.getCampaignValidation(campaignId!);
    snapshotStatus = (v['snapshot_status'] ?? 'none').toString();
    snapshotAudienceSize = (v['snapshot_audience_size'] as int?) ?? 0;
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

