import 'env.dart';

class AppConstants {
  /// Same Combine → Gemini proxy used by AI Chat, Identify, and Diagnose.
  static const String plantAiChatUrl =
      'https://combine-api-ruby.vercel.app/api/chat';

  // API Configuration
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com';

  static String get geminiApiKey => AppEnv.geminiApiKey;
  static String get geminiModel => AppEnv.geminiModel;

  // API Endpoints
  static String get geminiGenerateContentEndpoint =>
      '$geminiBaseUrl/v1/models/$geminiModel:generateContent?key=$geminiApiKey';

  // Add other app-wide constants here
  static const String appName = 'PlantFollow';
  static const String defaultLocale = 'en_US';
}
