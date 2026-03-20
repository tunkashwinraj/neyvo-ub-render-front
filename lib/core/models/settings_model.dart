class SettingsModel {
  const SettingsModel({
    this.calendlyUrl = '',
    this.smtpHost = '',
    this.smtpPort = 0,
    this.smtpUsername = '',
    this.smtpPassword = '',
  });

  final String calendlyUrl;
  final String smtpHost;
  final int smtpPort;
  final String smtpUsername;
  final String smtpPassword;

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'] is Map
        ? Map<String, dynamic>.from(json['settings'] as Map)
        : json;
    return SettingsModel(
      calendlyUrl: (settings['calendly_url'] ?? '').toString(),
      smtpHost: (settings['smtp_host'] ?? '').toString(),
      smtpPort: (settings['smtp_port'] as num?)?.toInt() ?? 0,
      smtpUsername: (settings['smtp_username'] ?? '').toString(),
      smtpPassword: (settings['smtp_password'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calendly_url': calendlyUrl,
      'smtp_host': smtpHost,
      'smtp_port': smtpPort,
      'smtp_username': smtpUsername,
      'smtp_password': smtpPassword,
    };
  }
}
