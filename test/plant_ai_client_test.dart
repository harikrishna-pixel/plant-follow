import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plantidentifier/services/gemini_service.dart';
import 'package:plantidentifier/services/plant_ai_client.dart';
import 'package:plantidentifier/services/plant_chat_logic.dart';
import 'package:plantidentifier/utils/constants.dart';

Uint8List _jpeg() =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8), quality: 70));

void main() {
  test('extractJson reads a fenced Combine/Gemini payload', () {
    const output = '''
```json
{
  "plant_name_common": "Aloe Vera",
  "plant_name_scientific": "Aloe barbadensis"
}
```
''';
    final json = PlantAiClient.extractJson(output);
    expect(json?['plant_name_common'], 'Aloe Vera');
    expect(json?['plant_name_scientific'], 'Aloe barbadensis');
  });

  test('extractJson reads a raw JSON object', () {
    const output =
        '{"plant_name":"Monstera","overall_condition":"looking_okay"}';
    final json = PlantAiClient.extractJson(output);
    expect(json?['plant_name'], 'Monstera');
  });

  test('readOutput accepts Combine string output', () {
    expect(
      PlantAiClient.readOutput({'output': 'Hello from Combine', 'provider': 'gemini'}),
      'Hello from Combine',
    );
  });

  test('readOutput accepts Combine JSON object output', () {
    final text = PlantAiClient.readOutput({
      'output': {
        'plant_name_common': 'Monstera',
        'plant_name_scientific': 'Monstera deliciosa',
      },
      'provider': 'gemini',
    });
    final json = PlantAiClient.extractJson(text);
    expect(json?['plant_name_common'], 'Monstera');
  });

  test('text-only request uses Combine input/prompt', () {
    final body = PlantAiClient.buildRequestBody(input: 'How often should I water?');
    expect(body, {
      'input': 'How often should I water?',
      'prompt': 'How often should I water?',
    });
    expect(body.containsKey('contents'), isFalse);
  });

  test('Identify, Diagnose, and Chat share the Combine chat URL', () {
    expect(
      AppConstants.plantAiChatUrl,
      'https://combine-api-ruby.vercel.app/api/chat',
    );
  });

  test('JPEG vision body is a Combine data URI, not a Gemini client request', () {
    final jpeg = _jpeg();
    final body = PlantAiClient.buildRequestBody(
      input: 'Identify this plant.',
      imageBytes: jpeg,
    );
    expect(body['input'], 'Identify this plant.');
    expect(body['prompt'], 'Identify this plant.');
    expect(body['mimeType'], 'image/jpeg');
    expect(body['contents'], isNull);
    expect(body['image'], startsWith('data:image/jpeg;base64,'));
    final b64 = (body['image'] as String).split(',').last;
    expect(base64Decode(b64), isNotEmpty);
  });

  test('PNG is normalized to JPEG before Combine upload', () {
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 32, height: 24)));
    final body = PlantAiClient.buildRequestBody(
      input: 'what plant is this',
      imageBytes: png,
    );
    final b64 = (body['image'] as String).split(',').last;
    final bytes = base64Decode(b64);
    expect(bytes[0], 0xFF);
    expect(bytes[1], 0xD8);
  });

  test('empty image is rejected instead of becoming a silent text-only body', () {
    expect(
      () => PlantAiClient.buildRequestBody(input: 'identify', imageBytes: []),
      returnsNormally,
    );
    expect(
      PlantAiClient.buildRequestBody(input: 'identify', imageBytes: []),
      {'input': 'identify', 'prompt': 'identify'},
    );
  });

  test('identification request forwards prompt and image together', () {
    const prompt = 'Analyze the attached image and provide structured JSON only.';
    final body = PlantAiClient.buildRequestBody(
      input: prompt,
      imageBytes: _jpeg(),
    );
    expect(body['input'], contains('attached image'));
    expect(body['image'], startsWith('data:image/jpeg;base64,'));
  });

  test('diagnosis request forwards image; species hint stays text', () {
    final prompt = GeminiService.diagnosePromptFor(null);
    expect(prompt, contains('Analyze the attached image'));
    final body = PlantAiClient.buildRequestBody(
      input: '$prompt\nA saved garden record names this plant as Peace Lily.',
      imageBytes: _jpeg(),
    );
    expect(body['input'], contains('Peace Lily'));
    expect(body['image'], isNotNull);
  });

  test('chat follow-up with image forwards image again on Combine', () {
    final prompt = PlantChatLogic.botanistPrompt(
      question: 'Could watering cause it?',
      hasImage: true,
      previousQuestion: 'What is wrong with this leaf?',
    );
    final body = PlantAiClient.buildRequestBody(
      input: prompt,
      imageBytes: _jpeg(),
    );
    expect(body['input'], contains('Could watering cause it?'));
    expect(body['input'], contains('What is wrong with this leaf?'));
    expect(body['image'], startsWith('data:image/jpeg;base64,'));
  });

  test('logs do not keep raw base64', () {
    final raw = 'data:image/jpeg;base64,${'A' * 100}';
    expect(PlantAiClient.sanitizeLog(raw), isNot(contains('AAAA')));
    expect(PlantAiClient.sanitizeLog(raw), isNot(contains('data:image/jpeg;base64,')));
  });

  test('compressForUpload always emits JPEG bytes', () {
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 32, height: 24)),
    );
    final jpeg = PlantAiClient.compressForUpload(png);
    expect(jpeg[0], 0xFF);
    expect(jpeg[1], 0xD8);
  });
}
