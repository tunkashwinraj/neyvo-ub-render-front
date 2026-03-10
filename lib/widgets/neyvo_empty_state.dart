// lib/widgets/neyvo_empty_state.dart
// Shared empty, loading, and error states per Step 9 spec.

import 'package:flutter/material.dart';
import '../theme/neyvo_theme.dart';

/// Centered empty state: dashed teal box + icon, title, subtitle, teal action button.
Widget buildNeyvoEmptyState({
  required BuildContext context,
  required String title,
  required String subtitle,
  required String buttonLabel,
  required VoidCallback onAction,
  IconData icon = Icons.inbox_outlined,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(NeyvoSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: NeyvoTheme.teal, width: 2, strokeAlign: BorderSide.strokeAlignInside),
              borderRadius: BorderRadius.circular(NeyvoRadius.md),
            ),
            child: Icon(icon, size: 48, color: NeyvoTheme.teal),
          ),
          const SizedBox(height: NeyvoSpacing.xl),
          Text(
            title,
            style: NeyvoType.titleLarge.copyWith(color: NeyvoTheme.textPrimary, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NeyvoSpacing.sm),
          Text(
            subtitle,
            style: NeyvoType.bodyMedium.copyWith(color: NeyvoTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NeyvoSpacing.xl),
          FilledButton(
            onPressed: onAction,
            child: Text(buttonLabel),
          ),
        ],
      ),
    ),
  );
}

/// Generic error state: "Something went wrong" + Retry button. Does not show raw error to user.
Widget buildNeyvoErrorState({
  required VoidCallback onRetry,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(NeyvoSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: NeyvoTheme.error),
          const SizedBox(height: NeyvoSpacing.lg),
          Text(
            'Something went wrong',
            style: NeyvoType.titleMedium.copyWith(color: NeyvoTheme.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NeyvoSpacing.sm),
          Text(
            'Please try again.',
            style: NeyvoType.bodySmall.copyWith(color: NeyvoTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NeyvoSpacing.xl),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

/// Simple loading skeleton: shimmer-style placeholder (circular indicator for now).
Widget buildNeyvoLoadingState() {
  return const Center(child: CircularProgressIndicator());
}
