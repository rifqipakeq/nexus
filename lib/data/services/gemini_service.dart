import '../../core/env_config.dart';
import 'api_service.dart';

/// Sends prompts to Google Gemini API via HTTP POST.
/// No SDK required – simple REST call.
class GeminiService {
  final ApiService _api;

  GeminiService(this._api);

  /// Send a prompt to Gemini and return the text response.
  Future<String> sendMessage(String prompt) async {
    final apiKey = EnvConfig.geminiApiKey;
    if (apiKey.isEmpty) {
      return 'Gemini API key not configured. Please set GEMINI_API_KEY in .env';
    }

    try {
      final response = await _api.post(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1024},
        },
      );

      final data = response.data;
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        final parts = content['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'] ?? 'No response text';
        }
      }
      return 'No response from Gemini.';
    } catch (e) {
      return 'Error: $e';
    }
  }
}
