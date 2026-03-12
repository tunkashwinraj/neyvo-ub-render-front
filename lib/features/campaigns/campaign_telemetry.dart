// lib/features/campaigns/campaign_telemetry.dart
// Lightweight analytics for campaign lifecycle events (plug in your analytics later).

import 'package:flutter/foundation.dart';

void campaignPrepared(String campaignId, {int? audienceSize}) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[CampaignTelemetry] campaign_prepared campaignId=$campaignId audienceSize=$audienceSize');
  }
}

void campaignPrepareFailed(String campaignId, {String? errorCode}) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[CampaignTelemetry] campaign_prepare_failed campaignId=$campaignId errorCode=$errorCode');
  }
}

void campaignLaunched(String campaignId, {int? initiated, int? failed}) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[CampaignTelemetry] campaign_launched campaignId=$campaignId initiated=$initiated failed=$failed');
  }
}

void campaignRebuildAudience(String campaignId) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[CampaignTelemetry] campaign_rebuild_audience campaignId=$campaignId');
  }
}
