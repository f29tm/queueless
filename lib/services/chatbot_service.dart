import 'package:google_generative_ai/google_generative_ai.dart';
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

  late final GenerativeModel _model;
  late final ChatSession _chat;

  ChatbotService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: ApiKeys.gemini,
      systemInstruction: Content.system(_systemInstruction),
    );
    _chat = _model.startChat();
  }

  Future<String> sendMessage(String text) async {
    final response = await _chat.sendMessage(Content.text(text));
    return response.text ?? 'Sorry, I could not generate a response. Please try again.';
  }
}
