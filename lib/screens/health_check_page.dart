import 'package:flutter/material.dart';

import '../api/neyvo_api.dart';
import '../neyvo_pulse_api.dart';

class HealthCheckPage extends StatefulWidget {
  const HealthCheckPage({super.key});

  @override
  State<HealthCheckPage> createState() => _HealthCheckPageState();
}

class _HealthCheckPageState extends State<HealthCheckPage> {
  final List<_EndpointResult> _results = [];
  bool _isRunning = false;

  Future<void> _runAll() async {
    setState(() {
      _isRunning = true;
      _results.clear();
    });

    final tests = <_EndpointTest>[
      _EndpointTest('GET /health', '/health', _EndpointResponseType.text),
      _EndpointTest('GET /ping', '/ping', _EndpointResponseType.text),
      _EndpointTest('GET /healthz', '/healthz', _EndpointResponseType.text),
      _EndpointTest('GET /webhooks/vapi/test', '/webhooks/vapi/test', _EndpointResponseType.text),
      _EndpointTest('GET /webhooks/vapi/health', '/webhooks/vapi/health', _EndpointResponseType.json),
      _EndpointTest('GET /api/pulse/health', '/api/pulse/health', _EndpointResponseType.json),
      _EndpointTest('GET /api/pulse/health/inbound', '/api/pulse/health/inbound', _EndpointResponseType.json, usePulseHelper: true),
      _EndpointTest('GET /api/templates', '/api/templates', _EndpointResponseType.json),
      _EndpointTest('GET /api/voice-profiles/library', '/api/voice-profiles/library', _EndpointResponseType.json),
      _EndpointTest('GET /api/billing/wallet', '/api/billing/wallet', _EndpointResponseType.json),
      _EndpointTest('GET /api/billing/tier', '/api/billing/tier', _EndpointResponseType.json),
      _EndpointTest('GET /api/agents', '/api/agents', _EndpointResponseType.json),
      _EndpointTest('GET /api/campaigns', '/api/campaigns', _EndpointResponseType.json),
      _EndpointTest('GET /api/studio/projects', '/api/studio/projects', _EndpointResponseType.json),
      _EndpointTest('GET /api/analytics/overview', '/api/analytics/overview', _EndpointResponseType.json),
    ];

    for (final t in tests) {
      await _runTest(t);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    if (mounted) {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _runTest(_EndpointTest test) async {
    final sw = Stopwatch()..start();
    _EndpointResult result;
    try {
      dynamic response;
      if (test.usePulseHelper && test.path == '/api/pulse/health/inbound') {
        response = await NeyvoPulseApi.getInboundHealthCheck();
      } else {
        switch (test.responseType) {
          case _EndpointResponseType.text:
            response = await NeyvoApi.getText(test.path);
            break;
          case _EndpointResponseType.json:
            response = await NeyvoApi.getJsonMap(test.path);
            break;
        }
      }
      sw.stop();
      result = _EndpointResult(
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
      result = _EndpointResult(
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
    if (!mounted) return;
    setState(() {
      _results.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Endpoint Health Check'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runAll,
            tooltip: 'Run all checks',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Run a quick check against the core backend endpoints to confirm that the backend is healthy and wired correctly.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _runAll,
              icon: _isRunning
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? 'Running…' : 'Run All Checks'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('No checks run yet.'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        return _ResultCard(result: _results[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _EndpointResponseType { text, json }

class _EndpointTest {
  final String name;
  final String path;
  final _EndpointResponseType responseType;
  final bool usePulseHelper;

  const _EndpointTest(this.name, this.path, this.responseType, {this.usePulseHelper = false});
}

class _EndpointResult {
  final String name;
  final String path;
  final String method;
  final String status;
  final int? statusCode;
  final int responseTimeMs;
  final dynamic response;
  final String? error;

  const _EndpointResult({
    required this.name,
    required this.path,
    required this.method,
    required this.status,
    this.statusCode,
    required this.responseTimeMs,
    this.response,
    this.error,
  });
}

class _ResultCard extends StatelessWidget {
  final _EndpointResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final bool ok = result.status == 'Success';
    final Color color = ok ? Colors.green : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ok ? Icons.check_circle : Icons.error, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    result.status,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${result.method} ${result.path}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Status: ${result.statusCode ?? '-'} · ${result.responseTimeMs}ms',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (result.error != null) ...[
              const SizedBox(height: 8),
              Text(
                result.error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
              ),
            ],
            if (result.response != null) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                title: const Text('Response'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey.shade50,
                    child: SelectableText(
                      result.response.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

