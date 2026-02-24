// File: projects_list_page.dart
// Purpose: Neyvo unified – list Studio projects; FAB opens 3-step creation wizard.
// Surface: studio
// Connected to: GET /api/studio/projects, POST /api/studio/projects

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import 'project_creation_wizard.dart';

class ProjectsListPage extends StatefulWidget {
  const ProjectsListPage({super.key});

  @override
  State<ProjectsListPage> createState() => _ProjectsListPageState();
}

class _ProjectsListPageState extends State<ProjectsListPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _projects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await NeyvoPulseApi.listStudioProjects();
      if (res['ok'] == true && res['projects'] != null) {
        setState(() { _projects = List<dynamic>.from(res['projects'] as List); _loading = false; });
      } else {
        setState(() { _error = res['error'] as String? ?? 'Failed to load'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: _body(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            builder: (ctx) => const ProjectCreationWizard(),
          );
          if (created == true) _load();
        },
        child: const Icon(Icons.add),
      ),
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
    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No projects yet'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                final created = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => const ProjectCreationWizard(),
                );
                if (created == true) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('Create project'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _projects.length,
      itemBuilder: (context, i) {
        final p = _projects[i] as Map<String, dynamic>;
        final name = p['name'] as String? ?? 'Untitled';
        final id = p['id'] as String? ?? '';
        final type = p['type'] as String? ?? 'tts';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(name),
            subtitle: Text(type),
            onTap: () {
              // Navigate to project detail / script editor when route exists
              Navigator.of(context).pushNamed(PulseRouteNames.projectDetail, arguments: id);
            },
          ),
        );
      },
    );
  }
}
