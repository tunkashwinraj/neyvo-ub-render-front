// lib/features/operators/universal_operator_wizard/universal_wizard_state.dart
// Dart models for Universal 5-Step Operator Wizard (v3). Mirrors TypeScript types from plan.

import 'dart:convert';

/// Step 1 — Business & Department Identity
class WizardStep1BusinessIdentity {
  final String businessName;
  final String industryVertical;
  final String? industryOther;
  final String department;
  final String? departmentOther;
  final String operatorDisplayName;
  final String language;
  final String locale;
  final Map<String, bool> complianceFlags;
  final String? mainPhone;

  const WizardStep1BusinessIdentity({
    this.businessName = '',
    this.industryVertical = 'Education',
    this.industryOther,
    this.department = 'admissions',
    this.departmentOther,
    this.operatorDisplayName = '',
    this.language = 'en-US',
    this.locale = 'en_US',
    this.complianceFlags = const {},
    this.mainPhone,
  });

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'industryVertical': industryVertical,
        if (industryOther != null && industryOther!.isNotEmpty) 'industryOther': industryOther,
        'department': department,
        if (departmentOther != null && departmentOther!.isNotEmpty) 'departmentOther': departmentOther,
        'operatorDisplayName': operatorDisplayName,
        'language': language,
        'locale': locale,
        'complianceFlags': complianceFlags,
        if (mainPhone != null && mainPhone!.isNotEmpty) 'main_phone': mainPhone,
      };

  static WizardStep1BusinessIdentity fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WizardStep1BusinessIdentity();
    final flags = json['complianceFlags'];
    return WizardStep1BusinessIdentity(
      businessName: (json['businessName'] ?? '').toString(),
      industryVertical: (json['industryVertical'] ?? 'Education').toString(),
      industryOther: json['industryOther']?.toString(),
      department: (json['department'] ?? 'Education').toString(),
      departmentOther: json['departmentOther']?.toString(),
      operatorDisplayName: (json['operatorDisplayName'] ?? '').toString(),
      language: (json['language'] ?? 'en-US').toString(),
      locale: (json['locale'] ?? 'en_US').toString(),
      complianceFlags: flags is Map ? Map<String, bool>.from(flags.map((k, v) => MapEntry(k.toString(), v == true))) : const {},
      mainPhone: json['main_phone'] ?? json['mainPhone']?.toString(),
    );
  }

  WizardStep1BusinessIdentity copyWith({
    String? businessName,
    String? industryVertical,
    String? industryOther,
    String? department,
    String? departmentOther,
    String? operatorDisplayName,
    String? language,
    String? locale,
    Map<String, bool>? complianceFlags,
    String? mainPhone,
  }) =>
      WizardStep1BusinessIdentity(
        businessName: businessName ?? this.businessName,
        industryVertical: industryVertical ?? this.industryVertical,
        industryOther: industryOther ?? this.industryOther,
        department: department ?? this.department,
        departmentOther: departmentOther ?? this.departmentOther,
        operatorDisplayName: operatorDisplayName ?? this.operatorDisplayName,
        language: language ?? this.language,
        locale: locale ?? this.locale,
        complianceFlags: complianceFlags ?? this.complianceFlags,
        mainPhone: mainPhone ?? this.mainPhone,
      );
}

/// Voice tone options (UI only; backend gets tone from personalityAdjectives).
const List<String> kVoiceToneIds = ['warm_friendly', 'professional_clear', 'calm_reassuring'];
const Map<String, String> kVoiceToneLabels = {
  'warm_friendly': 'Warm & friendly',
  'professional_clear': 'Professional & clear',
  'calm_reassuring': 'Calm & reassuring',
};

/// Step 2 — Voice only (tone + voice picker). No agent name, role, or technical sliders; tier handles config.
class WizardStep2PersonaVoice {
  final String voiceTone;
  final String voiceProvider;
  final String voiceId;
  final double stability;
  final double similarityBoost;
  final double style;

