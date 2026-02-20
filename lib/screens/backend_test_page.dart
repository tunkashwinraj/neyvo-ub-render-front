// lib/screens/backend_test_page.dart
// Backend connection test page for Neyvo Pulse

import 'dart:async';
import 'package:flutter/material.dart';
import '../../api/spearia_api.dart';
import '../../neyvo_pulse_api.dart';
import '../../theme/spearia_theme.dart';

class BackendTestPage extends StatefulWidget {
  const BackendTestPage({super.key});

  @override
  State<BackendTestPage> createState() => _BackendTestPageState();
}

class _BackendTestPageState extends State<BackendTestPage> {
  final List<TestResult> _results = [];
  bool _isRunning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBackendUrl();
  }

  void _loadBackendUrl() {
    setState(() {
      _error = null;
    });
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunning = true;
      _results.clear();
      _error = null;
    });

    final tests = [
      _Test('Health Check', '/api/pulse/health', 'GET', null),
      _Test('List Students', '/api/pulse/students', 'GET', null),
      _Test('List Payments', '/api/pulse/payments', 'GET', null),
      _Test('List Calls', '/api/pulse/calls', 'GET', null),
      _Test('Get Settings', '/api/pulse/settings', 'GET', null),
      _Test('Reports Summary', '/api/pulse/reports/summary', 'GET', null),
    ];

    for (final test in tests) {
      await _runTest(test);
      await Future.delayed(const Duration(milliseconds: 300)); // Small delay between tests
    }

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _runTest(_Test test) async {
    final stopwatch = Stopwatch()..start();
    TestResult result;

    try {
      dynamic response;
      
      if (test.method == 'GET') {
        response = await SpeariaApi.getJson(test.path);
      } else if (test.method == 'POST') {
        response = await SpeariaApi.postJson(test.path, body: test.body ?? {});
      } else {
        throw Exception('Unsupported method: ${test.method}');
      }

      stopwatch.stop();
      
      result = TestResult(
        name: test.name,
        path: test.path,
        method: test.method,
        status: 'Success',
        statusCode: 200,
        responseTime: stopwatch.elapsedMilliseconds,
        response: response,
        error: null,
      );
    } catch (e) {
      stopwatch.stop();
      
      int? statusCode;
      String errorMsg = e.toString();
      
      if (e is ApiException) {
        statusCode = e.statusCode;
        errorMsg = e.message;
      }

      result = TestResult(
        name: test.name,
        path: test.path,
        method: test.method,
        status: 'Failed',
        statusCode: statusCode,
        responseTime: stopwatch.elapsedMilliseconds,
        response: null,
        error: errorMsg,
      );
    }

    setState(() {
      _results.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpeariaAura.bg,
      appBar: AppBar(
        title: const Text('Backend Connection Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runAllTests,
            tooltip: 'Run All Tests',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        children: [
          // Backend URL Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SpeariaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: SpeariaAura.primary),
                      const SizedBox(width: SpeariaSpacing.md),
                      Text(
                        'Backend Configuration',
                        style: SpeariaType.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: SpeariaSpacing.md),
                  Text(
                    'Base URL:',
                    style: SpeariaType.labelMedium,
                  ),
                  const SizedBox(height: SpeariaSpacing.xs),
                  SelectableText(
                    SpeariaApi.baseUrl.isEmpty ? '(Not configured)' : SpeariaApi.baseUrl,
                    style: SpeariaType.bodyMedium.copyWith(
                      color: SpeariaApi.baseUrl.isEmpty 
                          ? SpeariaAura.error 
                          : SpeariaAura.textPrimary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: SpeariaSpacing.lg),
          
          // Test Button
          FilledButton.icon(
            onPressed: _isRunning ? null : _runAllTests,
            icon: _isRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_isRunning ? 'Running Tests...' : 'Run All Tests'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: SpeariaSpacing.xl,
                vertical: SpeariaSpacing.md,
              ),
            ),
          ),
          
          const SizedBox(height: SpeariaSpacing.lg),
          
          // Results
          if (_results.isEmpty && !_isRunning)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SpeariaSpacing.xl),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, 
                        size: 48, 
                        color: SpeariaAura.textMuted,
                      ),
                      const SizedBox(height: SpeariaSpacing.md),
                      Text(
                        'No tests run yet',
                        style: SpeariaType.bodyMedium.copyWith(
                          color: SpeariaAura.textMuted,
                        ),
                      ),
                      const SizedBox(height: SpeariaSpacing.sm),
                      Text(
                        'Click "Run All Tests" to check backend connection',
                        style: SpeariaType.bodySmall.copyWith(
                          color: SpeariaAura.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          if (_results.isNotEmpty) ...[
            Text(
              'Test Results (${_results.length})',
              style: SpeariaType.titleLarge,
            ),
            const SizedBox(height: SpeariaSpacing.md),
            ..._results.map((result) => _TestResultCard(result: result)),
          ],
        ],
      ),
    );
  }
}

