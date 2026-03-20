import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/neyvo_api.dart';

export 'timezone_provider.dart';

final backendBaseUrlProvider = Provider<String>((ref) => NeyvoApi.baseUrl);

final apiClientProvider = Provider<NeyvoApi>((ref) {
  return NeyvoApi();
});