  const WizardStep2PersonaVoice({
    this.voiceTone = 'warm_friendly',
    this.voiceProvider = '11labs',
    this.voiceId = '',
    this.stability = 0.5,
    this.similarityBoost = 0.4,
    this.style = 0.3,
  });

  List<String> get personalityAdjectives {
    switch (voiceTone) {
      case 'professional_clear':
        return ['professional', 'clear'];
      case 'calm_reassuring':
        return ['calm', 'reassuring'];
      default:
        return ['warm', 'friendly'];
    }
  }

  Map<String, dynamic> toJson() => {
        'voiceTone': voiceTone,
        'personalityAdjectives': personalityAdjectives,
        'voiceProvider': voiceProvider,
        'voiceId': voiceId,
        'stability': stability,
        'similarityBoost': similarityBoost,
        'style': style,
      };

  static WizardStep2PersonaVoice fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WizardStep2PersonaVoice();
    final tone = (json['voiceTone'] ?? 'warm_friendly').toString();
    return WizardStep2PersonaVoice(
      voiceTone: kVoiceToneIds.contains(tone) ? tone : 'warm_friendly',
      voiceProvider: (json['voiceProvider'] ?? '11labs').toString(),
      voiceId: (json['voiceId'] ?? '').toString(),
      stability: (json['stability'] is num) ? (json['stability'] as num).toDouble() : 0.5,
      similarityBoost: (json['similarityBoost'] is num) ? (json['similarityBoost'] as num).toDouble() : 0.4,
      style: (json['style'] is num) ? (json['style'] as num).toDouble() : 0.3,
    );
  }

  WizardStep2PersonaVoice copyWith({
    String? voiceTone,
    String? voiceProvider,
    String? voiceId,
    double? stability,
    double? similarityBoost,
    double? style,
  }) =>
      WizardStep2PersonaVoice(
        voiceTone: voiceTone ?? this.voiceTone,
        voiceProvider: voiceProvider ?? this.voiceProvider,
        voiceId: voiceId ?? this.voiceId,
        stability: stability ?? this.stability,
        similarityBoost: similarityBoost ?? this.similarityBoost,
        style: style ?? this.style,
      );
}

/// Step 3 — Conversation step (single step in flow)
class ConversationStepModel {
  final String id;
  final String label;
  final String promptText;
  final String? ifYes;
  final String? ifNo;
  final bool waitForUser;
  final String? toolTrigger;
  final int order;

  const ConversationStepModel({
    required this.id,
    this.label = '',
    this.promptText = '',
    this.ifYes,
    this.ifNo,
    this.waitForUser = true,
    this.toolTrigger,
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'promptText': promptText,
        if (ifYes != null) 'ifYes': ifYes,
        if (ifNo != null) 'ifNo': ifNo,
        'waitForUser': waitForUser,
        if (toolTrigger != null) 'toolTrigger': toolTrigger,
        'order': order,
      };

  static ConversationStepModel fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ConversationStepModel(id: '');
    return ConversationStepModel(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      promptText: (json['promptText'] ?? '').toString(),
      ifYes: json['ifYes']?.toString(),
      ifNo: json['ifNo']?.toString(),
      waitForUser: json['waitForUser'] == true,
      toolTrigger: json['toolTrigger']?.toString(),
      order: (json['order'] is int) ? json['order'] as int : 0,
    );
  }
}

/// Refining question for goal-based follow-up (step after primary objective).
class RefiningQuestion {
  final String id;
  final String text;
  final String type; // 'checkbox', 'mcq', 'text'
  final List<String> options;

  const RefiningQuestion({required this.id, this.text = '', this.type = 'text', this.options = const []});

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'type': type, 'options': options};
  static RefiningQuestion fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RefiningQuestion(id: '');
    return RefiningQuestion(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      type: (json['type'] ?? 'text').toString(),
      options: json['options'] is List ? (json['options'] as List).map((e) => e.toString()).toList() : const [],
    );
  }
}

