// lib/services/subscription_service.dart
// Thin client for /api/billing/subscription endpoints.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api/neyvo_api.dart';
import '../models/subscription_model.dart';

class SubscriptionService {
  static Future<Map<String, String>> _authHeaders() async {
    // NeyvoApi already centralizes auth headers in most calls;
    // here we only need Authorization & ngrok header.
    return <String, String>{
      'Accept': 'application/json',
      if (NeyvoApi.sessionToken != null)
        'Authorization': 'Bearer ${NeyvoApi.sessionToken}',
      if (NeyvoApi.baseUrl.contains('ngrok'))
        'ngrok-skip-browser-warning': 'true',
    };
  }

  static Future<SubscriptionPlan> getCurrentPlan() async {
    final uri = Uri.parse(
        '${NeyvoApi.baseUrl}/api/billing/subscription');
    final resp = await http.get(uri, headers: await _authHeaders());
    if (resp.statusCode == 200) {
      final map =
          json.decode(resp.body) as Map<String, dynamic>;
      return SubscriptionPlan.fromJson(map);
    }
    // Fallback to Free plan on error.
    return SubscriptionPlan(
      tier: 'free',
      status: 'active',
      pricePerMonth: 0,
      creditBonusPct: 0.0,
      features: SubscriptionFeatures.fromJson(<String, dynamic>{}),
    );
  }

  static Future<void> upgradePlan(String tier) async {
    final uri = Uri.parse(
        '${NeyvoApi.baseUrl}/api/billing/subscription/upgrade');
    final resp = await http.post(
      uri,
      headers: await _authHeaders()
        ..putIfAbsent('Content-Type', () => 'application/json'),
      body: json.encode(<String, dynamic>{'tier': tier}),
    );
    if (resp.statusCode != 200) {
      throw Exception(
          'Upgrade failed: ${resp.statusCode} ${resp.body}');
    }
  }

  static Future<void> cancelPlan() async {
    final uri = Uri.parse(
        '${NeyvoApi.baseUrl}/api/billing/subscription/cancel');
    final resp = await http.delete(
      uri,
      headers: await _authHeaders(),
    );
    if (resp.statusCode != 200) {
      throw Exception(
          'Cancellation failed: ${resp.statusCode} ${resp.body}');
    }
  }
}

