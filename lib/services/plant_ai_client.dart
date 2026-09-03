import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../utils/constants.dart';

class PlantAiException implements Exception {
  final IdentifyAiKind kind;
  final String message;
  final int? statusCode;

  const PlantAiException(this.kind, this.message, {this.statusCode});

  @override
  String toString() => 'PlantAiException($kind, $statusCode, $message)';
}

enum IdentifyAiKind { network, api, timeout }

/// Identify, Diagnose, Search, and AI Plant Expert all use Combine `/api/chat`.
/// Provider keys stay on the Combine server — never in the Flutter client.
class PlantAiClient {
  static const Duration timeout = Duration(seconds: 90);

  static Future<String> complete({
    required String input,
    List<int>? imageBytes,
  }) async {
    final body = buildRequestBody(input: input, imageBytes: imageBytes);
    return _postCombine(body);
  }

  static Future<String> _postCombine(Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.plantAiChatUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);

      debugPrint('Plant AI Combine ${AppConstants.plantAiChatUrl}');
      debugPrint('Plant AI status: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('Plant AI body: ${sanitizeLog(response.body)}');
        throw PlantAiException(
          IdentifyAiKind.api,
          'status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      return readOutput(jsonDecode(response.body));
    } on PlantAiException {
      rethrow;
    } on http.ClientException catch (e) {
      throw PlantAiException(IdentifyAiKind.network, e.message);
    } on TimeoutException {
      throw const PlantAiException(IdentifyAiKind.timeout, 'timeout');
    } on FormatException catch (e) {
      throw PlantAiException(IdentifyAiKind.api, 'invalid json: $e');
    }
  }

  /// Same Combine `/api/chat` body as AI Chat: `input` and `prompt` are aliases.
  static Map<String, dynamic> buildRequestBody({
    required String input,
    List<int>? imageBytes,
  }) {
    final body = <String, dynamic>{
      'input': input,
      'prompt': input,
    };
    if (imageBytes == null || imageBytes.isEmpty) return body;

    final jpeg = compressForUpload(imageBytes);
    if (jpeg.isEmpty) {
      throw const PlantAiException(IdentifyAiKind.api, 'empty_image');
    }
    body['image'] = 'data:image/jpeg;base64,${base64Encode(jpeg)}';
    body['mimeType'] = 'image/jpeg';
    debugPrint('Plant AI image jpegBytes=${jpeg.length}');
    return body;
  }

  static String readOutput(dynamic data) {
    if (data is String && data.trim().isNotEmpty) return data;
    if (data is! Map) {
      throw const PlantAiException(
        IdentifyAiKind.api,
        'unexpected response shape',
      );
    }

    debugPrint(
      'Plant AI provider: ${data['provider']} fallback: ${data['fallback']}',
    );

    for (final key in const [
      'output',
      'text',
      'message',
      'response',
      'content',
      'result',
    ]) {
      final text = stringifyOutput(data[key]);
      if (text != null) return text;
    }

    if (data.containsKey('plant_name_common') ||
        data.containsKey('error') ||
        data.containsKey('plant_name')) {
      return jsonEncode(Map<String, dynamic>.from(data));
    }

    throw const PlantAiException(IdentifyAiKind.api, 'empty output');
  }

  static String? stringifyOutput(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value;
    if (value is Map && value.isNotEmpty) {
      return jsonEncode(Map<String, dynamic>.from(value));
    }
    if (value is List && value.isNotEmpty) return jsonEncode(value);
    return null;
  }

  static Uint8List compressForUpload(List<int> bytes, {int maxBytes = 450000}) {
    final raw = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    try {
      final decoded = img.decodeImage(raw);
      if (decoded == null) {
        return raw;
      }
      var image = decoded;
      const maxSide = 1280;
      if (image.width > maxSide || image.height > maxSide) {
        image = img.copyResize(
          image,
          width: image.width >= image.height ? maxSide : null,
          height: image.height > image.width ? maxSide : null,
        );
      }
      var quality = 85;
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

  static String sanitizeLog(String value) {
    if (value.startsWith('data:image/')) return '[data-uri omitted]';
    return value.replaceAll(
      RegExp(r'[A-Za-z0-9+/]{80,}={0,2}'),
      '[base64 omitted]',
    );
  }
}
