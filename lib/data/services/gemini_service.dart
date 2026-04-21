import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/env_config.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    final apiKey = EnvConfig.geminiApiKey;

    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not set');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash-lite', 
      apiKey: apiKey,
    );
  }

  Future<String> sendMessage(String prompt) async {
    try {
      final response = await _model.generateContent([
        Content.text(prompt),
      ]);

      return response.text ?? 'No response';
    } catch (e) {
      return 'Error: $e';
    }
  }
}