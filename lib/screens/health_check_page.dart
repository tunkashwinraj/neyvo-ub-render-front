import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/health_check_provider.dart';

class HealthCheckPage extends ConsumerWidget {
  const HealthCheckPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(healthCheckRunProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Endpoint Health Check'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: ui.isRunning ? null : () => ref.read(healthCheckRunProvider.notifier).runAll(),
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
              onPressed: ui.isRunning ? null : () => ref.read(healthCheckRunProvider.notifier).runAll(),
              icon: ui.isRunning
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: Text(ui.isRunning ? 'Running…' : 'Run All Checks'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ui.results.isEmpty
                  ? const Center(child: Text('No checks run yet.'))
                  : ListView.builder(
                      itemCount: ui.results.length,
                      itemBuilder: (context, index) {
                        return _ResultCard(result: ui.results[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final HealthEndpointResult result;

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
