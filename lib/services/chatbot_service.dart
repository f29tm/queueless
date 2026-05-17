import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

class ChatbotService {
  static const String _systemInstruction = '''
You are a helpful medical assistant for QueueLess, an AI-assisted emergency department triage app used in Abu Dhabi.

Your role:
- Help patients understand their triage result (Emergency, Urgent, or Non-Urgent)
- Explain what to expect during their hospital visit
- Answer general questions about symptoms, wait times, and the check-in process
- Provide calm, reassuring, and clear information in plain language

Guidelines:
- Never diagnose conditions or prescribe medication
- Always recommend seeing a healthcare professional for serious concerns
- Keep responses concise and easy to understand
- If a patient describes a life-threatening emergency (e.g., chest pain, difficulty breathing, stroke symptoms), immediately tell them to call emergency services or go to the nearest ER now
- Be empathetic and supportive — patients may be anxious
''';

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  final List<Map<String, dynamic>> _history = [];

  Future<String> sendMessage(String text) async {
    _history.add({
      'role': 'user',
      'parts': [{'text': text}],
    });

    final uri = Uri.parse('$_endpoint?key=${ApiKeys.gemini}');

    final body = jsonEncode({
      'system_instruction': {
        'parts': [{'text': _systemInstruction}],
      },
      'contents': _history,
      'generationConfig': {'maxOutputTokens': 500},
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      _history.removeLast();
      throw Exception(
          'Gemini API error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final reply = (json['candidates'] as List?)
        ?.firstOrNull?['content']?['parts']
        ?.firstOrNull?['text'] as String?;

    if (reply == null || reply.isEmpty) {
      _history.removeLast();
      throw Exception('Empty response from Gemini API');
    }

    _history.add({
      'role': 'model',
      'parts': [{'text': reply}],
    });

    return reply;
  }
}