/// Step 3 — Conversation Goals + Refining Q&A (no call closing / fallback in UI; backend uses defaults).
class WizardStep3ConversationFlow {
  final String primaryObjective;
  final List<ConversationStepModel> steps;
  final String fallbackUnclearResponse;
  final int? fallbackSilenceTimeoutSeconds;
  final int? fallbackMaxRetriesBeforeEscalation;
  final String callClosingBehavior;
  final String? closingTransferNumber;
  final List<RefiningQuestion> refiningQuestions;
  final Map<String, dynamic> refiningAnswers;

  const WizardStep3ConversationFlow({
    this.primaryObjective = '',
    this.steps = const [],
    this.fallbackUnclearResponse = "I didn't catch that. Could you say that again?",
    this.fallbackSilenceTimeoutSeconds,
    this.fallbackMaxRetriesBeforeEscalation,
    this.callClosingBehavior = 'endCall',
    this.closingTransferNumber,
    this.refiningQuestions = const [],
    this.refiningAnswers = const {},
  });

  Map<String, dynamic> toJson() => {
        'primaryObjective': primaryObjective,
        'steps': steps.map((s) => s.toJson()).toList(),
        'fallbackUnclearResponse': fallbackUnclearResponse,
        if (fallbackSilenceTimeoutSeconds != null) 'fallbackSilenceTimeoutSeconds': fallbackSilenceTimeoutSeconds,
        if (fallbackMaxRetriesBeforeEscalation != null) 'fallbackMaxRetriesBeforeEscalation': fallbackMaxRetriesBeforeEscalation,
        'callClosingBehavior': callClosingBehavior,
        if (closingTransferNumber != null) 'closingTransferNumber': closingTransferNumber,
        'refiningQuestions': refiningQuestions.map((q) => q.toJson()).toList(),
        'refiningAnswers': refiningAnswers,
      };

  static WizardStep3ConversationFlow fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WizardStep3ConversationFlow();
    final stepsList = json['steps'];
    final rq = json['refiningQuestions'];
    final ra = json['refiningAnswers'];
    return WizardStep3ConversationFlow(
      primaryObjective: (json['primaryObjective'] ?? '').toString(),
      steps: stepsList is List
          ? stepsList.map((e) => ConversationStepModel.fromJson(e is Map ? Map<String, dynamic>.from(e) : null)).toList()
          : const [],
      fallbackUnclearResponse: (json['fallbackUnclearResponse'] ?? '').toString().isEmpty
          ? "I didn't catch that. Could you say that again?"
          : (json['fallbackUnclearResponse'] ?? '').toString(),
      fallbackSilenceTimeoutSeconds: json['fallbackSilenceTimeoutSeconds'] is int ? json['fallbackSilenceTimeoutSeconds'] as int : null,
      fallbackMaxRetriesBeforeEscalation: json['fallbackMaxRetriesBeforeEscalation'] is int ? json['fallbackMaxRetriesBeforeEscalation'] as int : null,
      callClosingBehavior: (json['callClosingBehavior'] ?? 'endCall').toString(),
      closingTransferNumber: json['closingTransferNumber']?.toString(),
      refiningQuestions: rq is List ? rq.map((e) => RefiningQuestion.fromJson(e is Map ? Map<String, dynamic>.from(e) : null)).toList() : const [],
      refiningAnswers: ra is Map ? Map<String, dynamic>.from(ra) : const {},
    );
  }

  WizardStep3ConversationFlow copyWith({
    String? primaryObjective,
    List<ConversationStepModel>? steps,
    String? fallbackUnclearResponse,
    int? fallbackSilenceTimeoutSeconds,
    int? fallbackMaxRetriesBeforeEscalation,
    String? callClosingBehavior,
    String? closingTransferNumber,
    List<RefiningQuestion>? refiningQuestions,
    Map<String, dynamic>? refiningAnswers,
  }) =>
      WizardStep3ConversationFlow(
        primaryObjective: primaryObjective ?? this.primaryObjective,
        steps: steps ?? this.steps,
        fallbackUnclearResponse: fallbackUnclearResponse ?? this.fallbackUnclearResponse,
        fallbackSilenceTimeoutSeconds: fallbackSilenceTimeoutSeconds ?? this.fallbackSilenceTimeoutSeconds,
        fallbackMaxRetriesBeforeEscalation: fallbackMaxRetriesBeforeEscalation ?? this.fallbackMaxRetriesBeforeEscalation,
        callClosingBehavior: callClosingBehavior ?? this.callClosingBehavior,
        closingTransferNumber: closingTransferNumber ?? this.closingTransferNumber,
        refiningQuestions: refiningQuestions ?? this.refiningQuestions,
        refiningAnswers: refiningAnswers ?? this.refiningAnswers,
      );
}

