// lib/features/setup/setup_api_service.dart
// Single source of truth for setup status – wraps GET /api/setup/status.

import '../../api/spearia_api.dart';
import '../../neyvo_pulse_api.dart';

class SetupStatusApiService {
  /// GET /api/setup/status
  /// Mirrors the backend response shape:
  /// {
  ///   ok, orgId,
  ///   business: { status, category, subcategory },
  ///   agents: { count, inboundEligibleCount },
  ///   numbers: { count, primaryNumber, primaryPhoneNumberId, hasInboundConfigured, routingMode },
  ///   goLive: { inboundReady, outboundReady, callToTest, notes },
  ///   nextStep: { key, title, ctaLabel, route }
  /// }
  static Future<Map<String, dynamic>> getStatus() async {
    final params = <String, dynamic>{};
    if (NeyvoPulseApi.defaultAccountId.isNotEmpty) {
      params['account_id'] = NeyvoPulseApi.defaultAccountId;
    }
    final res = await SpeariaApi.getJsonMap('/api/setup/status', params: params);
    return Map<String, dynamic>.from(res);
  }
}

