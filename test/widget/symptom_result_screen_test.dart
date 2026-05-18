import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/services/triage_service.dart';
import 'package:queueless/screens/patient/symptom_result_screen.dart';

TriageResult _makeResult({
  required String prediction,
  double confidence = 0.85,
  bool deferred = false,
}) {
  return TriageResult(
    prediction: prediction,
    confidence: confidence,
    probabilities: {
      'Emergency': 0.8,
      'Urgent': 0.15,
      'Non-Urgent': 0.05,
    },
    deferred: deferred,
    entropy: 0.3,
    stage: 1,
    isError: false,
  );
}

Future<void> pumpScreen(WidgetTester tester, TriageResult result) async {
  await tester.pumpWidget(MaterialApp(
    home: SymptomResultScreen(
      triageResult: result,
      queueDocId: 'test-doc-id',
      selectedSymptoms: ['Chest pain'],
    ),
  ));
  await tester.pump();
}

void main() {
  // ── Emergency prediction ─────────────────────────────────────────────────────

  group('Emergency prediction', () {
    testWidgets('label text "Emergency" is found on screen', (tester) async {
      await pumpScreen(tester, _makeResult(prediction: 'Emergency'));
      expect(find.text('Emergency'), findsWidgets);
    });

    testWidgets('button text containing "999" is found', (tester) async {
      await pumpScreen(tester, _makeResult(prediction: 'Emergency'));
      expect(find.textContaining('999'), findsWidgets);
    });

    testWidgets('"I Have Arrived at the Hospital" is not the primary CTA', (tester) async {
      await pumpScreen(tester, _makeResult(prediction: 'Emergency'));
      // Primary CTA is the 999 emergency button
      expect(find.textContaining('999'), findsWidgets);
      // I Have Arrived exists but as a secondary TextButton, not a primary ElevatedButton
      expect(find.text('I Have Arrived at the Hospital'), findsOneWidget);
      // It must NOT be wrapped in an ElevatedButton (it's a TextButton instead)
      expect(
        find.ancestor(
          of: find.text('I Have Arrived at the Hospital'),
          matching: find.byType(TextButton),
        ),
        findsAtLeastNWidgets(1),
      );
    });
  });

  // ── Urgent prediction ────────────────────────────────────────────────────────

  group('Urgent prediction', () {
    testWidgets('label text "Urgent" is found on screen', (tester) async {
      await pumpScreen(tester, _makeResult(prediction: 'Urgent'));
      expect(find.text('Urgent'), findsWidgets);
    });

    testWidgets('"I Have Arrived at the Hospital" button is present', (tester) async {
      await pumpScreen(tester, _makeResult(prediction: 'Urgent'));
      expect(find.text('I Have Arrived at the Hospital'), findsOneWidget);
    });
  });

  // ── Non-Urgent prediction ────────────────────────────────────────────────────

  group('Non-Urgent prediction', () {
    testWidgets('label text "Non-Urgent" is found (not "NON-URGENT")', (tester) async {
      await pumpScreen(tester, _makeResult(prediction: 'Non-Urgent'));
      expect(find.text('Non-Urgent'), findsWidgets);
    });

    testWidgets('"I Have Arrived at the Hospital" button is present', (tester) async {
      await pumpScreen(tester, _makeResult(prediction: 'Non-Urgent'));
      expect(find.text('I Have Arrived at the Hospital'), findsOneWidget);
    });
  });

  // ── Label casing ─────────────────────────────────────────────────────────────

  group('Label casing', () {
    testWidgets('"EMERGENCY" all-caps is NOT found for Emergency prediction', (tester) async {
      await pumpScreen(tester, _makeResult(prediction: 'Emergency'));
      expect(find.text('EMERGENCY'), findsNothing);
    });

    testWidgets('"NON-URGENT" all-caps is NOT found for Non-Urgent prediction', (tester) async {
      await pumpScreen(tester, _makeResult(prediction: 'Non-Urgent'));
      expect(find.text('NON-URGENT'), findsNothing);
    });
  });
}
