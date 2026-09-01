import 'plant_model.dart';

enum DiagnosisConfidence { high, medium, low }

enum CheckInStage { day3, day7 }

enum CheckInAssessment { better, same, worse }

enum RecoveryCaseStatus {
  active,
  awaitingDay3,
  awaitingDay7,
  recovered,
  improved,
  unresolved,
  lost,
  unknown,
}

enum OutcomeResult { recovered, improved, unresolved, lost, unknown }

extension DiagnosisConfidenceCodec on DiagnosisConfidence {
  String get wireName {
    switch (this) {
      case DiagnosisConfidence.high:
        return 'high';
      case DiagnosisConfidence.medium:
        return 'medium';
      case DiagnosisConfidence.low:
        return 'low';
    }
  }

  static DiagnosisConfidence fromWire(String? value) {
    switch (value?.toLowerCase()) {
      case 'high':
        return DiagnosisConfidence.high;
      case 'low':
        return DiagnosisConfidence.low;
      default:
        return DiagnosisConfidence.medium;
    }
  }
}

extension CheckInStageCodec on CheckInStage {
  String get wireName => this == CheckInStage.day3 ? 'day3' : 'day7';

  static CheckInStage fromWire(String? value) {
    return value == 'day7' ? CheckInStage.day7 : CheckInStage.day3;
  }
}

extension CheckInAssessmentCodec on CheckInAssessment {
  String get wireName {
    switch (this) {
      case CheckInAssessment.better:
        return 'better';
      case CheckInAssessment.same:
        return 'same';
      case CheckInAssessment.worse:
        return 'worse';
    }
  }

  String get label {
    switch (this) {
      case CheckInAssessment.better:
        return 'Better';
      case CheckInAssessment.same:
        return 'About the same';
      case CheckInAssessment.worse:
        return 'Worse';
    }
  }

  static CheckInAssessment fromWire(String? value) {
    switch (value) {
      case 'better':
        return CheckInAssessment.better;
      case 'worse':
        return CheckInAssessment.worse;
      default:
        return CheckInAssessment.same;
    }
  }
}

extension RecoveryCaseStatusCodec on RecoveryCaseStatus {
  String get wireName {
    switch (this) {
      case RecoveryCaseStatus.active:
        return 'active';
      case RecoveryCaseStatus.awaitingDay3:
        return 'awaiting_day3';
      case RecoveryCaseStatus.awaitingDay7:
        return 'awaiting_day7';
      case RecoveryCaseStatus.recovered:
        return 'recovered';
      case RecoveryCaseStatus.improved:
        return 'improved';
      case RecoveryCaseStatus.unresolved:
        return 'unresolved';
      case RecoveryCaseStatus.lost:
        return 'lost';
      case RecoveryCaseStatus.unknown:
        return 'unknown';
    }
  }

  bool get isOpen =>
      this == RecoveryCaseStatus.active ||
      this == RecoveryCaseStatus.awaitingDay3 ||
      this == RecoveryCaseStatus.awaitingDay7;

  bool get isClosed => !isOpen;

  static RecoveryCaseStatus fromWire(String? value) {
    switch (value) {
      case 'active':
        return RecoveryCaseStatus.active;
      case 'awaiting_day7':
        return RecoveryCaseStatus.awaitingDay7;
      case 'recovered':
        return RecoveryCaseStatus.recovered;
      case 'improved':
        return RecoveryCaseStatus.improved;
      case 'unresolved':
        return RecoveryCaseStatus.unresolved;
      case 'lost':
        return RecoveryCaseStatus.lost;
      case 'unknown':
        return RecoveryCaseStatus.unknown;
      default:
        return RecoveryCaseStatus.awaitingDay3;
    }
  }
}

extension OutcomeResultCodec on OutcomeResult {
  String get wireName {
    switch (this) {
      case OutcomeResult.recovered:
        return 'recovered';
      case OutcomeResult.improved:
        return 'improved';
      case OutcomeResult.unresolved:
        return 'unresolved';
      case OutcomeResult.lost:
        return 'lost';
      case OutcomeResult.unknown:
        return 'unknown';
    }
  }

