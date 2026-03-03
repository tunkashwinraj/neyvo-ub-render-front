// lib/features/business_intelligence/business_model_completeness.dart
// Evaluates business model completeness from BI payload or wizard payload.

class BusinessModelCompleteness {
  final int percent;
  final List<String> missing;

  BusinessModelCompleteness(this.percent, this.missing);
}

/// Evaluates completeness from a BI-like map.
/// Accepts either backend BI shape (core, knowledge) or wizard payload (business_name, category, offerings.services, etc.).
BusinessModelCompleteness evaluateBusinessModelCompleteness(Map<String, dynamic> bi) {
  int score = 0;
  final List<String> missing = [];

  // Normalize: support both backend BI and wizard payload shapes
  final core = bi['core'] as Map<String, dynamic>? ?? bi;
  final knowledge = bi['knowledge'] as Map<String, dynamic>? ?? <String, dynamic>{};
  final name = (core['name'] ?? core['business_name'] ?? '').toString().trim();
  final category = (core['category'] ?? '').toString().trim();
  final subcategory = (core['subcategory'] ?? '').toString().trim();
  final contact = knowledge['contact'] as Map<String, dynamic>? ?? {};
  final mainPhone = (contact['main_phone'] ?? contact['mainPhone'] ?? bi['phone_number'] ?? '').toString().trim();
  final offerings = bi['offerings'] as Map<String, dynamic>? ?? knowledge['offerings'] as Map<String, dynamic>? ?? {};
  final servicesList = offerings['services'] as List<dynamic>? ?? knowledge['services'] as List<dynamic>? ?? [];
  final services = servicesList.where((e) => e is Map).toList();
  final hasHours = (bi['hours'] ?? knowledge['hours']) != null &&
      (bi['hours'] is Map || knowledge['hours'] is Map || (bi['hours'] is String && (bi['hours'] as String).isNotEmpty));
  final hasPolicies = (bi['policies'] ?? knowledge['policies']) != null &&
      ((bi['policies'] is List && (bi['policies'] as List).isNotEmpty) ||
          (knowledge['policies'] is List && (knowledge['policies'] as List).isNotEmpty) ||
          (bi['policies'] is String && (bi['policies'] as String).trim().isNotEmpty));

  // Identity: 20% (name + category + subcategory)
  final hasIdentity = name.isNotEmpty && category.isNotEmpty && subcategory.isNotEmpty;
  if (hasIdentity) {
    score += 20;
  } else {
    missing.add('Identity');
  }

  // Services: 25% (at least 3)
  if (services.length >= 3) {
    score += 25;
  } else {
    missing.add('Services');
  }

  // Hours: 15%
  if (hasHours) {
    score += 15;
  } else {
    missing.add('Hours');
  }

  // Policies: 15%
  if (hasPolicies) {
    score += 15;
  } else {
    missing.add('Policies');
  }

  // Contact: 10%
  if (mainPhone.isNotEmpty) {
    score += 10;
  } else {
    missing.add('Contact');
  }

  // Percent: max 85 so we scale to 0–100
  final percent = (85 > 0) ? ((score / 85) * 100).round().clamp(0, 100) : 0;
  return BusinessModelCompleteness(percent, missing);
}
