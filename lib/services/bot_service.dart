import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls the `car-assistant` Supabase Edge Function (Gemini).
///
/// No API keys are embedded in the client — the key lives only in Supabase
/// Edge Function environment variables.
class BotService {
  BotService._();
  static final BotService instance = BotService._();

  /// Maximum length for a single user message (keeps payloads small).
  static const int _maxMessageLength = 2000;

  /// Sends a message to the `car-assistant` Edge Function and returns the
  /// AI reply text. Throws an [Exception] with a user-friendly message on
  /// network, API, quota, or parse failures.
  Future<String> askAssistant(String message) async {
    final text = message.trim();
    if (text.isEmpty) {
      throw Exception('Please enter a message.');
    }
    if (text.length > _maxMessageLength) {
      throw Exception(
        'Message is too long. Please keep it under $_maxMessageLength characters.',
      );
    }

    try {
      final response =
          await Supabase.instance.client.functions.invoke(
        'car-assistant',
        body: {'message': text},
      );

      final data = response.data;

      if (data is Map && data['reply'] is String) {
        return data['reply'] as String;
      }

      final errorMessage = data is Map
          ? data['error']?.toString()
          : null;

      throw Exception(
        errorMessage ?? 'The AI returned an unexpected response.',
      );
    } on FunctionException catch (e) {
      throw Exception(
        'AI request failed (HTTP ${e.status}): ${e.details}',
      );
    } catch (e) {
      throw Exception('Could not contact AI assistant: $e');
    }
  }
}