/// Step 4 — Tools & Integrations
class WizardStep4ToolsIntegrations {
  final List<String> enabledToolKeys;
  final Map<String, Map<String, String>> toolVariableMappings;
  final String? webhookUrl;
  final String? callbackUrl;
  final Map<String, dynamic> analysisSchema;

  const WizardStep4ToolsIntegrations({
    this.enabledToolKeys = const ['get_business_info@1.0', 'create_callback@1.0', 'send_confirmation@1.0'],
    this.toolVariableMappings = const {},
    this.webhookUrl,
    this.callbackUrl,
    this.analysisSchema = const {},
  });

  Map<String, dynamic> toJson() => {
        'enabledToolKeys': enabledToolKeys,
        'toolVariableMappings': toolVariableMappings,
        if (webhookUrl != null) 'webhookUrl': webhookUrl,
        if (callbackUrl != null) 'callbackUrl': callbackUrl,
        'analysisSchema': analysisSchema,
      };

  static WizardStep4ToolsIntegrations fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WizardStep4ToolsIntegrations();
    final keys = json['enabledToolKeys'];
    final mappings = json['toolVariableMappings'];
    return WizardStep4ToolsIntegrations(
      enabledToolKeys: keys is List ? keys.map((e) => e.toString()).toList() : const ['get_business_info@1.0', 'create_callback@1.0', 'send_confirmation@1.0'],
      toolVariableMappings: mappings is Map
          ? mappings.map((k, v) => MapEntry(k.toString(), v is Map ? Map<String, String>.from(v.map((k2, v2) => MapEntry(k2.toString(), v2.toString()))) : <String, String>{}))
          : const {},
      webhookUrl: json['webhookUrl']?.toString(),
      callbackUrl: json['callbackUrl']?.toString(),
      analysisSchema: json['analysisSchema'] is Map ? Map<String, dynamic>.from(json['analysisSchema']) : const {},
    );
  }

  WizardStep4ToolsIntegrations copyWith({
    List<String>? enabledToolKeys,
    Map<String, Map<String, String>>? toolVariableMappings,
    String? webhookUrl,
    String? callbackUrl,
    Map<String, dynamic>? analysisSchema,
  }) =>
      WizardStep4ToolsIntegrations(
        enabledToolKeys: enabledToolKeys ?? this.enabledToolKeys,
        toolVariableMappings: toolVariableMappings ?? this.toolVariableMappings,
        webhookUrl: webhookUrl ?? this.webhookUrl,
        callbackUrl: callbackUrl ?? this.callbackUrl,
        analysisSchema: analysisSchema ?? this.analysisSchema,
      );
}

/// Step 5 — Review & Generate (state)
class WizardStep5Review {
  final String? generatedSystemPrompt;
  final String? generatedVoicemailMessage;
  final String? generatedSummary;
  final String? fullAssistantConfigJson;
  final String? lastRegeneratedAt;

  const WizardStep5Review({
    this.generatedSystemPrompt,
    this.generatedVoicemailMessage,
    this.generatedSummary,
    this.fullAssistantConfigJson,
    this.lastRegeneratedAt,
  });

