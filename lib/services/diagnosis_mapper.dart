import '../model/data_model/recovery_models.dart';

/// Maps Gemini JSON (new recovery schema or legacy diagnosis JSON)
/// into persistent PlantFollow diagnosis + treatment drafts.
class DiagnosisMapper {
  static PlantDiagnosis diagnosisFromGemini({
    required Map<String, dynamic> json,
    required String plantId,
    required String photoPath,
  }) {
    final confidence = _confidence(json);
    final issues = _issues(json);
    final primary = issues.isNotEmpty
        ? issues.first
        : DiagnosisIssue(
            name: json['plant_name'] as String? ?? 'Needs a closer look',
            explanation: _string(json['what_we_noticed']) ??
                _string(json['description']) ??
                'We noticed the plant may need attention.',
            evidence: '',
          );

    DiagnosisIssue? alternative;
    DiagnosisIssue? second;
    if (confidence == DiagnosisConfidence.medium && issues.length > 1) {
      alternative = issues[1];
    } else if (json['alternative_issue'] is Map) {
      alternative = _issueFromMap(json['alternative_issue'] as Map);
    }

    if (confidence == DiagnosisConfidence.low) {
      if (issues.length > 1) {
        second = issues[1];
      } else if (json['second_explanation'] is Map) {
        second = _issueFromMap(json['second_explanation'] as Map);
      }
      alternative ??= second;
    }

    final firstAid = _firstAid(json);
    return PlantDiagnosis(
      id: newRecoveryId(),
      plantId: plantId,
      createdAt: DateTime.now(),
      photoPath: photoPath,
      confidence: confidence,
      primaryIssue: primary,
      alternativeIssue: alternative,
      secondExplanation: second,
      firstAid: firstAid,
      followUpRequired: confidence == DiagnosisConfidence.low,
      source: 'gemini',
      plantName: json['plant_name'] as String? ?? '',
      overallCondition: _condition(json),
      rawPayload: Map<String, dynamic>.from(json),
    );
  }

  static TreatmentPlan treatmentFromGemini({
    required Map<String, dynamic> json,
    required PlantDiagnosis diagnosis,
    bool alternative = false,
  }) {
    final rawSteps = alternative
        ? (json['alternative_treatment_steps'] as List<dynamic>? ??
            json['treatment_steps'] as List<dynamic>? ??
            json['recommendations'] as List<dynamic>? ??
            [])
        : (json['treatment_steps'] as List<dynamic>? ??
            json['recommendations'] as List<dynamic>? ??
            []);

    var steps = <TreatmentStep>[];
    for (var i = 0; i < rawSteps.length && steps.length < 3; i++) {
      final raw = rawSteps[i];
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final warning = map['irreversible_warning'] as String? ??
          map['irreversibleWarning'] as String?;
      steps.add(
        TreatmentStep(
          id: newRecoveryId(),
          order: i + 1,
          title: map['title'] as String? ??
              map['action'] as String? ??
              'Care step ${i + 1}',
          timing: map['timing'] as String? ?? 'Today if you can',
          method: map['method'] as String? ?? map['details'] as String? ?? '',
          rationale: map['rationale'] as String? ?? '',
          irreversibleWarning:
              (warning != null && warning.trim().isNotEmpty) ? warning : null,
        ),
      );
    }

    if (steps.isEmpty) {
      steps = [
        TreatmentStep(
          id: newRecoveryId(),
          order: 1,
          title: diagnosis.firstAid.action.isNotEmpty
              ? diagnosis.firstAid.action
              : 'Give the plant a gentle check',
          timing: 'Today',
          method: diagnosis.firstAid.method.isNotEmpty
              ? diagnosis.firstAid.method
              : 'Look at the affected leaves and only do what feels reversible.',
          rationale: 'A small, safe step is better than a drastic change.',
        ),
      ];
    }

    if (alternative) {
      steps = RecoveryAlternative.wrap(steps);
    }

    return TreatmentPlan(
      id: newRecoveryId(),
      plantId: diagnosis.plantId,
      diagnosisId: diagnosis.id,
      createdAt: DateTime.now(),
      steps: steps,
    );
  }

