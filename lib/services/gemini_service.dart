import 'dart:io';

import '../model/data_model/plant_model.dart';
import 'plant_ai_client.dart';

class GeminiService {
  static const _identifyPrompt = '''
You are a plant identification and care expert.
Analyze the attached image and provide structured JSON output with detailed plant information.

Required fields:
- plant_name_common: (Common name of the plant)
- plant_name_scientific: (Scientific name with genus and species)
- description: (Short description about the plant)
- taxonomy: {kingdom, family, genus, species}
- native_region: (Where it naturally grows)
- growth_season: (Seasonal cycle, flowering/fruiting period)
- toxicity: (Is it toxic to humans or pets? Yes/No + details)
- care_guide: {
    watering: (How often & how much water needed),
    sunlight: (Type & duration of sunlight needed),
    soil: (Soil type & pH preference),
    fertilization: (Type & frequency),
    pruning: (When & how to prune),
    propagation: (Best propagation methods)
}
- health_scan: (Based on the image, detect if the plant looks healthy or has issues)
- common_pests: (Possible pests & treatments)
- common_diseases: (Possible diseases & treatments)
- usage: (Medicinal, decorative, food, etc.)
- fun_fact: (One interesting fact for user engagement)

Format: JSON only. No extra explanation.
''';

  static const _diagnosePrompt = '''
You are a plant health diagnosis expert.
Analyze the attached plant image and provide a detailed health assessment in JSON format.

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

Do not use the words: symptoms, prognosis, critical, patient, disease diagnosis as a medical verdict.
Prefer plant language: what we noticed, likely issue, affected area, what to do next.

Format: JSON only.
''';

  static Future<Plant?> identifyPlant(File image) async {
    try {
      if (!image.existsSync()) {
        print('Identify error: image file missing at ${image.path}');
        return null;
      }
      final bytes = await image.readAsBytes();
      final content = await PlantAiClient.complete(
        input: _identifyPrompt,
        imageBytes: bytes,
      );
      print('Plant AI identify content: $content');
      final plantJson = PlantAiClient.extractJson(content);
      if (plantJson != null) {
        return Plant.fromGemini(plantJson, image.path);
      }
      return null;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> diagnosePlantHealth(File image) async {
    try {
      if (!image.existsSync()) {
        print('Diagnosis error: image file missing at ${image.path}');
        return null;
      }
      final bytes = await image.readAsBytes();
      final content = await PlantAiClient.complete(
        input: _diagnosePrompt,
        imageBytes: bytes,
      );
      print('Plant AI diagnosis content: $content');
      return PlantAiClient.extractJson(content);
    } catch (e) {
      print('Diagnosis Error: $e');
      return null;
    }
  }

  Future<String> generateContent(String prompt) async {
    try {
      return (await PlantAiClient.complete(input: prompt)).trim();
    } catch (e) {
      print('Generate Content Error: $e');
      throw Exception('Unable to fetch plant information');
    }
  }
}
