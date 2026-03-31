/// Thrown when a tab-scoped HTTP GET was cancelled because the user switched
/// main Pulse sidebar tabs. Callers should ignore it (no SnackBar / error state).
class PulseRequestCancelled implements Exception {
  const PulseRequestCancelled();

  @override
  String toString() => 'PulseRequestCancelled';
}

bool isPulseRequestCancelled(Object? e) => e is PulseRequestCancelled;
