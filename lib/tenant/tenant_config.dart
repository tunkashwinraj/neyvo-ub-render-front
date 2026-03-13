import 'package:flutter/material.dart';

/// Branding configuration for a tenant (e.g. UB, Goodwin).
class TenantConfig {
  final String tenantId;
  final String schoolName;
  final Color? primaryColor;
  final Color? secondaryColor;
  final Color? accentColor;
  final String? logoHorizontalColorUrl;
  final String? logoHorizontalWhiteUrl;
  final String? logoStackedColorUrl;
  final String? logoStackedWhiteUrl;

  const TenantConfig({
    required this.tenantId,
    required this.schoolName,
    this.primaryColor,
    this.secondaryColor,
    this.accentColor,
    this.logoHorizontalColorUrl,
    this.logoHorizontalWhiteUrl,
    this.logoStackedColorUrl,
    this.logoStackedWhiteUrl,
  });

  factory TenantConfig.fromJson(Map<String, dynamic> json) {
    Color? _parseColor(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      final hex = s.startsWith('#') ? s.substring(1) : s;
      if (hex.length != 6 && hex.length != 8) return null;
      final value = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
      if (value == null) return null;
      return Color(value);
    }

    return TenantConfig(
      tenantId: (json['tenant_id'] ?? '').toString().trim(),
      schoolName: (json['school_name'] ?? '').toString().trim(),
      primaryColor: _parseColor(json['primary_color']),
      secondaryColor: _parseColor(json['secondary_color']),
      accentColor: _parseColor(json['accent_color']),
      logoHorizontalColorUrl:
          (json['logo_horizontal_color_url'] ?? '').toString().trim().isEmpty
              ? null
              : (json['logo_horizontal_color_url'] ?? '').toString().trim(),
      logoHorizontalWhiteUrl:
          (json['logo_horizontal_white_url'] ?? '').toString().trim().isEmpty
              ? null
              : (json['logo_horizontal_white_url'] ?? '').toString().trim(),
      logoStackedColorUrl:
          (json['logo_stacked_color_url'] ?? '').toString().trim().isEmpty
              ? null
              : (json['logo_stacked_color_url'] ?? '').toString().trim(),
      logoStackedWhiteUrl:
          (json['logo_stacked_white_url'] ?? '').toString().trim().isEmpty
              ? null
              : (json['logo_stacked_white_url'] ?? '').toString().trim(),
    );
  }
}

