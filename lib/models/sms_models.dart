// SMS templates + Twilio platform config (FastAPI).

class SmsConfig {
  final bool configured;
  final String? fromMasked;

  const SmsConfig({
    required this.configured,
    this.fromMasked,
  });

  factory SmsConfig.fromJson(Map<String, dynamic> json) {
    return SmsConfig(
      configured: json['configured'] == true,
      fromMasked: json['from_masked']?.toString(),
    );
  }
}

class SmsTemplate {
  final String id;
  final String name;
  final String body;
  final List<String> variables;
  final int charCount;
  final int segments;

  const SmsTemplate({
    required this.id,
    required this.name,
    required this.body,
    required this.variables,
    required this.charCount,
    required this.segments,
  });

  factory SmsTemplate.fromJson(Map<String, dynamic> json) {
    final vars = json['variables'];
    return SmsTemplate(
      id: json['id']?.toString() ?? json['template_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      variables: vars is List ? vars.map((e) => e.toString()).toList() : const [],
      charCount: int.tryParse(json['char_count']?.toString() ?? '') ?? 0,
      segments: int.tryParse(json['segments']?.toString() ?? '') ?? 1,
    );
  }
}
