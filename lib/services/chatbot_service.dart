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
- Reply in the language the patient writes in (Arabic or English)
- Never reveal internal model signals such as confidence scores, entropy, or review flags
''';

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final http.Client _client;
  final List<Map<String, dynamic>> _history = [];

  /// Patient-safe visit summary injected into the system instruction so the
  /// assistant can personalize answers. Must only ever contain what the
  /// patient already sees in the app — never confidence, entropy, or the
  /// deferral flag (FR-RESULT-02).
  String? _patientContext;

  ChatbotService({http.Client? client, String? patientContext})
    : _client = client ?? http.Client(),
      _patientContext = patientContext;

  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  void updateContext(String? context) => _patientContext = context;

  void resetConversation() => _history.clear();

  String get _effectiveSystemInstruction => _patientContext == null
      ? _systemInstruction
      : '$_systemInstruction\n'
            'PATIENT CONTEXT (the patient already sees all of this in the app — '
            'use it to personalize answers, never to change their triage):\n'
            '$_patientContext';

  Future<String> sendMessage(String text) async {
    _history.add({
      'role': 'user',
      'parts': [
        {'text': text},
      ],
    });

    try {
      final uri = Uri.parse(
        '$_baseUrl/gemini-2.5-flash:generateContent?key=${ApiKeys.gemini}',
      );

      final body = jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': _effectiveSystemInstruction},
          ],
        },
        'contents': _history,
        'generationConfig': {'maxOutputTokens': 500},
      });

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode != 200) {
        _history.removeLast();
        throw Exception('Gemini API error ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      final parts = (candidates == null || candidates.isEmpty)
          ? null
          : candidates.first['content']?['parts'] as List?;
      final reply = (parts == null || parts.isEmpty)
          ? null
          : parts.first['text'] as String?;

      if (reply == null || reply.isEmpty) {
        _history.removeLast();
        throw Exception('Empty response from Gemini API');
      }

      _history.add({
        'role': 'model',
        'parts': [
          {'text': reply},
        ],
      });

      return reply;
    } catch (e) {
      rethrow;
    }
  }
}
