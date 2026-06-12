import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:queueless/screens/patient/symptom_assessment_screen.dart';
import 'package:queueless/services/speech_input_service.dart';
import 'package:queueless/services/symptom_extraction_service.dart';
import 'package:queueless/services/triage_service.dart';

/// Deterministic "speech unavailable / permission denied" double — the exact
/// degraded environment FR-VOICE-04/05 require the typed form to survive.
/// (Also keeps tests off the real plugin, which the Windows host registers.)
class _UnavailableSpeechService extends SpeechInputService {
  @override
  Future<bool> init({void Function(String status)? onStatus}) async => false;

  @override
  Future<String?> resolveLocaleId(String languageCode) async => null;

  @override
  Future<void> start({
    String? localeId,
    required void Function(String text, bool isFinal) onText,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

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

/// Pumps the real screen with a fake profile (no Firebase), a Gemini
/// MockClient for extraction, and a predictor that captures the Stage 1
/// payload and halts the flow before any Firestore write.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<Stage1Request> captured,
  Map<String, dynamic>? extractionFields,
}) async {
  // Tall viewport so the whole single-scroll form is built and tappable.
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final extraction = SymptomExtractionService(
    client: MockClient((_) async =>
        _geminiJsonResponse(extractionFields ?? const {})),
  );

  await tester.pumpWidget(
    MaterialApp(
      // Unique key so repeated pumps in one test rebuild the screen state
      // (and its injected services) from scratch.
      key: UniqueKey(),
      home: SymptomAssessmentScreen(
        profileOverride: (name: 'Test Patient', age: 45, sex: 1),
        speechService: _UnavailableSpeechService(),
        extractionService: extraction,
        predictStage1: (request) async {
          captured.add(request);
          // Halt before navigation/Firestore — the payload is what matters.
          return TriageResult.error('stop for test');
        },
      ),
    ),
  );
}

Future<void> _runExtraction(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nlp_extract_button')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.text('Get AI Assessment →'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Lets the result snackbar's auto-dismiss timer expire so the test ends
/// without pending timers.
Future<void> _drainSnackbars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  // ── FR-NLP-03: suggestions are editable and never auto-submitted ──────────

  testWidgets(
      'extracted values render as a pending suggestion card, apply into '
      'editable controls, and never trigger submission', (tester) async {
    final captured = <Stage1Request>[];
    await _pumpScreen(
      tester,
      captured: captured,
      extractionFields: {
        'chief_complaint': 'fever with body aches',
        'symptoms': ['Fever'],
        'nrs_pain': 7,
        'injury': false,
        'arrival_mode': 'car',
        'mental_status': 'alert',
      },
    );

    await tester.enterText(
        find.byType(TextField), 'I feel hot, my pain is 7 out of 10');
    await tester.pump();

    await _runExtraction(tester);

    // Suggestions render as a clearly-marked pending card…
    expect(find.byKey(const Key('nlp_suggestion_card')), findsOneWidget);
    expect(find.textContaining('suggestions only'), findsOneWidget);
    // …and nothing has been submitted.
    expect(captured, isEmpty);

    await tester.tap(find.byKey(const Key('nlp_apply_button')));
    await tester.pump();

    // Applied values land in the regular editable form controls.
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 7.0);
    expect(slider.onChanged, isNotNull, reason: 'pain stays editable');
    expect(find.textContaining('1 symptoms'), findsOneWidget);
    expect(find.byKey(const Key('nlp_applied_banner')), findsOneWidget);

    // Applying still does not submit anything (FR-NLP-03).
    expect(captured, isEmpty);

    // The transcript remains editable after applying.
    await tester.enterText(find.byType(TextField), 'actually it started today');
    await tester.pump();
    expect(captured, isEmpty);
  });

  testWidgets('dismissing suggestions leaves the form untouched',
      (tester) async {
    final captured = <Stage1Request>[];
    await _pumpScreen(
      tester,
      captured: captured,
      extractionFields: {
        'chief_complaint': 'headache',
        'symptoms': ['Headache'],
        'nrs_pain': 9,
        'injury': null,
        'arrival_mode': null,
        'mental_status': 'alert',
      },
    );

    await tester.enterText(find.byType(TextField), 'terrible headache, 9/10');
    await tester.pump();
    await _runExtraction(tester);

    await tester.tap(find.byKey(const Key('nlp_dismiss_button')));
    await tester.pump();

    expect(find.byKey(const Key('nlp_suggestion_card')), findsNothing);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 0.0, reason: 'dismissed suggestions change nothing');
    expect(captured, isEmpty);
  });

  // ── FR-VOICE-04/05: typed form stays fully functional without voice ───────

  testWidgets(
      'form is still submittable when speech recognition is unavailable',
      (tester) async {
    final captured = <Stage1Request>[];
    await _pumpScreen(tester, captured: captured);

    // In the test environment no speech plugin exists — tapping the mic must
    // degrade gracefully with a friendly message, not crash.
    await tester.tap(find.byKey(const Key('voice_mic_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining("Voice input isn't available"), findsOneWidget);

    // The typed path still submits.
    await tester.enterText(
        find.byType(TextField), 'sore throat and mild fever');
    await tester.pump();
    await _submit(tester);

    expect(captured, hasLength(1));
    expect(
      captured.single.toJson()['chief_complaint'],
      'sore throat and mild fever',
    );

    await _drainSnackbars(tester);
  });

  // ── ML-NLP-01: identical Stage 1 payload for typed vs extracted entry ─────

  testWidgets(
      'Stage 1 payload is byte-identical whether fields were typed or '
      'extracted and confirmed', (tester) async {
    const text = 'crushing chest pain for 20 minutes';

    // Run 1 — patient types the description and submits.
    final typedCaptured = <Stage1Request>[];
    await _pumpScreen(tester, captured: typedCaptured);
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await _submit(tester);
    expect(typedCaptured, hasLength(1));
    await _drainSnackbars(tester);

    // Run 2 — same description goes through extraction + confirm instead.
    final nlpCaptured = <Stage1Request>[];
    await _pumpScreen(
      tester,
      captured: nlpCaptured,
      extractionFields: {
        'chief_complaint': text, // canonical English == the typed text
        'symptoms': [],
        'nrs_pain': null,
        'injury': null,
        'arrival_mode': null,
        'mental_status': 'alert',
      },
    );
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await _runExtraction(tester);
    await tester.tap(find.byKey(const Key('nlp_apply_button')));
    await tester.pump();
    await _submit(tester);
    expect(nlpCaptured, hasLength(1));
    await _drainSnackbars(tester);

    // The NLP path added no triage signal and no extra fields.
    expect(
      jsonEncode(nlpCaptured.single.toJson()),
      jsonEncode(typedCaptured.single.toJson()),
    );
  });
}
