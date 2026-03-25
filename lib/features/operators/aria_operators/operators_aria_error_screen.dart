import 'package:flutter/material.dart';

import '../../../pulse_route_names.dart';

/// Full-screen ARIA / Vapi failure details (replaces transient SnackBars).
class OperatorsAriaErrorScreen extends StatelessWidget {
  const OperatorsAriaErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final message = args is String ? args : (args?.toString() ?? 'Unknown error');

    return Scaffold(
      appBar: AppBar(
        title: const Text('ARIA connection issue'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'The voice session could not continue. Details below. Common causes: blocked CDN (jsdelivr / esm.sh), wrong Vapi public key or assistant ID for this account, or microphone blocked.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: SelectableText(
                      message,
                      style: const TextStyle(fontSize: 13, height: 1.35, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed(PulseRouteNames.operatorsRoot);
                      },
                      child: const Text('All operators'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed(PulseRouteNames.operatorsNew);
                      },
                      child: const Text('Try again'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
