import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/data_model/plant_model.dart';
import 'identify_logic.dart';
import 'plant_ai_client.dart';

class DiagnoseAttempt {
  final Map<String, dynamic>? json;
  final IdentifyFailureKind? failure;
  final String? debugDetail;

  const DiagnoseAttempt._({this.json, this.failure, this.debugDetail});

  factory DiagnoseAttempt.ok(Map<String, dynamic> json) =>
      DiagnoseAttempt._(json: json);

  factory DiagnoseAttempt.fail(IdentifyFailureKind failure, [String? detail]) =>
      DiagnoseAttempt._(failure: failure, debugDetail: detail);

  bool get isSuccess => json != null && failure == null;
}

class GeminiService {
  static const _identifyPrompt = '''
You are a plant identification expert.
Analyze the attached image and provide structured JSON only.

If you cannot see a photograph in this request, return {"error":"no_image_received"} and nothing else. Do not guess a houseplant.

Accept ANY botanical photo: leaf, flower, bloom, bud, fruit, seed, stem, bark, succulent, cactus, herb, grass, tree, houseplant, garden plant, or the whole plant. A flower-only photo is valid. A whole-plant photo is valid. Do NOT require a leaf close-up. Do NOT return not_a_plant or low_detail only because leaves are missing. Set image_quality to ok when a flower or whole plant is clearly visible.

Required fields:
- plant_name_common
- plant_name_scientific
- identification_confidence: high / medium / low. high only when visible botanical evidence is strong. Use medium or low rather than guessing a popular houseplant.
- evidence_summary: one short user-facing sentence of visible botanical evidence (flower form, petals, leaf shape, veins, fruit, growth habit). Never include hidden reasoning or chain-of-thought. Required for high or medium confidence.
- image_quality: ok / blurry / dark / too_small / multiple_plants / low_detail / not_a_plant
- safety: { status: toxic / non_toxic / unknown, summary, cats: toxic / non_toxic / unknown, dogs: toxic / non_toxic / unknown, humans: toxic / non_toxic / unknown }. unknown if you are not sure. Never call missing data safe.
- toxicity: short phrase matching safety.status
- description
- taxonomy: {kingdom, family, genus, species}
- native_region
- growth_season
- care_guide: {watering, sunlight, soil, fertilization, pruning, propagation}
- health_scan: optional visual notes about the photo, not a medical diagnosis
- common_pests
- common_diseases
- usage
- fun_fact
- alternative_candidates: array of at most 3 objects {common_name, scientific_name} ONLY when identification_confidence is medium or low and you have real alternatives. Empty array otherwise. Never invent species.

Return {"error":"not_a_plant","image_quality":"not_a_plant"} only when the photo clearly has no botanical subject (person, pet, furniture, food packaging, or an empty scene). Flowers, fruits, and whole plants ARE botanical subjects.
If you can tell it is a plant or flower but cannot name it, return {"error":"unable_to_identify"} rather than guessing a popular houseplant.

Format: JSON only. No extra explanation.
''';

  static const _diagnosePrompt = '''
You are a plant health diagnosis expert.
Analyze the attached image and provide a detailed health assessment in JSON format.

The photo may show a leaf, flower, bloom, bud, fruit, stem, or the whole plant. Assess whatever botanical subject is visible. A flower or whole-plant photo is valid. Do not return an error only because the photo is not a close-up leaf.

Required fields (JSON only, no extra explanation):
- plant_name
- overall_condition: looking_okay / needs_attention / struggling
- confidence: high / medium / low
- what_we_noticed: short description of the affected area
- primary_issue: { name, explanation, evidence }
- alternative_issue: { name, explanation, evidence } (required when confidence is medium)
- second_explanation: { name, explanation, evidence } (required when confidence is low)
- first_aid: { action, method } one safe thing the user can do today. Avoid irreversible steps.
- treatment_steps: 2 or 3 objects { title, timing, method, rationale, irreversible_warning }
  Use gentle-first order. irreversible_warning is empty unless the step is hard to undo.
- alternative_treatment_steps: 2 or 3 objects with the same shape, used if the first plan does not help. Do not simply repeat the first plan more strongly.

Return {"error":"unable_to_diagnose"} only when the photo is blank, has no plant or flower, or is too unclear to assess at all.
If you cannot see a photograph in this request, return {"error":"no_image_received"} and nothing else.
Do not use the words: symptoms, prognosis, critical, patient, disease diagnosis as a medical verdict.
Prefer plant language: what we noticed, likely issue, affected area, what to do next.

Format: JSON only.
''';

  static String diagnosePromptFor(Plant? plant) {
    final name = plant?.name.trim() ?? '';
    final scientific = plant?.scientificName.trim() ?? '';
    if (name.isEmpty) return _diagnosePrompt;
    final label = scientific.isEmpty ? name : '$name ($scientific)';
    return '$_diagnosePrompt\n'
        'A saved garden record names this plant as $label. '
        'That name may be wrong. Diagnose the attached photo. '
        'If the photo conflicts with the saved name, trust the photo. '
        'Do not invent issues typical of the saved species unless they are visible.';
  }