  Map<String, dynamic> toJson() => {
        if (generatedSystemPrompt != null) 'generatedSystemPrompt': generatedSystemPrompt,
        if (generatedVoicemailMessage != null) 'generatedVoicemailMessage': generatedVoicemailMessage,
        if (generatedSummary != null) 'generatedSummary': generatedSummary,
        if (fullAssistantConfigJson != null) 'fullAssistantConfigJson': fullAssistantConfigJson,
        if (lastRegeneratedAt != null) 'lastRegeneratedAt': lastRegeneratedAt,
      };

  static WizardStep5Review fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WizardStep5Review();
    return WizardStep5Review(
      generatedSystemPrompt: json['generatedSystemPrompt']?.toString(),
      generatedVoicemailMessage: json['generatedVoicemailMessage']?.toString(),
      generatedSummary: json['generatedSummary']?.toString(),
      fullAssistantConfigJson: json['fullAssistantConfigJson']?.toString(),
      lastRegeneratedAt: json['lastRegeneratedAt']?.toString(),
    );
  }
}

/// Aggregate wizard state (all 5 steps)
class UniversalWizardState {
  final WizardStep1BusinessIdentity step1;
  final WizardStep2PersonaVoice step2;
  final WizardStep3ConversationFlow step3;
  final WizardStep4ToolsIntegrations step4;
  final WizardStep5Review step5;

  const UniversalWizardState({
    this.step1 = const WizardStep1BusinessIdentity(),
    this.step2 = const WizardStep2PersonaVoice(),
    this.step3 = const WizardStep3ConversationFlow(),
    this.step4 = const WizardStep4ToolsIntegrations(),
    this.step5 = const WizardStep5Review(),
  });

  Map<String, dynamic> toJson() => {
        'step1': step1.toJson(),
        'step2': step2.toJson(),
        'step3': step3.toJson(),
        'step4': step4.toJson(),
        'step5': step5.toJson(),
      };

  static UniversalWizardState fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UniversalWizardState();
    return UniversalWizardState(
      step1: WizardStep1BusinessIdentity.fromJson(json['step1'] is Map ? Map<String, dynamic>.from(json['step1']) : null),
      step2: WizardStep2PersonaVoice.fromJson(json['step2'] is Map ? Map<String, dynamic>.from(json['step2']) : null),
      step3: WizardStep3ConversationFlow.fromJson(json['step3'] is Map ? Map<String, dynamic>.from(json['step3']) : null),
      step4: WizardStep4ToolsIntegrations.fromJson(json['step4'] is Map ? Map<String, dynamic>.from(json['step4']) : null),
      step5: WizardStep5Review.fromJson(json['step5'] is Map ? Map<String, dynamic>.from(json['step5']) : null),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static UniversalWizardState fromJsonString(String? s) {
    if (s == null || s.isEmpty) return const UniversalWizardState();
    try {
      final map = jsonDecode(s) as Map<String, dynamic>?;
      return UniversalWizardState.fromJson(map);
    } catch (_) {
      return const UniversalWizardState();
    }
  }
}

/// Department options with labels for Step 1 (icon-style selection, aligned with Create Operator).
const List<Map<String, String>> kDepartmentIcons = [
  {'id': 'admissions', 'label': 'Admissions'},
  {'id': 'student_financial_services', 'label': 'Student Financial Services'},
  {'id': 'registrar', 'label': 'Registrar'},
  {'id': 'residential_life_and_housing', 'label': 'Housing'},
  {'id': 'information_technology_help_desk', 'label': 'IT Help Desk'},
  {'id': 'general_front_desk', 'label': 'General Front Desk'},
];

/// Legacy flat list for backward compatibility
const List<String> departmentPresets = [
  'Admissions',
  'Student Financial Services',
  'Registrar',
  'Housing',
  'IT Help Desk',
  'General Front Desk',
  'Education',
  'Healthcare',
  'Other',
];
