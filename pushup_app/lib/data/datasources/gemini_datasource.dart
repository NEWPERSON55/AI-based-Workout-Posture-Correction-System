import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

class GeminiDatasource {
  static const String _model = 'gemini-2.5-flash';

  /// System prompt (زي ما هو 👌)
  static const _systemPrompt = '''
You are KINETIC AI, an expert professional fitness coach built into a workout tracking app.

Your responsibilities:
• Provide personalised exercise advice for push-ups and squats
• Analyse the user's recent workout data when provided
• Give form correction tips, recovery advice, and progressive overload suggestions
• Calculate and explain calorie burn estimates
• Be motivating, concise, and evidence-based
• Use a friendly, coaching tone — not overly casual, not robotic

When the user shares workout context, reference specific numbers (reps, accuracy, calories) in your response.
Keep responses under 150 words unless the user asks for a detailed explanation.
''';

  /// Send message to Gemini (HTTP)
  Future<String> sendMessage(
    String userMessage, {
    String? workoutContext,
    String? userProfileContext,
  }) async {
    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=${AppConfig.geminiApiKey}",
      );

      // بناء الرسالة زي ما كنت عامل
      final buffer = StringBuffer();

      if (userProfileContext != null && userProfileContext.isNotEmpty) {
        buffer.writeln('User Profile:\n$userProfileContext\n');
      }

      if (workoutContext != null && workoutContext.isNotEmpty) {
        buffer.writeln('Recent Workouts:\n$workoutContext\n');
      }

      buffer.writeln('User Message:\n$userMessage');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": buffer.toString()},
              ],
            },
          ],
          "systemInstruction": {
            "parts": [
              {"text": _systemPrompt},
            ],
          },
          "generationConfig": {
            "temperature": 0.7,
            "topP": 0.9,
            "maxOutputTokens": 1024,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return data["candidates"][0]["content"]["parts"][0]["text"] ??
            "No response";
      } else {
        return "Error: ${response.body}";
      }
    } catch (e) {
      return "Exception: $e";
    }
  }

  /// Reset chat (هنستخدمه بعدين لو عملنا memory)
  void resetChat() {
    // حالياً فاضي لأننا مش بنستخدم session
  }
}
