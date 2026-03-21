import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'operator_optimization_api_service.dart';

final optimizationStatusProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, operatorId) async {
  return OperatorOptimizationApiService.getStatus(operatorId);
});

final optimizationIterationsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, operatorId) async {
  return OperatorOptimizationApiService.listIterations(operatorId);
});

final optimizationFlaggedCallsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, operatorId) async {
  return OperatorOptimizationApiService.listFlaggedCalls(operatorId);
});

final optimizationPerformanceProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, operatorId) async {
  return OperatorOptimizationApiService.getPerformance(operatorId);
});
