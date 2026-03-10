// lib/models/subscription_model.dart
// Neyvo subscription plan model loaded from /api/billing/subscription.

class SubscriptionFeatures {
  final List<String> allowedVoiceTiers;
  final int maxManagedProfiles;
  final int maxPhoneNumbers;
  final bool canUseAiStudio;
  final bool canMakeOutboundCalls;
  final bool canUseCampaignScheduling;
  final bool canAccessFullAnalytics;
  final bool hipaaIncluded;
  final bool hipaaAvailableAsAddon;
  final bool apiAccess;
  final bool whiteLabel;
  final int monthlyCallLimit;
  final String supportLevel;

  const SubscriptionFeatures({
    required this.allowedVoiceTiers,
    required this.maxManagedProfiles,
    required this.maxPhoneNumbers,
    required this.canUseAiStudio,
    required this.canMakeOutboundCalls,
    required this.canUseCampaignScheduling,
    required this.canAccessFullAnalytics,
    required this.hipaaIncluded,
    required this.hipaaAvailableAsAddon,
    required this.apiAccess,
    required this.whiteLabel,
    required this.monthlyCallLimit,
    required this.supportLevel,
  });

  bool isVoiceTierAllowed(String voiceTier) =>
      allowedVoiceTiers.contains(voiceTier);

  factory SubscriptionFeatures.fromJson(Map<String, dynamic> json) {
    return SubscriptionFeatures(
      allowedVoiceTiers:
          List<String>.from(json['allowed_voice_tiers'] as List? ?? <String>[]),
      maxManagedProfiles: json['max_managed_profiles'] as int? ?? 1,
      maxPhoneNumbers: json['max_phone_numbers'] as int? ?? 1,
      canUseAiStudio: json['can_use_ai_studio'] as bool? ?? false,
      canMakeOutboundCalls:
          json['can_make_outbound_calls'] as bool? ?? false,
      canUseCampaignScheduling:
          json['can_use_campaign_scheduling'] as bool? ?? false,
      canAccessFullAnalytics:
          json['can_access_full_analytics'] as bool? ?? false,
      hipaaIncluded: json['hipaa_included'] as bool? ?? false,
      hipaaAvailableAsAddon:
          json['hipaa_available_as_addon'] as bool? ?? false,
      apiAccess: json['api_access'] as bool? ?? false,
      whiteLabel: json['white_label'] as bool? ?? false,
      monthlyCallLimit: json['monthly_call_limit'] as int? ?? 0,
      supportLevel: json['support_level'] as String? ?? 'email',
    );
  }
}

class SubscriptionPlan {
  final String tier; // "free" | "pro" | "business"
  final String status; // "active" | "cancelled" | "trial"
  final int pricePerMonth;
  final double creditBonusPct;
  final SubscriptionFeatures features;

  const SubscriptionPlan({
    required this.tier,
    required this.status,
    required this.pricePerMonth,
    required this.creditBonusPct,
    required this.features,
  });

  String get displayName {
    switch (tier) {
      case 'pro':
        return 'Pro';
      case 'business':
        return 'Business';
      default:
        return 'Free';
    }
  }

  bool get isFree => tier == 'free';
  bool get isPro => tier == 'pro';
  bool get isBusiness => tier == 'business';

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      tier: json['tier'] as String? ?? 'free',
      status: json['status'] as String? ?? 'active',
      pricePerMonth: json['price_per_month'] as int? ?? 0,
      creditBonusPct:
          (json['credit_bonus_pct'] as num?)?.toDouble() ?? 0.0,
      features: SubscriptionFeatures.fromJson(
          json['features'] as Map<String, dynamic>? ?? <String, dynamic>{}),
    );
  }
}

