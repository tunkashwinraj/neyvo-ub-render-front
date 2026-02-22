// lib/neyvo_pulse/screens/students_page.dart
// Placeholder students list (school can add Firestore/API later).

import 'package:flutter/material.dart';

import '../pulse_route_names.dart';
import '../../theme/spearia_theme.dart';

class StudentsPage extends StatelessWidget {
  const StudentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpeariaAura.bg,
      appBar: AppBar(
        title: const Text('Contacts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacementNamed(PulseRouteNames.dashboard),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(SpeariaSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contacts_outlined, size: 64, color: SpeariaAura.textMuted),
              const SizedBox(height: SpeariaSpacing.lg),
              Text(
                'Contacts',
                style: SpeariaType.headlineMedium,
              ),
              const SizedBox(height: SpeariaSpacing.sm),
              Text(
                'Connect your contact list (Firestore or CSV) to see balances and reach out from here.',
                textAlign: TextAlign.center,
                style: SpeariaType.bodyMedium.copyWith(color: SpeariaAura.textSecondary),
              ),
              const SizedBox(height: SpeariaSpacing.xl),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed(PulseRouteNames.outbound),
                child: const Text('Reach out now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
