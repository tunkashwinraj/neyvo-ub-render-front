import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../api/neyvo_api.dart';
import '../../config/backend_urls.dart';

export 'timezone_provider.dart';

final apiBaseUrlProvider = Provider<String>((ref) {
  return resolveNeyvoApiBaseUrl();
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

