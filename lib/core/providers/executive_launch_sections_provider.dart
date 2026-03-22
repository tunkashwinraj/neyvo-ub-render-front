import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/neyvo_api.dart';
import '../../features/managed_profiles/managed_profile_api_service.dart';
import '../../features/setup/setup_api_service.dart';
import '../../neyvo_pulse_api.dart';
import 'account_provider.dart';

class ExecutiveRange {
  const ExecutiveRange({
    required this.from,
    required this.to,
    required this.priorFrom,
    required this.priorTo,
  });

  final String from;
  final String to;
  final String priorFrom;
  final String priorTo;

  String get key => '$from|$to|$priorFrom|$priorTo';
}

class ExecutiveCriticalData {
  const ExecutiveCriticalData({
    required this.comms,
    required this.calls,
    required this.successSummary,
    required this.recentCalls,
  });

  final Map<String, dynamic> comms;
  final List<Map<String, dynamic>> calls;
  final Map<String, dynamic>? successSummary;
  final List<Map<String, dynamic>> recentCalls;
}

class ExecutiveDeferredData {
  const ExecutiveDeferredData({
    required this.runningCampaignId,
    required this.campaignItems,
    required this.campaignMetrics,
  });

  final String? runningCampaignId;
  final List<Map<String, dynamic>> campaignItems;
  final Map<String, dynamic>? campaignMetrics;
}

class LaunchCriticalData {
  const LaunchCriticalData({
    required this.credits,
    required this.businessReady,
  });

  final int credits;
  final bool businessReady;
}

class LaunchDeferredData {
  const LaunchDeferredData({
    required this.agentsCount,
    required this.numbersCount,
    required this.hasFirstCompletedCall,
    required this.trainingNumberE164,
  });

  final int agentsCount;
  final int numbersCount;
  final bool hasFirstCompletedCall;
  final String? trainingNumberE164;
}

class _CacheEntry<T> {
  const _CacheEntry(this.value, this.expiresAt);
  final T value;
  final DateTime expiresAt;
}

final Map<String, _CacheEntry<dynamic>> _cache = <String, _CacheEntry<dynamic>>{};
final Map<String, Future<dynamic>> _inFlight = <String, Future<dynamic>>{};

Future<T> _cachedFetch<T>({
  required String key,
  required Duration ttl,
  required Future<T> Function() loader,
}) {
  final now = DateTime.now();
  final cached = _cache[key];
  if (cached != null && cached.expiresAt.isAfter(now)) {
    return Future<T>.value(cached.value as T);
  }
  final pending = _inFlight[key];
  if (pending != null) return pending as Future<T>;

  final future = loader().then((value) {
    _cache[key] = _CacheEntry<dynamic>(value, DateTime.now().add(ttl));
    return value;
  }).whenComplete(() => _inFlight.remove(key));
  _inFlight[key] = future;
  return future;
}

final executiveCriticalProvider =
    FutureProvider.family<ExecutiveCriticalData, ExecutiveRange>((ref, range) async {
  ref.watch(
    accountInfoProvider.select(
      (async) => async.valueOrNull?['account_id']?.toString() ?? '',
    ),
  );
  return _cachedFetch<ExecutiveCriticalData>(
    key: 'exec-critical:${range.key}',
    ttl: const Duration(seconds: 45),
    loader: () async {
      final results = await Future.wait<dynamic>([
        NeyvoPulseApi.getAnalyticsComms(
          from: range.from,
          to: range.to,
          timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.medium),
        ).catchError((_) => <String, dynamic>{'ok': false}),
        NeyvoPulseApi.listCalls(
          from: range.from,
          to: range.to,
          limit: 150,
          timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.medium),
        ).catchError((_) => <String, dynamic>{'calls': <dynamic>[]}),
        NeyvoPulseApi.listCalls(
          from: range.priorFrom,
          to: range.priorTo,
          limit: 150,
          timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.medium),
        ).catchError((_) => <String, dynamic>{'calls': <dynamic>[]}),
        NeyvoPulseApi.getCallsSuccessSummary(
          from: range.from,
          to: range.to,
          timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.medium),
        ).catchError((_) => <String, dynamic>{}),
        NeyvoPulseApi.listCalls(
          limit: 5,
          noVapi: true,
          timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.fast),
        ).catchError((_) => <String, dynamic>{'calls': <dynamic>[]}),
        ref.read(accountInfoProvider.future).catchError((_) => <String, dynamic>{}),
      ]);
      final callsRes = Map<String, dynamic>.from(results[1] as Map);
      final recentRes = Map<String, dynamic>.from(results[4] as Map);
      final calls = (callsRes['calls'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final recent = (recentRes['calls'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final success = Map<String, dynamic>.from(results[3] as Map);
      return ExecutiveCriticalData(
        comms: Map<String, dynamic>.from(results[0] as Map),
        calls: calls,
        recentCalls: recent,
        successSummary: success['ok'] == true ? success : null,
      );
    },
  );
});