  static void _log(String category, String message) {
    if (kDebugMode) {
      debugPrint('IDENTIFY[$category] $message');
    }
  }

  static IdentifyFailureKind _fromAi(PlantAiException e) {
    switch (e.kind) {
      case IdentifyAiKind.network:
      case IdentifyAiKind.timeout:
        return IdentifyFailureKind.network;
      case IdentifyAiKind.api:
        return IdentifyFailureKind.api;
    }
  }

  static Future<IdentifyAttempt> identifyPlant(File image) async {
    try {
      if (!image.existsSync()) {
        _log('LOCAL STORAGE FAILURE', 'missing ${image.path}');
        return IdentifyAttempt.fail(IdentifyFailureKind.local, 'missing file');
      }
      final bytes = await image.readAsBytes();
      _log('REQUEST', 'bytes=${bytes.length}');
      final content = await PlantAiClient.complete(
        input: _identifyPrompt,
        imageBytes: bytes,
      );
      _log('MODEL', 'chars=${content.length} preview=${_preview(content)}');
      final attempt = IdentifyLogic.fromModelText(content, image.path);
      if (!attempt.isSuccess) {
        final kind = attempt.failure ?? IdentifyFailureKind.invalid;
        _log(_debugLabel(kind), attempt.debugDetail ?? 'failed');
      }
      return attempt;
    } on PlantAiException catch (e) {
      final kind = _fromAi(e);
      _log(_debugLabel(kind), e.message);
      return IdentifyAttempt.fail(kind, e.message);
    } on SocketException catch (e) {
      _log('NETWORK FAILURE', e.message);
      return IdentifyAttempt.fail(IdentifyFailureKind.network, e.message);
    } catch (e) {
      _log('API FAILURE', '$e');
      return IdentifyAttempt.fail(IdentifyFailureKind.api, '$e');
    }
  }

  static Future<DiagnoseAttempt> diagnosePlantHealth(
    File image, {
    Plant? plant,
  }) async {
    try {
      if (!image.existsSync()) {
        _log('LOCAL STORAGE FAILURE', 'diagnosis missing ${image.path}');
        return DiagnoseAttempt.fail(IdentifyFailureKind.local, 'missing file');
      }
      final bytes = await image.readAsBytes();
      _log(
        'REQUEST',
        'Combine diagnosis bytes=${bytes.length}',
      );
      final content = await PlantAiClient.complete(
        input: diagnosePromptFor(plant),
        imageBytes: bytes,
      );
      _log(
        'MODEL',
        'diagnosis chars=${content.length} preview=${_preview(content)}',
      );
      Map<String, dynamic>? json;
      try {
        json = PlantAiClient.extractJson(content);
      } catch (e) {
        _log('PARSER FAILURE', '$e');
        return DiagnoseAttempt.fail(IdentifyFailureKind.parser, '$e');
      }
      if (json == null) {
        _log('PARSER FAILURE', 'no json');
        return DiagnoseAttempt.fail(IdentifyFailureKind.parser, 'no json');
      }
      if (json['error'] != null) {
        _log('INVALID RESULT', '${json['error']}');
        return DiagnoseAttempt.fail(IdentifyFailureKind.invalid, '${json['error']}');
      }
      return DiagnoseAttempt.ok(json);
    } on PlantAiException catch (e) {
      final kind = _fromAi(e);
      _log(_debugLabel(kind), 'diagnosis ${e.message}');
      return DiagnoseAttempt.fail(kind, e.message);
    } on SocketException catch (e) {
      _log('NETWORK FAILURE', e.message);
      return DiagnoseAttempt.fail(IdentifyFailureKind.network, e.message);
    } catch (e) {
      _log('API FAILURE', '$e');
      return DiagnoseAttempt.fail(IdentifyFailureKind.api, '$e');
    }
  }

  Future<String> generateContent(String prompt) async {
    try {
      return (await PlantAiClient.complete(input: prompt)).trim();
    } catch (e) {
      debugPrint('Generate Content Error: $e');
      throw Exception('Unable to fetch plant information');
    }
  }

  static String _preview(String content) {
    final trimmed = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.length <= 120) return trimmed;
    return '${trimmed.substring(0, 117)}...';
  }

  static String _debugLabel(IdentifyFailureKind kind) {
    switch (kind) {
      case IdentifyFailureKind.network:
        return 'NETWORK FAILURE';
      case IdentifyFailureKind.api:
        return 'API FAILURE';
      case IdentifyFailureKind.model:
        return 'MODEL FAILURE';
      case IdentifyFailureKind.parser:
        return 'PARSER FAILURE';
      case IdentifyFailureKind.invalid:
        return 'INVALID RESULT';
      case IdentifyFailureKind.storage:
      case IdentifyFailureKind.local:
        return 'LOCAL STORAGE FAILURE';
    }
  }
}
