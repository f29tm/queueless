import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:queueless/services/symptom_extraction_service.dart';

/// Words that must never appear in the extraction schema or output —
/// the NLP layer fills form fields only, it does not decide urgency
/// (FR-NLP-02 / ML-NLP-01).
const List<String> _forbiddenWords = [
  'severity',
  'urgency',
  'urgent',
  'acuity',
  'triage_level',
  'ktas',
  'priority',
];

http.Response _geminiJsonResponse(Map<String, dynamic> fields) {
  return http.Response(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': jsonEncode(fields)}
            ]
          }
        }
      ]
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  // ── request contract ───────────────────────────────────────────────────────

  group('extraction request contract', () {
    late Map<String, dynamic> sentBody;

    Future<ExtractedSymptoms?> run(String transcript) {
      final client = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _geminiJsonResponse({
          'chief_complaint': 'fall from ladder with arm pain',
          'symptoms': ['Fracture'],
          'nrs_pain': 8,
          'injury': true,
          'arrival_mode': 'ambulance',
          'mental_status': 'alert',
        });
      });
      return SymptomExtractionService(client: client).extract(transcript);
    }

    test('is deterministic: temperature 0 and JSON response mime type',
        () async {
      await run('I fell off a ladder');
      final config = sentBody['generationConfig'] as Map<String, dynamic>;
      expect(config['temperature'], 0);
      expect(config['responseMimeType'], 'application/json');
    });

    test('schema contains exactly the six addendum fields and nothing else',
        () async {
      await run('I fell off a ladder');
      final schema =
          sentBody['generationConfig']['responseSchema'] as Map<String, dynamic>;
      final properties = schema['properties'] as Map<String, dynamic>;
      expect(
        properties.keys.toSet(),
        {
          'chief_complaint',
          'symptoms',
          'nrs_pain',
          'injury',
          'arrival_mode',
          'mental_status',
        },
      );
    });

    test('schema contains NO severity/urgency/acuity/triage-level field',
        () async {
      await run('I fell off a ladder');
      final schemaJson = jsonEncode(
        sentBody['generationConfig']['responseSchema'],
      ).toLowerCase();
      for (final word in _forbiddenWords) {
        expect(schemaJson.contains(word), isFalse,
            reason: 'schema must not mention "$word"');
      }
    });

    test('sends the transcript as the user content', () async {
      await run('shortness of breath since this morning');
      final parts = sentBody['contents'][0]['parts'] as List;
      expect(parts.first['text'], 'shortness of breath since this morning');
    });
  });

  // ── response parsing on fixed transcripts ──────────────────────────────────

  group('extraction output', () {
    test('parses all fields from a fully-determined description', () async {
      final client = MockClient((_) async => _geminiJsonResponse({
            'chief_complaint': 'chest pain radiating to left arm',
            'symptoms': ['Chest pain', 'Shortness of breath'],
            'nrs_pain': 8,
            'injury': false,
            'arrival_mode': 'car',
            'mental_status': 'alert',
          }));
      final result = await SymptomExtractionService(client: client)
          .extract('My chest hurts badly, pain is 8, my son is driving me');

      expect(result, isNotNull);
      expect(result!.chiefComplaint, 'chest pain radiating to left arm');
      expect(result.symptoms, ['Chest pain', 'Shortness of breath']);
      expect(result.nrsPain, 8.0);
      expect(result.injury, isFalse);
      expect(result.arrivalMode, 'car');
      expect(result.mentalStatus, 'alert');
    });

    test('leaves undetermined fields null rather than guessed (FR-NLP-04)',
        () async {
      final client = MockClient((_) async => _geminiJsonResponse({
            'chief_complaint': 'headache',
            'symptoms': ['Headache'],
            'nrs_pain': null,
            'injury': null,
            'arrival_mode': null,
            'mental_status': 'alert',
          }));
      final result = await SymptomExtractionService(client: client)
          .extract('I have a headache');

      expect(result!.nrsPain, isNull);
      expect(result.injury, isNull);
      expect(result.arrivalMode, isNull);
    });

    test('toJson holds exactly the six schema keys and no severity field',
        () async {
      final client = MockClient((_) async => _geminiJsonResponse({
            'chief_complaint': 'abdominal pain',
            'symptoms': ['Abdominal pain'],
            'nrs_pain': 5,
            'injury': null,
            'arrival_mode': 'walk',
            'mental_status': 'alert',
          }));
      final result = await SymptomExtractionService(client: client)
          .extract('my stomach hurts, pain about 5, I walked here');

      final json = result!.toJson();
      expect(
        json.keys.toSet(),
        {
          'chief_complaint',
          'symptoms',
          'nrs_pain',
          'injury',
          'arrival_mode',
          'mental_status',
        },
      );
      final encoded = jsonEncode(json).toLowerCase();
      for (final word in _forbiddenWords) {
        expect(encoded.contains(word), isFalse,
            reason: 'output must not contain "$word"');
      }
    });

    test('encoding maps follow the addendum §4 table', () {
      expect(kArrivalModeCodes,
          {'walk': 1, 'ambulance': 2, 'car': 3, 'transit': 4, 'referred': 5});
      expect(kMentalStatusCodes,
          {'alert': 1, 'verbal': 2, 'pain': 3, 'unresponsive': 4});
    });
  });

  // ── failure fallback (FR-NLP-06) ───────────────────────────────────────────

  group('extraction failure falls back to manual entry', () {
    test('returns null on HTTP 500', () async {
      final client = MockClient((_) async => http.Response('boom', 500));
      final result =
          await SymptomExtractionService(client: client).extract('fever');
      expect(result, isNull);
    });

    test('returns null when the reply is not valid JSON', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'sorry, I cannot help with that'}
                    ]
                  }
                }
              ]
            }),
            200,
          ));
      final result =
          await SymptomExtractionService(client: client).extract('fever');
      expect(result, isNull);
    });

    test('returns null on empty candidates', () async {
      final client = MockClient(
          (_) async => http.Response(jsonEncode({'candidates': []}), 200));
      final result =
          await SymptomExtractionService(client: client).extract('fever');
      expect(result, isNull);
    });

    test('returns null for a blank transcript without calling the API',
        () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      final result =
          await SymptomExtractionService(client: client).extract('   ');
      expect(result, isNull);
      expect(called, isFalse);
    });
  });
}
