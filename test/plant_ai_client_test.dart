import 'package:flutter_test/flutter_test.dart';
import 'package:plantidentifier/services/plant_ai_client.dart';

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
    const output = '{"plant_name":"Monstera","overall_condition":"looking_okay"}';
    final json = PlantAiClient.extractJson(output);
    expect(json?['plant_name'], 'Monstera');
  });
}