  static DiagnosisConfidence _confidence(Map<String, dynamic> json) {
    final explicit = json['confidence'] as String?;
    if (explicit != null) {
      return DiagnosisConfidenceCodec.fromWire(explicit);
    }
    final score = json['health_score'];
    if (score is num) {
      if (score >= 80) return DiagnosisConfidence.high;
      if (score <= 40) return DiagnosisConfidence.low;
    }
    final issues = json['issues_detected'];
    if (issues is List && issues.length >= 2) {
      return DiagnosisConfidence.medium;
    }
    return DiagnosisConfidence.high;
  }

  static List<DiagnosisIssue> _issues(Map<String, dynamic> json) {
    if (json['primary_issue'] is Map) {
      final list = <DiagnosisIssue>[_issueFromMap(json['primary_issue'] as Map)];
      if (json['alternative_issue'] is Map) {
        list.add(_issueFromMap(json['alternative_issue'] as Map));
      }
      if (json['second_explanation'] is Map) {
        list.add(_issueFromMap(json['second_explanation'] as Map));
      }
      return list;
    }
    final detected = json['issues_detected'] as List<dynamic>? ?? [];
    return detected.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      final noticed = map['what_we_noticed'] ?? map['description'];
      final evidence = map['evidence'] ??
          (map['visible_signs'] is List
              ? (map['visible_signs'] as List).join(', ')
              : map['visible_signs']);
      return DiagnosisIssue(
        name: map['name'] as String? ?? 'Plant issue',
        explanation: noticed?.toString() ?? '',
        evidence: evidence?.toString() ?? '',
      );
    }).toList();
  }

  static DiagnosisIssue _issueFromMap(Map raw) {
    final map = Map<String, dynamic>.from(raw);
    return DiagnosisIssue(
      name: map['name'] as String? ?? '',
      explanation: map['explanation'] as String? ??
          map['description'] as String? ??
          '',
      evidence: map['evidence'] as String? ?? '',
    );
  }

  static FirstAidAction _firstAid(Map<String, dynamic> json) {
    if (json['first_aid'] is Map) {
      final map = Map<String, dynamic>.from(json['first_aid'] as Map);
      return FirstAidAction(
        action: map['action'] as String? ?? '',
        method: map['method'] as String? ?? '',
      );
    }
    final recs = json['recommendations'] as List<dynamic>? ?? [];
    if (recs.isNotEmpty && recs.first is Map) {
      final map = Map<String, dynamic>.from(recs.first as Map);
      return FirstAidAction(
        action: map['action'] as String? ?? 'One gentle thing you can do today',
        method: map['details'] as String? ?? '',
      );
    }
    return const FirstAidAction(
      action: 'Check the soil with a finger before changing anything else',
      method: 'If the top feels wet, wait. If it is dry, water slowly at the base.',
    );
  }

  static String _condition(Map<String, dynamic> json) {
    final value = (json['overall_condition'] ?? json['overall_health'] ?? '')
        .toString()
        .toLowerCase();
    if (value.contains('healthy')) return 'looking okay';
    if (value.contains('critical') || value.contains('struggling')) {
      return 'struggling';
    }
    if (value.isEmpty) return 'needs attention';
    return 'needs attention';
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map((e) => e.toString()).join(' ');
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

class RecoveryAlternative {
  static List<TreatmentStep> wrap(List<TreatmentStep> steps) {
    return steps
        .map(
          (step) => TreatmentStep(
            id: step.id.isEmpty ? newRecoveryId() : step.id,
            order: step.order,
            title: step.title.startsWith('Try a different')
                ? step.title
                : 'Try a different approach: ${step.title}',
            timing: step.timing,
            method: step.method,
            rationale: step.rationale.isEmpty
                ? 'A different method is safer than repeating the last plan more strongly.'
                : step.rationale,
            irreversibleWarning: step.irreversibleWarning,
          ),
        )
        .toList();
  }
}
