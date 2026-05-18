import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:queueless/services/chatbot_service.dart';

http.Response _geminiResponse(String text) {
  return http.Response(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ]
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}

/// Returns a MockClient that handles the listAvailableModels GET with 200
/// and the sendMessage POST with [postResponse].
MockClient _mockClient(http.Response Function() postResponse) {
  return MockClient((request) async {
    if (request.method == 'GET') return http.Response('{}', 200);
    return postResponse();
  });
}

void main() {
  // ── sendMessage success ──────────────────────────────────────────────────────

  group('sendMessage success', () {
    test('returns text from valid Gemini response', () async {
      final service = ChatbotService(
        client: _mockClient(() => _geminiResponse('Hello! How can I help?')),
      );
      final reply = await service.sendMessage('hello');
      expect(reply, 'Hello! How can I help?');
    });

    test('history grows by 2 after one call (user + model)', () async {
      final service = ChatbotService(
        client: _mockClient(() => _geminiResponse('hi there')),
      );
      await service.sendMessage('hello');
      expect(service.history.length, 2);
    });

    test('history grows by 4 after two sequential calls', () async {
      final service = ChatbotService(
        client: _mockClient(() => _geminiResponse('response')),
      );
      await service.sendMessage('first');
      await service.sendMessage('second');
      expect(service.history.length, 4);
    });
  });

  // ── sendMessage failure ──────────────────────────────────────────────────────

  group('sendMessage failure', () {
    test('throws Exception on 500 response', () async {
      final service = ChatbotService(
        client: MockClient(
          (request) async => http.Response('Server error', 500),
        ),
      );
      await expectLater(service.sendMessage('hello'), throwsException);
    });

    test('history does NOT grow after 500 (user turn is rolled back)', () async {
      final service = ChatbotService(
        client: MockClient(
          (request) async => http.Response('Server error', 500),
        ),
      );
      try {
        await service.sendMessage('hello');
      } catch (_) {}
      expect(service.history.length, 0);
    });

    test('throws Exception on 200 with empty candidates []', () async {
      final service = ChatbotService(
        client: _mockClient(
          () => http.Response(
            jsonEncode({'candidates': []}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(service.sendMessage('hello'), throwsException);
    });
  });
}
