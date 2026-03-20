import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../api/neyvo_api.dart';

export 'timezone_provider.dart';

final apiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://fallback-url.onrender.com',
  );
});

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  return Dio(BaseOptions(baseUrl: baseUrl));
});

final speariaApiProvider = Provider<NeyvoApi>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  ref.watch(dioProvider);
  NeyvoApi.setBaseUrl(baseUrl);
  return NeyvoApi();
});

