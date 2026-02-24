// lib/screens/backend_test_page.dart
// Backend connection test page for Neyvo Pulse – health, Pulse API, Billing, Stripe, Admin.

import 'dart:async';
import 'package:flutter/material.dart';
import '../api/spearia_api.dart';
import '../theme/spearia_theme.dart';

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
      // —— Launch / core (neyvo-launch.onrender.com) ——
      _Test('Health (root)', '/health', 'GET'),
      _Test('Ping', '/ping', 'GET'),
      _Test('Healthz', '/healthz', 'GET'),
      _Test('Vapi Webhook Test', '/webhooks/vapi/test', 'GET'),
      _Test('Vapi Webhook Health', '/webhooks/vapi/health', 'GET'),
      _Test('Vapi Signature Rejection', '/webhooks/vapi/events', 'POST',
        body: {'message': {'type': 'assistant-request'}},
        headers: {'x-vapi-signature': 'sha256=invalid'},
        expectStatusCodes: [400, 401],
      ),
      // —— Unified API ——
      _Test('Templates', '/api/templates', 'GET'),
      _Test('Voice Profiles Library', '/api/voice-profiles/library', 'GET'),
      _Test('Agents', '/api/agents', 'GET'),
      _Test('Campaigns', '/api/campaigns', 'GET'),
      _Test('Studio Projects', '/api/studio/projects', 'GET'),
      _Test('Analytics Overview', '/api/analytics/overview', 'GET'),
      // —— Pulse / app ——
      _Test('Pulse Health', '/api/pulse/health', 'GET'),
      _Test('List Students', '/api/pulse/students', 'GET'),
      _Test('List Payments', '/api/pulse/payments', 'GET'),
      _Test('List Calls', '/api/pulse/calls', 'GET'),
      _Test('Get Settings', '/api/pulse/settings', 'GET'),
      _Test('Reports Summary', '/api/pulse/reports/summary', 'GET'),
      _Test('Outbound Numbers', '/api/pulse/outbound/phone-numbers', 'GET'),
      _Test('Outbound Capacity', '/api/pulse/outbound/capacity', 'GET'),
      _Test('Call Templates', '/api/pulse/call_templates', 'GET'),
      _Test('Campaigns (Pulse)', '/api/pulse/campaigns', 'GET'),
      _Test('Seed Verify', '/api/pulse/seed-verify', 'GET'),
      _Test('Insights', '/api/pulse/insights', 'GET'),
      _Test('Knowledge Policy', '/api/pulse/knowledge/policy', 'GET'),
      _Test('Knowledge FAQ', '/api/pulse/knowledge/faq', 'GET'),
      // —— Billing / Wallet ——
      _Test('Billing Wallet', '/api/billing/wallet', 'GET'),
      _Test('Billing Tier', '/api/billing/tier', 'GET'),
      _Test('Billing Subscription', '/api/billing/subscription', 'GET'),
      _Test('Billing Transactions', '/api/billing/transactions', 'GET', params: {'limit': 5}),
      _Test('Billing Usage', '/api/billing/usage', 'GET'),
      _Test('Stripe Create Checkout Session', '/api/billing/wallet/create-checkout-session', 'POST', body: {'pack': 'starter'}),
      // —— Admin (require admin token) ——
      _Test('Admin Billing Overview', '/api/admin/billing-overview', 'GET', adminAuth: true),
      _Test('Admin System Health', '/api/admin/system-health', 'GET', adminAuth: true),
      _Test('Admin Tier Configs', '/api/admin/tier-configs', 'GET', adminAuth: true),
      _Test('Admin Organizations', '/api/admin/organizations', 'GET', adminAuth: true, params: {'limit': 5}),
      _Test('Admin Pricing Config', '/api/admin/pricing-config', 'GET', adminAuth: true),
      _Test('Admin Numbers Stats', '/api/admin/numbers/stats', 'GET', adminAuth: true),
    ];

    for (final test in tests) {
      await _runTest(test);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _runTest(_Test test) async {
    final stopwatch = Stopwatch()..start();
    TestResult result;
    final params = test.params != null ? Map<String, dynamic>.from(test.params!) : null;
    final body = test.body != null ? Map<String, dynamic>.from(test.body!) : null;
    final adminAuth = test.adminAuth ?? false;
    final headers = test.headers != null ? Map<String, String>.from(test.headers!) : null;
    final expectStatusCodes = test.expectStatusCodes;

    try {
      dynamic response;
      if (test.method == 'GET') {
        response = await SpeariaApi.getJson(
          test.path,
          params: params,
          headers: headers,
          adminAuth: adminAuth,
        );
      } else if (test.method == 'POST') {
        response = await SpeariaApi.postJson(
          test.path,
          body: body ?? {},
          params: params,
          headers: headers,
          adminAuth: adminAuth,
        );
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
      // Treat expected 4xx (e.g. signature rejection) as success
      final expectedFail = expectStatusCodes != null &&
          statusCode != null &&
          expectStatusCodes.contains(statusCode);
      result = TestResult(
        name: test.name,
        path: test.path,
        method: test.method,
        status: expectedFail ? 'Success' : 'Failed',
        statusCode: statusCode,
        responseTime: stopwatch.elapsedMilliseconds,
        response: expectedFail ? {'expected_status': statusCode} : null,
        error: expectedFail ? null : errorMsg,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
        title: const Text('Developer'),
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
  final Map<String, dynamic>? params;
  final Map<String, String>? headers;
  final List<int>? expectStatusCodes;
  final bool? adminAuth;

  _Test(
    this.name,
    this.path,
    this.method, {
    this.body,
    this.params,
    this.headers,
    this.expectStatusCodes,
    this.adminAuth,
  });
}
