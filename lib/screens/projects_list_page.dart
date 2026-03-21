// File: projects_list_page.dart
// Purpose: Neyvo unified – list Studio projects; FAB opens 3-step creation wizard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/studio_projects_list_provider.dart';
import '../pulse_route_names.dart';
import 'project_creation_wizard.dart';

class ProjectsListPage extends ConsumerWidget {
  const ProjectsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studioProjectsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(e.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(studioProjectsListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (projects) => _ProjectsBody(projects: projects, ref: ref),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            builder: (ctx) => const ProjectCreationWizard(),
          );
          if (created == true) ref.invalidate(studioProjectsListProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ProjectsBody extends StatelessWidget {
  const _ProjectsBody({required this.projects, required this.ref});

  final List<dynamic> projects;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
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
                if (created == true) ref.invalidate(studioProjectsListProvider);
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
      itemCount: projects.length,
      itemBuilder: (context, i) {
        final p = projects[i] as Map<String, dynamic>;
        final name = p['name'] as String? ?? 'Untitled';
        final id = p['id'] as String? ?? '';
        final type = p['type'] as String? ?? 'tts';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(name),
            subtitle: Text(type),
            onTap: () {
              Navigator.of(context).pushNamed(PulseRouteNames.projectDetail, arguments: id);
            },
          ),
        );
      },
    );
  }
}
