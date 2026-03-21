import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/neyvo_api.dart';
import '../../features/setup/setup_api_service.dart';
import '../../neyvo_pulse_api.dart';
import 'account_provider.dart';

class PulseDashboardRange {
  const PulseDashboardRange({this.from, this.to});

  final String? from;
  final String? to;

  String get key => '${from ?? ''}|${to ?? ''}';
}

class PulseDashboardCriticalData {
  const PulseDashboardCriticalData({
    required this.businessConfigured,
    required this.operatorCount,
    required this.numberLive,
    required this.firstCallCompleted,
    required this.ubStatus,
    required this.trainingNumber,
    required this.kpi,
  });

  final bool businessConfigured;
  final int operatorCount;
  final bool numberLive;
  final bool firstCallCompleted;
  final String ubStatus;
  final String? trainingNumber;
  final Map<String, dynamic> kpi;
}

class PulseDashboardImportantData {
  const PulseDashboardImportantData({
    required this.recentCalls,
    required this.recentCampaigns,
  });

  final List<Map<String, dynamic>> recentCalls;
  final List<Map<String, dynamic>> recentCampaigns;
}

class PulseDashboardHeavyData {
  const PulseDashboardHeavyData({
    required this.perf,
    required this.perfPrevious,
    required this.successSummary,
    required this.successSummaryPrevious,
    required this.ubModel,
  });

  final Map<String, dynamic>? perf;
  final Map<String, dynamic>? perfPrevious;
  final Map<String, dynamic>? successSummary;
  final Map<String, dynamic>? successSummaryPrevious;
  final Map<String, dynamic>? ubModel;
}

class _CacheEntry<T> {
  const _CacheEntry({required this.value, required this.expiresAt});
  final T value;
  final DateTime expiresAt;
}

final Map<String, _CacheEntry<dynamic>> _sectionCache = <String, _CacheEntry<dynamic>>{};
final Map<String, Future<dynamic>> _inFlight = <String, Future<dynamic>>{};

Future<T> _cachedFetch<T>({
  required String cacheKey,
  required Duration ttl,
  required Future<T> Function() loader,
}) {
  final now = DateTime.now();
  final cached = _sectionCache[cacheKey];
  if (cached != null && cached.expiresAt.isAfter(now)) {
    return Future<T>.value(cached.value as T);
  }

  final inFlight = _inFlight[cacheKey];
  if (inFlight != null) {
    return inFlight as Future<T>;
  }

  final future = loader().then((value) {
    _sectionCache[cacheKey] = _CacheEntry<dynamic>(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
    return value;
  }).whenComplete(() {
    _inFlight.remove(cacheKey);
  });

  _inFlight[cacheKey] = future;
  return future;
}

final pulseDashboardSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, PulseDashboardRange>((ref, range) async {
  ref.watch(accountInfoProvider);
  final cacheKey = 'summary:${range.key}';
  return _cachedFetch<Map<String, dynamic>>(
    cacheKey: cacheKey,
    ttl: const Duration(seconds: 45),
    loader: () => NeyvoPulseApi.getDashboardSummary(
      from: range.from,
      to: range.to,
      recentCallsLimit: 8,
      recentCampaignsLimit: 8,
      timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.medium),
    ),
  );
});

final pulseDashboardCriticalProvider =
    FutureProvider.family<PulseDashboardCriticalData, PulseDashboardRange>((ref, range) async {
  final summaryFuture = ref.watch(pulseDashboardSummaryProvider(range).future);
  final fallbackFuture = SetupStatusApiService.getStatus()
      .timeout(const Duration(milliseconds: 1200))
      .catchError((_) => <String, dynamic>{});
  final summary = await summaryFuture;
  final setup = Map<String, dynamic>.from(summary['setup'] as Map? ?? const {});
  final kpi = Map<String, dynamic>.from(summary['kpi'] as Map? ?? const {});
  final fallback = await fallbackFuture;
  final fallbackBusiness = Map<String, dynamic>.from(fallback['business'] as Map? ?? const {});

  return PulseDashboardCriticalData(
    businessConfigured: setup['business_configured'] == true || (fallbackBusiness['status']?.toString().toLowerCase() == 'ready'),
    operatorCount: (setup['operator_count'] as num?)?.toInt() ?? 0,
    numberLive: setup['number_live'] == true,
    firstCallCompleted: setup['first_call_completed'] == true,
    ubStatus: (setup['ub_status']?.toString().toLowerCase() ?? 'missing'),
    trainingNumber: (setup['training_number'] as String?)?.trim().isEmpty == true ? null : setup['training_number'] as String?,
    kpi: kpi,
  );
});

final pulseDashboardImportantProvider =
    FutureProvider.family<PulseDashboardImportantData, PulseDashboardRange>((ref, range) async {
  final summary = await ref.watch(pulseDashboardSummaryProvider(range).future);
  final recentCalls = ((summary['recent_calls'] as List?) ?? const <dynamic>[])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final recentCampaigns = ((summary['recent_campaigns'] as List?) ?? const <dynamic>[])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  return PulseDashboardImportantData(
    recentCalls: recentCalls,
    recentCampaigns: recentCampaigns,
  );
});

final pulseDashboardHeavyProvider =
    FutureProvider.family<PulseDashboardHeavyData, PulseDashboardRange>((ref, range) async {
  final prevFromTo = _previousRange(range.from, range.to);
  final cacheKey = 'heavy:${range.key}';
  return _cachedFetch<PulseDashboardHeavyData>(
    cacheKey: cacheKey,
    ttl: const Duration(seconds: 120),
    loader: () async {
      final results = await Future.wait([
        NeyvoPulseApi.getAnalyticsOverview(
          from: range.from,
          to: range.to,
          timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.heavy),
        ),
        NeyvoPulseApi.getAnalyticsOverview(
          from: prevFromTo.$1,
          to: prevFromTo.$2,
          timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.heavy),
        ),
        NeyvoPulseApi.getCallsSuccessSummary(
          from: range.from,
          to: range.to,
          timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.heavy),
        ),
        NeyvoPulseApi.getCallsSuccessSummary(
          from: prevFromTo.$1,
          to: prevFromTo.$2,
          timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.heavy),
        ),
        NeyvoPulseApi.getUbStatus(
          timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.medium),
        ).catchError((_) => <String, dynamic>{}),
      ]);

      return PulseDashboardHeavyData(
        perf: Map<String, dynamic>.from(results[0] as Map),
        perfPrevious: Map<String, dynamic>.from(results[1] as Map),
        successSummary: Map<String, dynamic>.from(results[2] as Map),
        successSummaryPrevious: Map<String, dynamic>.from(results[3] as Map),
        ubModel: Map<String, dynamic>.from(results[4] as Map),
      );
    },
  );
});

(String?, String?) _previousRange(String? from, String? to) {
  if (from == null || to == null || from.isEmpty || to.isEmpty) {
    return (null, null);
  }
  try {
    final fromDate = DateTime.parse(from);
    final toDate = DateTime.parse(to);
    final days = toDate.difference(fromDate).inDays + 1;
    final prevEnd = fromDate.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(Duration(days: days - 1));
    String toIso(DateTime d) => '${d.toUtc().toIso8601String().split('T').first}';
    return (toIso(prevStart), toIso(prevEnd));
  } catch (_) {
    return (null, null);
  }
}

