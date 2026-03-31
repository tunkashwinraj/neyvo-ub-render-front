// Voice Library – list global voice profiles (Studio).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/voice_library_provider.dart';

class VoiceLibraryPage extends ConsumerWidget {
  const VoiceLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voiceLibraryListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Library')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(e.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(voiceLibraryListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (profiles) {
          if (profiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.record_voice_over_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No voice profiles in library'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            itemBuilder: (context, i) {
              final p = profiles[i] as Map<String, dynamic>;
              final name = p['display_name'] as String? ?? p['internal_name'] as String? ?? p['id'] as String? ?? '';
              final desc = p['description'] as String? ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(name),
                  subtitle: desc.isNotEmpty ? Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
