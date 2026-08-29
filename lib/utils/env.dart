import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get geminiApiKey {
    final v = dotenv.env['GEMINI_API_KEY'];
    if (v == null || v.trim().isEmpty) {
      throw StateError('Missing GEMINI_API_KEY in .env');
    }
    return v.trim();
  }

  static String get geminiModel {
    final v = dotenv.env['GEMINI_MODEL'];
    return (v == null || v.trim().isEmpty) ? 'gemini-2.5-flash' : v.trim();
  }
}