  static OutcomeResult fromWire(String? value) {
    switch (value) {
      case 'recovered':
        return OutcomeResult.recovered;
      case 'improved':
        return OutcomeResult.improved;
      case 'lost':
        return OutcomeResult.lost;
      case 'unknown':
        return OutcomeResult.unknown;
      default:
        return OutcomeResult.unresolved;
    }
  }

  String get label {
    switch (this) {
      case OutcomeResult.recovered:
        return 'Recovered';
      case OutcomeResult.improved:
        return 'Improved';
      case OutcomeResult.unresolved:
        return 'Unresolved';
      case OutcomeResult.lost:
        return 'Did not make it';
      case OutcomeResult.unknown:
        return 'Outcome unknown';
    }
  }
}

class DiagnosisIssue {
  final String name;
  final String explanation;
  final String evidence;

  const DiagnosisIssue({
    required this.name,
    required this.explanation,
    this.evidence = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'explanation': explanation,
        'evidence': evidence,
      };

  factory DiagnosisIssue.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const DiagnosisIssue(name: '', explanation: '');
    }
    return DiagnosisIssue(
      name: json['name'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      evidence: json['evidence'] as String? ?? '',
    );
  }

  bool get isEmpty => name.trim().isEmpty;
}

class FirstAidAction {
  final String action;
  final String method;

  const FirstAidAction({required this.action, this.method = ''});

  Map<String, dynamic> toJson() => {'action': action, 'method': method};

  factory FirstAidAction.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const FirstAidAction(action: '');
    }
    return FirstAidAction(
      action: json['action'] as String? ?? '',
      method: json['method'] as String? ?? '',
    );
  }
}

class PlantDiagnosis {
  final String id;
  final String plantId;
  final DateTime createdAt;
  final String photoPath;
  final DiagnosisConfidence confidence;
  final DiagnosisIssue primaryIssue;
  final DiagnosisIssue? alternativeIssue;
  final DiagnosisIssue? secondExplanation;
  final FirstAidAction firstAid;
  final bool followUpRequired;
  final String source;
  final String plantName;
  final String overallCondition;
  final Map<String, dynamic> rawPayload;

