// Models for ARIA Operators UI.

class AriaOperatorCard {
  final String operatorId;
  final String personaName;
  final String industry;
  final String operatorRole;
  final String operatorSummary;
  final String status;

  const AriaOperatorCard({
    required this.operatorId,
    required this.personaName,
    required this.industry,
    required this.operatorRole,
    required this.operatorSummary,
    required this.status,
  });

  static AriaOperatorCard fromJson(Map<String, dynamic> json) {
    return AriaOperatorCard(
      operatorId: (json['operator_id'] ?? json['operatorId'] ?? '').toString(),
      personaName: (json['persona_name'] ?? json['personaName'] ?? 'Operator').toString(),
      industry: (json['industry'] ?? '').toString(),
      operatorRole: (json['operator_role'] ?? json['operatorRole'] ?? '').toString(),
      operatorSummary: (json['operator_summary'] ?? json['operatorSummary'] ?? '').toString(),
      status: (json['status'] ?? 'building').toString(),
    );
  }
}

class AriaOperatorStatus {
  final String status; // building | extracting_profile | ... | live | error
  final int currentStep;
  final String errorMessage;

  const AriaOperatorStatus({
    required this.status,
    required this.currentStep,
    required this.errorMessage,
  });

  static AriaOperatorStatus fromJson(Map<String, dynamic> json) {
    return AriaOperatorStatus(
      status: (json['status'] ?? 'building').toString(),
      currentStep: int.tryParse((json['current_step'] ?? 0).toString()) ?? 0,
      errorMessage: (json['error_message'] ?? '').toString(),
    );
  }
}

