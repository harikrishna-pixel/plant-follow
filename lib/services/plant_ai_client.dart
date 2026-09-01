import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../utils/constants.dart';

/// Same backend AI Chat uses: Combine proxy → Gemini.
class PlantAiClient {
  static const Duration timeout = Duration(seconds: 90);

  static Future<String> complete({
    required String input,
    List<int>? imageBytes,
  }) async {
    final body = <String, dynamic>{'input': input};
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final compressed = compressForUpload(imageBytes);
      body['image'] = base64Encode(compressed);
      body['mimeType'] = 'image/jpeg';
    }

    final response = await http
        .post(
          Uri.parse(AppConstants.plantAiChatUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);

    debugPrint('Plant AI status: ${response.statusCode}');
    if (response.statusCode != 200) {
      debugPrint('Plant AI body: ${response.body}');
      throw Exception('Plant AI error ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data is! Map) {
      throw Exception('Plant AI returned an unexpected response');
    }
    debugPrint('Plant AI provider: ${data['provider']}');
    final output = data['output'];
    if (output is! String || output.trim().isEmpty) {
      throw Exception('Plant AI returned no output');
    }
    return output;
  }

  static Uint8List compressForUpload(List<int> bytes, {int maxBytes = 900000}) {
    final raw = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    if (raw.length <= maxBytes) return raw;
    try {
      final decoded = img.decodeImage(raw);
      if (decoded == null) return raw;
      var image = decoded;
      const maxSide = 1280;
      if (image.width > maxSide || image.height > maxSide) {
        image = img.copyResize(
          image,
          width: image.width >= image.height ? maxSide : null,
          height: image.height > image.width ? maxSide : null,
        );
      }
      var quality = 80;
      var out = img.encodeJpg(image, quality: quality);
      while (out.length > maxBytes && quality > 40) {
        quality -= 10;
        out = img.encodeJpg(image, quality: quality);
      }
      return Uint8List.fromList(out);
    } catch (e) {
      debugPrint('Plant AI compress skipped: $e');
      return raw;
    }
  }

  static Map<String, dynamic>? extractJson(String text) {
    final fence = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```').firstMatch(text);
    final raw =
        fence?.group(1) ?? RegExp(r'\{[\s\S]*\}').firstMatch(text)?.group(0);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }
}
