import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../model/data_model/plant_model.dart';
import '../utils/constants.dart';

class GeminiService {
  static String get _endpoint => AppConstants.geminiGenerateContentEndpoint;

  static Future<Plant?> identifyPlant(File image) async {
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final prompt = {
        "contents": [
          {
            "parts": [
              {
                "text": """
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
""",
              },
              {
                "inline_data": {"mime_type": "image/jpeg", "data": base64Image},
              },
            ],
          },
        ],
      };

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(prompt),
      );

      print("Status: ${response.statusCode}");
      print("Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        print("Gemini content: $content");
        if (content != null) {
          final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
          print("Match: ${match?.group(0)}");
          if (match != null) {
            final plantJson = jsonDecode(match.group(0)!);
            return Plant.fromGemini(plantJson, image.path);
          }
        }
      }
      return null;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> diagnosePlantHealth(File image) async {
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final prompt = {
        "contents": [
          {
            "parts": [
              {
                "text": """
You are a plant health diagnosis expert.
Analyze the attached plant image and provide a detailed health assessment in JSON format.

Required fields:
- plant_name: (Identify the plant if possible)
- overall_health: (Healthy/Unhealthy/Critical - overall status)
- health_score: (0-100, where 100 is perfectly healthy)
- issues_detected: [
    {
      "type": "pest/disease/nutrient/environmental",
      "name": "Specific issue name",
      "severity": "low/medium/high",
      "description": "Detailed description of the issue",
      "symptoms": ["List of visible symptoms"]
    }
  ]
- recommendations: [
    {
      "action": "What to do",
      "priority": "immediate/high/medium/low",
      "details": "Step-by-step instructions"
    }
  ]
- preventive_care: {
    "watering": "Watering advice",
    "sunlight": "Light requirements",
    "fertilization": "Fertilizer recommendations",
    "general": "General care tips"
  }
- prognosis: (Expected recovery time and outcome)

Format: JSON only. No extra explanation.
""",
              },
              {
                "inline_data": {"mime_type": "image/jpeg", "data": base64Image},
              },
            ],
          },
        ],
      };

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(prompt),
      );

      print("Diagnosis Status: ${response.statusCode}");
      print("Diagnosis Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        print("Gemini diagnosis content: $content");
        if (content != null) {
          final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
          print("Diagnosis Match: ${match?.group(0)}");
          if (match != null) {
            final diagnosisJson = jsonDecode(match.group(0)!);
            return diagnosisJson;
          }
        }
      }
      return null;
    } catch (e) {
      print('Diagnosis Error: $e');
      return null;
    }
  }

  /// Generate text content from Gemini
  Future<String> generateContent(String prompt) async {
    try {
      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "maxOutputTokens": 1024,
        }
      };

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (content != null) {
          return content.toString().trim();
        }
      }
      throw Exception('Failed to generate content');
    } catch (e) {
      print('Generate Content Error: $e');
      throw Exception('Unable to fetch plant information');
    }
  }
}
