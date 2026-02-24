// File: project_detail_page.dart
// Purpose: Neyvo unified – project detail and script editor (Studio).
// Connected to: GET/PATCH /api/studio/projects/:id, POST /api/studio/generate

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({super.key, required this.projectId});
  final String projectId;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _project;
  final TextEditingController _scriptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scriptController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.projectId.isEmpty) {
      setState(() { _loading = false; _error = 'No project id'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await NeyvoPulseApi.getStudioProject(widget.projectId);
      if (res['ok'] == true && res['project'] != null) {
        final p = Map<String, dynamic>.from(res['project'] as Map);
        setState(() { _project = p; _loading = false; });
        final scripts = p['scripts'] as List?;
        if (scripts != null && scripts.isNotEmpty) {
          final first = scripts.first as Map<String, dynamic>?;
          _scriptController.text = (first?['text'] as String?) ?? '';
        }
      } else {
        setState(() { _error = res['error'] as String? ?? 'Not found'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_project?['name'] as String? ?? 'Project'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
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
  }
}
