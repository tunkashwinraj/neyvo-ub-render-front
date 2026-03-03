// lib/ui/screens/business_interview/ai_log_event.dart
// Data model for AI console log entries.

enum AiLogLevel { info, success, warn, error, progress }

class AiLogEvent {
  final String id;
  final AiLogLevel level;
  final String message;
  final DateTime at;
  final bool isEphemeral;

  AiLogEvent({
    required this.id,
    required this.level,
    required this.message,
    required this.at,
    this.isEphemeral = false,
  });
}
