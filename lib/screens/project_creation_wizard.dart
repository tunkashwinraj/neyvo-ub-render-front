// File: project_creation_wizard.dart
// Purpose: Neyvo unified – 3-step Project Creation Wizard (type, voice, name).
// Surface: studio
// Connected to: GET /api/voice-profiles/library, POST /api/studio/projects

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';

class ProjectCreationWizard extends StatefulWidget {
  const ProjectCreationWizard({super.key});

  @override
  State<ProjectCreationWizard> createState() => _ProjectCreationWizardState();
}

class _ProjectCreationWizardState extends State<ProjectCreationWizard> {
  int _step = 0;
  static const int _totalSteps = 3;
  String _type = 'voiceover';
  String? _voiceProfileId;
  String _projectName = '';
  List<dynamic> _voices = [];
  bool _loadingVoices = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    setState(() => _loadingVoices = true);
    try {
      final res = await NeyvoPulseApi.listVoiceProfilesLibrary();
      if (res['ok'] == true && res['profiles'] != null) {
        setState(() { _voices = List<dynamic>.from(res['profiles'] as List); _loadingVoices = false; });
      } else {
        setState(() => _loadingVoices = false);
      }
    } catch (_) {
      setState(() => _loadingVoices = false);
    }
  }

  Future<void> _createProject() async {
    if (_projectName.trim().isEmpty) return;
    setState(() { _saving = true; _error = null; });
    try {
      final res = await NeyvoPulseApi.createStudioProject(
        name: _projectName.trim(),
        type: _type == 'voiceover' ? 'tts' : _type == 'clone' ? 'clone' : 'dub',
        voiceProfileId: _voiceProfileId,
      );
      if (res['ok'] == true && mounted) {
        Navigator.of(context).pop(true);
      } else {
        setState(() { _error = res['error'] as String? ?? 'Failed'; _saving = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('New project', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              LinearProgressIndicator(value: (_step + 1) / _totalSteps),
              const SizedBox(height: 16),
              if (_step == 0) _buildStepType(),
              if (_step == 1) _buildStepVoice(),
              if (_step == 2) _buildStepName(),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_step > 0) TextButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
                  if (_step < _totalSteps - 1)
                    FilledButton(onPressed: () => setState(() => _step++), child: const Text('Next'))
                  else
                    FilledButton(
                      onPressed: (_saving || _projectName.trim().isEmpty) ? null : _createProject,
                      child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Project type'),
        const SizedBox(height: 12),
        ...['voiceover', 'clone', 'dub'].map((t) => RadioListTile<String>(
          title: Text(t == 'voiceover' ? 'Voiceover (TTS)' : t == 'clone' ? 'Voice clone' : 'Dub'),
          value: t,
          groupValue: _type,
          onChanged: (v) => setState(() => _type = v!),
        )),
      ],
    );
  }

  Widget _buildStepVoice() {
    if (_loadingVoices) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose voice'),
        const SizedBox(height: 8),
        if (_voices.isEmpty) const Text('No voices in library.'),
        ..._voices.map((v) {
          final id = v['id'] as String?;
          final name = v['display_name'] as String? ?? v['name'] as String? ?? id;
          return ListTile(
            title: Text(name ?? ''),
            selected: _voiceProfileId == id,
            onTap: () => setState(() => _voiceProfileId = id),
          );
        }),
      ],
    );
  }

  Widget _buildStepName() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Project name'),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(hintText: 'e.g. Product intro'),
          onChanged: (v) => setState(() => _projectName = v),
        ),
      ],
    );
  }
}