final executiveDeferredProvider =
    FutureProvider.family<ExecutiveDeferredData, ExecutiveRange>((ref, range) async {
  return _cachedFetch<ExecutiveDeferredData>(
    key: 'exec-deferred:${range.key}',
    ttl: const Duration(seconds: 120),
    loader: () async {
      final results = await Future.wait<dynamic>([
        NeyvoPulseApi.health(timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.fast)).catchError((_) => <String, dynamic>{}),
        NeyvoPulseApi.getUbStatus(timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.medium)).catchError((_) => <String, dynamic>{}),
        NeyvoPulseApi.listAgents(status: 'active', timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.medium)).catchError((_) => <String, dynamic>{'agents': []}),
        NeyvoPulseApi.listCampaigns(limit: 20, timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.heavy)),
      ]);
      final campaignsRes = Map<String, dynamic>.from(results[3] as Map);
      final campaigns = campaignsRes['campaigns'] as List? ?? const [];
      String? runningId;
      for (final c in campaigns) {
        final m = Map<String, dynamic>.from(c as Map);
        final s = (m['status'] as String? ?? '').toLowerCase();
        if (s == 'running' || s == 'active') {
          runningId = m['id'] as String?;
          break;
        }
      }
      List<Map<String, dynamic>> items = const [];
      Map<String, dynamic>? metrics;
      if (runningId != null && runningId.isNotEmpty) {
        final pair = await Future.wait([
          NeyvoPulseApi.getCampaignCallItems(runningId, limit: 120, timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.heavy)),
          NeyvoPulseApi.getCampaignMetrics(runningId, timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.heavy)),
        ]);
        final itemsRes = Map<String, dynamic>.from(pair[0] as Map);
        items = (itemsRes['items'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [];
        final metricsRes = Map<String, dynamic>.from(pair[1] as Map);
        final m = metricsRes['metrics'];
        metrics = m is Map ? Map<String, dynamic>.from(m) : null;
      }
      return ExecutiveDeferredData(
        runningCampaignId: runningId,
        campaignItems: items,
        campaignMetrics: metrics,
      );
    },
  );
});

final launchCriticalProvider = FutureProvider<LaunchCriticalData>((ref) async {
  ref.watch(
    accountInfoProvider.select(
      (async) => async.valueOrNull?['account_id']?.toString() ?? '',
    ),
  );
  return _cachedFetch<LaunchCriticalData>(
    key: 'launch-critical',
    ttl: const Duration(seconds: 45),
    loader: () async {
      final results = await Future.wait<dynamic>([
        NeyvoPulseApi.getBillingWallet(timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.medium)),
        SetupStatusApiService.getStatus(),
      ]);
      final wallet = Map<String, dynamic>.from(results[0] as Map);
      final setup = Map<String, dynamic>.from(results[1] as Map);
      final business = Map<String, dynamic>.from(setup['business'] as Map? ?? {});
      final credits = (wallet['credits'] as num?)?.toInt() ?? (wallet['wallet_credits'] as num?)?.toInt() ?? 0;
      return LaunchCriticalData(
        credits: credits,
        businessReady: (business['status'] as String? ?? '').toLowerCase() == 'ready',
      );
    },
  );
});

final launchDeferredProvider = FutureProvider<LaunchDeferredData>((ref) async {
  return _cachedFetch<LaunchDeferredData>(
    key: 'launch-deferred',
    ttl: const Duration(seconds: 90),
    loader: () async {
      final results = await Future.wait<dynamic>([
        ManagedProfileApiService.listProfiles(),
        NeyvoPulseApi.listNumbers(timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.medium)),
        NeyvoPulseApi.listCalls(limit: 120, timeout: NeyvoApi.timeoutForClass(ApiTimeoutClass.heavy)),
        ref.read(accountInfoProvider.future).catchError((_) => <String, dynamic>{}),
      ]);
      final profiles = Map<String, dynamic>.from(results[0] as Map);
      final numbers = Map<String, dynamic>.from(results[1] as Map);
      final calls = Map<String, dynamic>.from(results[2] as Map);
      final account = Map<String, dynamic>.from(results[3] as Map);
      final agentsCount = ((profiles['profiles'] as List?)?.length ?? 0);
      final numbersCount = ((numbers['numbers'] as List?)?.length ?? 0);
      final callsList = (calls['calls'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final hasCompleted = callsList.any((c) {
        final status = (c['status'] as String?)?.toLowerCase();
        if (status == 'completed' || status == 'success') return true;
        final endedAt = c['ended_at'];
        return endedAt != null && status != 'failed';
      });
      String? trainingNumber;
      final primary = (account['primary_phone_e164'] ?? account['primary_phone'])?.toString();
      if (primary != null && primary.trim().isNotEmpty) {
        trainingNumber = primary.trim();
      } else {
        final list = (numbers['numbers'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        final primaryNum = list.firstWhere(
          (n) => (n['role']?.toString().toLowerCase() ?? '') == 'primary',
          orElse: () => const {},
        );
        trainingNumber = (primaryNum['phone_number_e164'] ?? primaryNum['phone_number'])?.toString();
      }
      return LaunchDeferredData(
        agentsCount: agentsCount,
        numbersCount: numbersCount,
        hasFirstCompletedCall: hasCompleted,
        trainingNumberE164: trainingNumber,
      );
    },
  );
});