class _TestResultCard extends StatelessWidget {
  final TestResult result;

  const _TestResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isSuccess = result.status == 'Success';
    final color = isSuccess ? SpeariaAura.success : SpeariaAura.error;
    
    return Card(
      margin: const EdgeInsets.only(bottom: SpeariaSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(SpeariaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: SpeariaSpacing.md),
                Expanded(
                  child: Text(
                    result.name,
                    style: SpeariaType.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpeariaSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    result.status,
                    style: SpeariaType.labelSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: SpeariaSpacing.sm),
            
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpeariaSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: SpeariaAura.bgDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    result.method,
                    style: SpeariaType.labelSmall.copyWith(
                      color: SpeariaAura.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: SpeariaSpacing.sm),
                Expanded(
                  child: Text(
                    result.path,
                    style: SpeariaType.bodySmall.copyWith(
                      color: SpeariaAura.textSecondary,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: SpeariaSpacing.xs),
            
            Row(
              children: [
                if (result.statusCode != null)
                  Text(
                    'Status: ${result.statusCode}',
                    style: SpeariaType.bodySmall.copyWith(
                      color: SpeariaAura.textMuted,
                    ),
                  ),
                if (result.statusCode != null)
                  const SizedBox(width: SpeariaSpacing.md),
                Text(
                  'Time: ${result.responseTime}ms',
                  style: SpeariaType.bodySmall.copyWith(
                    color: SpeariaAura.textMuted,
                  ),
                ),
              ],
            ),
            
            if (result.error != null) ...[
              const SizedBox(height: SpeariaSpacing.sm),
              Container(
                padding: const EdgeInsets.all(SpeariaSpacing.md),
                decoration: BoxDecoration(
                  color: SpeariaAura.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(SpeariaRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, 
                      color: SpeariaAura.error, 
                      size: 16,
                    ),
                    const SizedBox(width: SpeariaSpacing.sm),
                    Expanded(
                      child: Text(
                        result.error!,
                        style: SpeariaType.bodySmall.copyWith(
                          color: SpeariaAura.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (result.response != null) ...[
              const SizedBox(height: SpeariaSpacing.sm),
              ExpansionTile(
                title: Text(
                  'Response Data',
                  style: SpeariaType.labelMedium,
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(SpeariaSpacing.md),
                    decoration: BoxDecoration(
                      color: SpeariaAura.bgDark,
                      borderRadius: BorderRadius.circular(SpeariaRadius.sm),
                    ),
                    child: SelectableText(
                      _formatResponse(result.response),
                      style: SpeariaType.bodySmall.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
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

  String _formatResponse(dynamic response) {
    if (response is Map || response is List) {
      // Simple JSON-like formatting
      return response.toString();
    }
    return response.toString();
  }
}

class TestResult {
  final String name;
  final String path;
  final String method;
  final String status;
  final int? statusCode;
  final int responseTime;
  final dynamic response;
  final String? error;

  TestResult({
    required this.name,
    required this.path,
    required this.method,
    required this.status,
    this.statusCode,
    required this.responseTime,
    this.response,
    this.error,
  });
}

class _Test {
  final String name;
  final String path;
  final String method;
  final Map<String, dynamic>? body;

  _Test(this.name, this.path, this.method, this.body);
}