  const PlantDiagnosis({
    required this.id,
    required this.plantId,
    required this.createdAt,
    required this.photoPath,
    required this.confidence,
    required this.primaryIssue,
    this.alternativeIssue,
    this.secondExplanation,
    required this.firstAid,
    this.followUpRequired = false,
    this.source = 'gemini',
    this.plantName = '',
    this.overallCondition = '',
    this.rawPayload = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'createdAt': createdAt.toIso8601String(),
        'photoPath': photoPath,
        'confidence': confidence.wireName,
        'primaryIssue': primaryIssue.toJson(),
        'alternativeIssue': alternativeIssue?.toJson(),
        'secondExplanation': secondExplanation?.toJson(),
        'firstAid': firstAid.toJson(),
        'followUpRequired': followUpRequired,
        'source': source,
        'plantName': plantName,
        'overallCondition': overallCondition,
        'rawPayload': rawPayload,
      };

  factory PlantDiagnosis.fromJson(Map<String, dynamic> json) {
    return PlantDiagnosis(
      id: json['id'] as String,
      plantId: json['plantId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      photoPath: json['photoPath'] as String? ?? '',
      confidence: DiagnosisConfidenceCodec.fromWire(json['confidence'] as String?),
      primaryIssue: DiagnosisIssue.fromJson(
        json['primaryIssue'] is Map
            ? Map<String, dynamic>.from(json['primaryIssue'] as Map)
            : null,
      ),
      alternativeIssue: json['alternativeIssue'] is Map
          ? DiagnosisIssue.fromJson(
              Map<String, dynamic>.from(json['alternativeIssue'] as Map),
            )
          : null,
      secondExplanation: json['secondExplanation'] is Map
          ? DiagnosisIssue.fromJson(
              Map<String, dynamic>.from(json['secondExplanation'] as Map),
            )
          : null,
      firstAid: FirstAidAction.fromJson(
        json['firstAid'] is Map
            ? Map<String, dynamic>.from(json['firstAid'] as Map)
            : null,
      ),
      followUpRequired: json['followUpRequired'] as bool? ?? false,
      source: json['source'] as String? ?? 'gemini',
      plantName: json['plantName'] as String? ?? '',
      overallCondition: json['overallCondition'] as String? ?? '',
      rawPayload: json['rawPayload'] is Map
          ? Map<String, dynamic>.from(json['rawPayload'] as Map)
          : const {},
    );
  }
}

class TreatmentStep {
  final String id;
  final int order;
  final String title;
  final String timing;
  final String method;
  final String rationale;
  final DateTime? completedAt;
  final String? irreversibleWarning;

  const TreatmentStep({
    required this.id,
    required this.order,
    required this.title,
    required this.timing,
    required this.method,
    required this.rationale,
    this.completedAt,
    this.irreversibleWarning,
  });

  bool get isCompleted => completedAt != null;
  bool get isIrreversible =>
      irreversibleWarning != null && irreversibleWarning!.trim().isNotEmpty;

  TreatmentStep copyWith({DateTime? completedAt}) {
    return TreatmentStep(
      id: id,
      order: order,
      title: title,
      timing: timing,
      method: method,
      rationale: rationale,
      completedAt: completedAt ?? this.completedAt,
      irreversibleWarning: irreversibleWarning,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'title': title,
        'timing': timing,
        'method': method,
        'rationale': rationale,
        'completedAt': completedAt?.toIso8601String(),
        'irreversibleWarning': irreversibleWarning,
      };

  factory TreatmentStep.fromJson(Map<String, dynamic> json) {
    return TreatmentStep(
      id: json['id'] as String,
      order: json['order'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      timing: json['timing'] as String? ?? '',
      method: json['method'] as String? ?? '',
      rationale: json['rationale'] as String? ?? '',
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      irreversibleWarning: json['irreversibleWarning'] as String?,
    );
  }
}

class TreatmentPlan {
  final String id;
  final String plantId;
  final String diagnosisId;
  final String? recoveryCaseId;
  final DateTime createdAt;
  final List<TreatmentStep> steps;
  final String? adjustedFromTreatmentId;

  const TreatmentPlan({
    required this.id,
    required this.plantId,
    required this.diagnosisId,
    this.recoveryCaseId,
    required this.createdAt,
    required this.steps,
    this.adjustedFromTreatmentId,
  });

  TreatmentPlan copyWith({
    String? recoveryCaseId,
    List<TreatmentStep>? steps,
    String? adjustedFromTreatmentId,
  }) {
    return TreatmentPlan(
      id: id,
      plantId: plantId,
      diagnosisId: diagnosisId,
      recoveryCaseId: recoveryCaseId ?? this.recoveryCaseId,
      createdAt: createdAt,
      steps: steps ?? this.steps,
      adjustedFromTreatmentId:
          adjustedFromTreatmentId ?? this.adjustedFromTreatmentId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'diagnosisId': diagnosisId,
        'recoveryCaseId': recoveryCaseId,
        'createdAt': createdAt.toIso8601String(),
        'steps': steps.map((s) => s.toJson()).toList(),
        'adjustedFromTreatmentId': adjustedFromTreatmentId,
      };

  factory TreatmentPlan.fromJson(Map<String, dynamic> json) {
    return TreatmentPlan(
      id: json['id'] as String,
      plantId: json['plantId'] as String,
      diagnosisId: json['diagnosisId'] as String,
      recoveryCaseId: json['recoveryCaseId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      steps: (json['steps'] as List<dynamic>? ?? [])
          .map((s) => TreatmentStep.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      adjustedFromTreatmentId: json['adjustedFromTreatmentId'] as String?,
    );
  }
}

class RecoveryCase {
  final String id;
  final String plantId;
  final String diagnosisId;
  final String treatmentId;
  final DateTime openedAt;
  final RecoveryCaseStatus status;
  final DateTime day3DueAt;
  final DateTime day7DueAt;
  final DateTime? closedAt;
  final String? outcomeId;
  final bool missedDay3ReminderSent;
  final DateTime? day3CompletedAt;
  final DateTime? day7CompletedAt;
  final int day3SameCount;
  final int day7AdjustmentCount;
  final DateTime? deferredUntil;
  final bool usedAlternativeTreatment;
  final String originalPhotoPath;

  const RecoveryCase({
    required this.id,
    required this.plantId,
    required this.diagnosisId,
    required this.treatmentId,
    required this.openedAt,
    required this.status,
    required this.day3DueAt,
    required this.day7DueAt,
    this.closedAt,
    this.outcomeId,
    this.missedDay3ReminderSent = false,
    this.day3CompletedAt,
    this.day7CompletedAt,
    this.day3SameCount = 0,
    this.day7AdjustmentCount = 0,
    this.deferredUntil,
    this.usedAlternativeTreatment = false,
    this.originalPhotoPath = '',
  });

  RecoveryCase copyWith({
    String? treatmentId,
    RecoveryCaseStatus? status,
    DateTime? day3DueAt,
    DateTime? day7DueAt,
    DateTime? closedAt,
    String? outcomeId,
    bool? missedDay3ReminderSent,
    DateTime? day3CompletedAt,
    DateTime? day7CompletedAt,
    int? day3SameCount,
    int? day7AdjustmentCount,
    DateTime? deferredUntil,
    bool? usedAlternativeTreatment,
  }) {
    return RecoveryCase(
      id: id,
      plantId: plantId,
      diagnosisId: diagnosisId,
      treatmentId: treatmentId ?? this.treatmentId,
      openedAt: openedAt,
      status: status ?? this.status,
      day3DueAt: day3DueAt ?? this.day3DueAt,
      day7DueAt: day7DueAt ?? this.day7DueAt,
      closedAt: closedAt ?? this.closedAt,
      outcomeId: outcomeId ?? this.outcomeId,
      missedDay3ReminderSent:
          missedDay3ReminderSent ?? this.missedDay3ReminderSent,
      day3CompletedAt: day3CompletedAt ?? this.day3CompletedAt,
      day7CompletedAt: day7CompletedAt ?? this.day7CompletedAt,
      day3SameCount: day3SameCount ?? this.day3SameCount,
      day7AdjustmentCount: day7AdjustmentCount ?? this.day7AdjustmentCount,
      deferredUntil: deferredUntil ?? this.deferredUntil,
      usedAlternativeTreatment:
          usedAlternativeTreatment ?? this.usedAlternativeTreatment,
      originalPhotoPath: originalPhotoPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'diagnosisId': diagnosisId,
        'treatmentId': treatmentId,
        'openedAt': openedAt.toIso8601String(),
        'status': status.wireName,
        'day3DueAt': day3DueAt.toIso8601String(),
        'day7DueAt': day7DueAt.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
        'outcomeId': outcomeId,
        'missedDay3ReminderSent': missedDay3ReminderSent,
        'day3CompletedAt': day3CompletedAt?.toIso8601String(),
        'day7CompletedAt': day7CompletedAt?.toIso8601String(),
        'day3SameCount': day3SameCount,
        'day7AdjustmentCount': day7AdjustmentCount,
        'deferredUntil': deferredUntil?.toIso8601String(),
        'usedAlternativeTreatment': usedAlternativeTreatment,
        'originalPhotoPath': originalPhotoPath,
      };

  factory RecoveryCase.fromJson(Map<String, dynamic> json) {
    return RecoveryCase(
      id: json['id'] as String,
      plantId: json['plantId'] as String,
      diagnosisId: json['diagnosisId'] as String,
      treatmentId: json['treatmentId'] as String,
      openedAt: DateTime.parse(json['openedAt'] as String),
      status: RecoveryCaseStatusCodec.fromWire(json['status'] as String?),
      day3DueAt: DateTime.parse(json['day3DueAt'] as String),
      day7DueAt: DateTime.parse(json['day7DueAt'] as String),
      closedAt: json['closedAt'] != null
          ? DateTime.tryParse(json['closedAt'] as String)
          : null,
      outcomeId: json['outcomeId'] as String?,
      missedDay3ReminderSent: json['missedDay3ReminderSent'] as bool? ?? false,
      day3CompletedAt: json['day3CompletedAt'] != null
          ? DateTime.tryParse(json['day3CompletedAt'] as String)
          : null,
      day7CompletedAt: json['day7CompletedAt'] != null
          ? DateTime.tryParse(json['day7CompletedAt'] as String)
          : null,
      day3SameCount: json['day3SameCount'] as int? ?? 0,
      day7AdjustmentCount: json['day7AdjustmentCount'] as int? ?? 0,
      deferredUntil: json['deferredUntil'] != null
          ? DateTime.tryParse(json['deferredUntil'] as String)
          : null,
      usedAlternativeTreatment:
          json['usedAlternativeTreatment'] as bool? ?? false,
      originalPhotoPath: json['originalPhotoPath'] as String? ?? '',
    );
  }
}

class RecoveryCheckIn {
  final String id;
  final String recoveryCaseId;
  final String plantId;
  final DateTime createdAt;
  final CheckInStage stage;
  final String photoPath;
  final CheckInAssessment assessment;
  final String? note;

  const RecoveryCheckIn({
    required this.id,
    required this.recoveryCaseId,
    required this.plantId,
    required this.createdAt,
    required this.stage,
    required this.photoPath,
    required this.assessment,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'recoveryCaseId': recoveryCaseId,
        'plantId': plantId,
        'createdAt': createdAt.toIso8601String(),
        'stage': stage.wireName,
        'photoPath': photoPath,
        'assessment': assessment.wireName,
        'note': note,
      };

  factory RecoveryCheckIn.fromJson(Map<String, dynamic> json) {
    return RecoveryCheckIn(
      id: json['id'] as String,
      recoveryCaseId: json['recoveryCaseId'] as String,
      plantId: json['plantId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      stage: CheckInStageCodec.fromWire(json['stage'] as String?),
      photoPath: json['photoPath'] as String? ?? '',
      assessment:
          CheckInAssessmentCodec.fromWire(json['assessment'] as String?),
      note: json['note'] as String?,
    );
  }
}

class RecoveryOutcome {
  final String id;
  final String plantId;
  final String recoveryCaseId;
  final OutcomeResult result;
  final DateTime closedAt;
  final String closeReason;
  final String? note;

  const RecoveryOutcome({
    required this.id,
    required this.plantId,
    required this.recoveryCaseId,
    required this.result,
    required this.closedAt,
    required this.closeReason,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'recoveryCaseId': recoveryCaseId,
        'result': result.wireName,
        'closedAt': closedAt.toIso8601String(),
        'closeReason': closeReason,
        'note': note,
      };

  factory RecoveryOutcome.fromJson(Map<String, dynamic> json) {
    return RecoveryOutcome(
      id: json['id'] as String,
      plantId: json['plantId'] as String,
      recoveryCaseId: json['recoveryCaseId'] as String,
      result: OutcomeResultCodec.fromWire(json['result'] as String?),
      closedAt: DateTime.parse(json['closedAt'] as String),
      closeReason: json['closeReason'] as String? ?? '',
      note: json['note'] as String?,
    );
  }
}

String newRecoveryId() => Plant.generateDurableId();
