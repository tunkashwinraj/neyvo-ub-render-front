import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/neyvo_api.dart' show ApiException, NeyvoApi;
import '../../neyvo_pulse_api.dart';

part 'health_check_provider.g.dart';

enum HealthEndpointResponseType { text, json }

class HealthEndpointTest {
  const HealthEndpointTest(this.name, this.path, this.responseType, {this.usePulseHelper = false});

  final String name;
  final String path;
  final HealthEndpointResponseType responseType;
  final bool usePulseHelper;
}

class HealthEndpointResult {
  const HealthEndpointResult({
    required this.name,
    required this.path,
    required this.method,
    required this.status,
    this.statusCode,
    required this.responseTimeMs,
    this.response,
    this.error,
  });

  final String name;
  final String path;
  final String method;
  final String status;
  final int? statusCode;
  final int responseTimeMs;
  final dynamic response;
  final String? error;
}

class HealthCheckUiState {
  const HealthCheckUiState({this.isRunning = false, this.results = const []});

  final bool isRunning;
  final List<HealthEndpointResult> results;

  HealthCheckUiState copyWith({bool? isRunning, List<HealthEndpointResult>? results}) {
    return HealthCheckUiState(
      isRunning: isRunning ?? this.isRunning,
      results: results ?? this.results,
    );
  }
}

@riverpod
class HealthCheckRun extends _$HealthCheckRun {
  @override
  HealthCheckUiState build() => const HealthCheckUiState();

  static const List<HealthEndpointTest> _tests = [
    HealthEndpointTest('GET /health', '/health', HealthEndpointResponseType.text),
    HealthEndpointTest('GET /ping', '/ping', HealthEndpointResponseType.text),
    HealthEndpointTest('GET /healthz', '/healthz', HealthEndpointResponseType.text),
    HealthEndpointTest('GET /webhooks/vapi/test', '/webhooks/vapi/test', HealthEndpointResponseType.text),
    HealthEndpointTest('GET /webhooks/vapi/health', '/webhooks/vapi/health', HealthEndpointResponseType.json),
    HealthEndpointTest('GET /api/pulse/health', '/api/pulse/health', HealthEndpointResponseType.json),
    HealthEndpointTest(
      'GET /api/pulse/health/inbound',
      '/api/pulse/health/inbound',
      HealthEndpointResponseType.json,
      usePulseHelper: true,
    ),
    HealthEndpointTest('GET /api/templates', '/api/templates', HealthEndpointResponseType.json),
    HealthEndpointTest('GET /api/voice-profiles/library', '/api/voice-profiles/library', HealthEndpointResponseType.json),
    HealthEndpointTest('GET /api/billing/wallet', '/api/billing/wallet', HealthEndpointResponseType.json),
    HealthEndpointTest('GET /api/billing/tier', '/api/billing/tier', HealthEndpointResponseType.json),
    HealthEndpointTest('GET /api/agents', '/api/agents', HealthEndpointResponseType.json),
    HealthEndpointTest('GET /api/campaigns', '/api/campaigns', HealthEndpointResponseType.json),
    HealthEndpointTest('GET /api/studio/projects', '/api/studio/projects', HealthEndpointResponseType.json),
    HealthEndpointTest('GET /api/analytics/overview', '/api/analytics/overview', HealthEndpointResponseType.json),
  ];

  Future<void> runAll() async {
    state = state.copyWith(isRunning: true, results: []);
    for (final t in _tests) {
      await _runTest(t);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    state = state.copyWith(isRunning: false);
  }

  Future<void> _runTest(HealthEndpointTest test) async {
    final sw = Stopwatch()..start();
    late final HealthEndpointResult result;
    try {
      dynamic response;
      if (test.usePulseHelper && test.path == '/api/pulse/health/inbound') {
        response = await NeyvoPulseApi.getInboundHealthCheck();
      } else {
        switch (test.responseType) {
          case HealthEndpointResponseType.text:
            response = await NeyvoApi.getText(test.path);
            break;
          case HealthEndpointResponseType.json:
            response = await NeyvoApi.getJsonMap(test.path);
            break;
        }
      }
      sw.stop();
      result = HealthEndpointResult(
        name: test.name,
        path: test.path,
        method: 'GET',
        status: 'Success',
        statusCode: 200,
        responseTimeMs: sw.elapsedMilliseconds,
        response: response,
        error: null,
      );
    } catch (e) {
      sw.stop();
      int? status;
      if (e is ApiException) status = e.statusCode;
      result = HealthEndpointResult(
        name: test.name,
        path: test.path,
        method: 'GET',
        status: 'Failed',
        statusCode: status,
        responseTimeMs: sw.elapsedMilliseconds,
        response: null,
        error: e.toString(),
      );
    }
    state = state.copyWith(results: [...state.results, result]);
  }
}
