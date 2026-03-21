// Models for SendGrid integration and operator email templates.

class SendgridConfig {
  final bool enabled;
  final bool connected;
  final String? fromEmail;
  final String? updatedAt;
  /// True when using server env defaults (no per-tenant Firestore key).
  final bool platformManaged;
  /// Backend hint: tenant | platform | none
  final String? source;

  const SendgridConfig({
    required this.enabled,
    required this.connected,
    this.fromEmail,
    this.updatedAt,
    this.platformManaged = true,
    this.source,
  });

  factory SendgridConfig.fromJson(Map<String, dynamic> json) {
    return SendgridConfig(
      enabled: json['enabled'] == true,
      connected: json['connected'] == true,
      fromEmail: json['from_email']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      platformManaged: json['platform_managed'] != false,
      source: json['source']?.toString(),
    );
  }
}

class EmailTemplate {
  final String id;
  final String name;
  final String subject;
  final String body;
  final String? htmlBody;
  final List<String> variables;

  const EmailTemplate({
    required this.id,
    required this.name,
    required this.subject,
    required this.body,
    this.htmlBody,
    required this.variables,
  });

  factory EmailTemplate.fromJson(Map<String, dynamic> json) {
    final vars = json['variables'];
    return EmailTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      htmlBody: json['html_body']?.toString(),
      variables: vars is List ? vars.map((e) => e.toString()).toList() : const [],
    );
  }
}
