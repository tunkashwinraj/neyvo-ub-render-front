// Exports – list or create Studio exports (placeholder until list API exists).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExportsPage extends ConsumerWidget {
  const ExportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exports')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Exports from Voice Studio'),
            const SizedBox(height: 8),
            Text(
              'Export a project from the Projects page to see it here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
