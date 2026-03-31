// File: project_detail_page.dart
// Purpose: Neyvo unified – project detail and script editor (Studio).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/studio_project_detail_provider.dart';
import '../neyvo_pulse_api.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  final TextEditingController _scriptController = TextEditingController();
  String _scriptSig = '';

  @override
  void dispose() {
    _scriptController.dispose();
    super.dispose();
  }

  void _syncScriptFromProject(Map<String, dynamic> p) {
    final scripts = p['scripts'] as List?;
    if (scripts != null && scripts.isNotEmpty) {
      final first = scripts.first as Map<String, dynamic>?;
      _scriptController.text = (first?['text'] as String?) ?? '';
    }
  }

  Future<void> _generateTts() async {
    final text = _scriptController.text.trim();
    if (text.isEmpty) return;
    try {
      final res = await NeyvoPulseApi.generateTts(projectId: widget.projectId, text: text);
      if (res['ok'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TTS generated')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] as String? ?? 'Failed')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studioProjectDetailProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?['name'] as String? ?? 'Project'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(studioProjectDetailProvider(widget.projectId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(e.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(studioProjectDetailProvider(widget.projectId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (project) {
          final sig = '${project['id']}_${project['updated_at']}';
          if (sig != _scriptSig) {
            _scriptSig = sig;
            _syncScriptFromProject(project);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _scriptController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Script',
                    hintText: 'Enter text for voiceover',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _generateTts,
                  icon: const Icon(Icons.record_voice_over),
                  label: const Text('Generate TTS'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
