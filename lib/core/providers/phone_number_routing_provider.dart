import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/business_intelligence/routing_api_service.dart';
import '../../features/managed_profiles/managed_profile_api_service.dart';

part 'phone_number_routing_provider.g.dart';

Map<String, String> _intentMapFromConfig(Map<String, dynamic> config) {
  final im = Map<String, dynamic>.from(config['intentMap'] as Map? ?? {});
  return {
    'sales': (im['sales'] ?? '').toString(),
    'support': (im['support'] ?? '').toString(),
    'booking': (im['booking'] ?? '').toString(),
    'billing': (im['billing'] ?? '').toString(),
  };
}

class PhoneNumberRoutingUiState {
  const PhoneNumberRoutingUiState({
    this.loading = true,
    this.saving = false,
    this.error,
    this.routingPreset = 'simple',
    this.mode = 'single',
    this.defaultProfileId = '',
    this.intentMap = const {
      'sales': '',
      'support': '',
      'booking': '',
      'billing': '',
    },
    this.confidenceThreshold = 0.75,
    this.advancedExpanded = false,
    this.profiles = const [],
  });

  final bool loading;
  final bool saving;
  final String? error;
  final String routingPreset;
  final String mode;
  final String defaultProfileId;
  final Map<String, String> intentMap;
  final double confidenceThreshold;
  final bool advancedExpanded;
  final List<Map<String, dynamic>> profiles;

  PhoneNumberRoutingUiState copyWith({
    bool? loading,
    bool? saving,
    String? error,
    String? routingPreset,
    String? mode,
    String? defaultProfileId,
    Map<String, String>? intentMap,
    double? confidenceThreshold,
    bool? advancedExpanded,
    List<Map<String, dynamic>>? profiles,
    bool clearError = false,
  }) {
    return PhoneNumberRoutingUiState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
      routingPreset: routingPreset ?? this.routingPreset,
      mode: mode ?? this.mode,
      defaultProfileId: defaultProfileId ?? this.defaultProfileId,
      intentMap: intentMap ?? Map<String, String>.from(this.intentMap),
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      advancedExpanded: advancedExpanded ?? this.advancedExpanded,
      profiles: profiles ?? this.profiles,
    );
  }
}

@riverpod
class PhoneNumberRoutingCtrl extends _$PhoneNumberRoutingCtrl {
  @override
  PhoneNumberRoutingUiState build(String numberId) {
    return const PhoneNumberRoutingUiState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        RoutingApiService.getConfig(),
        ManagedProfileApiService.listProfiles(),
      ]);
      final configRes = results[0];
      final profRes = results[1];

      var next = state.copyWith(loading: false, clearError: true);

      if (configRes['ok'] == true && configRes['config'] != null) {
        final config = Map<String, dynamic>.from(configRes['config'] as Map);
        next = next.copyWith(
          mode: (config['mode'] as String? ?? 'single').toString(),
          defaultProfileId: (config['defaultProfileId'] ?? '').toString(),
          intentMap: _intentMapFromConfig(config),
          confidenceThreshold: (config['confidenceThreshold'] as num?)?.toDouble() ?? 0.75,
          routingPreset: 'custom',
        );
      }

      final list = (profRes['profiles'] as List?)?.cast<dynamic>() ?? [];
      next = next.copyWith(
        profiles: list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );

      state = next;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setRoutingPreset(String v) {
    state = state.copyWith(routingPreset: v);
  }

  void setMode(String v) {
    state = state.copyWith(mode: v);
  }

  void setDefaultProfileId(String v) {
    state = state.copyWith(defaultProfileId: v);
  }

  void setIntent(String key, String v) {
    final m = Map<String, String>.from(state.intentMap);
    m[key] = v;
    state = state.copyWith(intentMap: m);
  }

  void setConfidenceThreshold(double v) {
    state = state.copyWith(confidenceThreshold: v);
  }

  void setAdvancedExpanded(bool v) {
    state = state.copyWith(advancedExpanded: v);
  }

  void applySimplePreset() {
    final profiles = state.profiles;
    if (profiles.isEmpty) return;
    String? bookingId;
    String? salesId;
    String? supportId;

    for (final p in profiles) {
      final id = (p['profile_id'] ?? '').toString();
      final name = (p['profile_name'] ?? '').toString().toLowerCase();
      if (id.isEmpty) continue;
      if (bookingId == null && (name.contains('book') || name.contains('schedule'))) {
        bookingId = id;
      } else if (salesId == null && (name.contains('sale') || name.contains('lead'))) {
        salesId = id;
      } else if (supportId == null &&
          (name.contains('support') || name.contains('reception') || name.contains('general'))) {
        supportId = id;
      }
    }

    final firstId = profiles.isNotEmpty ? (profiles.first['profile_id'] ?? '').toString() : '';
    supportId ??= firstId;
    bookingId ??= supportId;
    salesId ??= supportId;

    state = state.copyWith(
      mode: 'silent_intent',
      defaultProfileId: supportId,
      intentMap: {
        ...state.intentMap,
        'booking': bookingId,
        'sales': salesId,
        'support': supportId,
      },
    );
  }

  Future<void> save() async {
    state = state.copyWith(saving: true, clearError: true);
    try {
      final intentMap = <String, String>{};
      for (final e in state.intentMap.entries) {
        if (e.value.isNotEmpty) {
          intentMap[e.key] = e.value;
        }
      }
      await RoutingApiService.updateConfig({
        'mode': state.mode,
        'defaultProfileId': state.defaultProfileId.trim(),
        'intentMap': intentMap,
        'confidenceThreshold': state.confidenceThreshold,
      });
      state = state.copyWith(saving: false);
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
    }
  }
}
