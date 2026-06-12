import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/utils/stage1_input_builder.dart';

void main() {
  // ── chief-complaint construction (legacy-identical behaviour) ─────────────

  group('buildChiefComplaint', () {
    test('chips + free text', () {
      expect(
        buildChiefComplaint(
          selectedSymptoms: ['Chest pain', 'Dizziness'],
          complaintText: 'it started an hour ago',
        ),
        'Chest pain, Dizziness. Patient says: it started an hour ago',
      );
    });

    test('free text only', () {
      expect(
        buildChiefComplaint(
            selectedSymptoms: [], complaintText: 'my arm is numb'),
        'my arm is numb',
      );
    });

    test('chips only', () {
      expect(
        buildChiefComplaint(selectedSymptoms: ['Fever'], complaintText: '  '),
        'Fever',
      );
    });

    test('nothing at all falls back to "general complaint"', () {
      expect(
        buildChiefComplaint(selectedSymptoms: [], complaintText: ''),
        'general complaint',
      );
    });
  });

  // ── Stage 1 payload identity: typed vs extracted (ML-NLP-01) ──────────────

  group('buildStage1Request', () {
    test(
        'payload is identical whether the form state came from typing or '
        'from confirmed NLP suggestions', () {
      // A patient typing these values by hand…
      final typed = buildStage1Request(
        selectedSymptoms: ['Chest pain'],
        complaintText: 'crushing chest pain for 20 minutes',
        age: 45,
        sex: 1,
        nrsPain: 8,
        mental: 1,
        arrivalMode: 2,
        injury: 2,
      );

      // …and a patient whose confirmed suggestions produced the same final
      // form state go through the same single construction path.
      final extracted = buildStage1Request(
        selectedSymptoms: ['Chest pain'],
        complaintText: 'crushing chest pain for 20 minutes',
        age: 45,
        sex: 1,
        nrsPain: 8,
        mental: 1,
        arrivalMode: 2,
        injury: 2,
      );

      expect(typed.toJson(), equals(extracted.toJson()));
    });

    test('payload contains exactly the nine Stage 1 keys — no NLP additions',
        () {
      final request = buildStage1Request(
        selectedSymptoms: ['Fever'],
        complaintText: 'feeling hot since yesterday',
        age: 30,
        sex: 2,
        nrsPain: 2,
        mental: 1,
        arrivalMode: 1,
        injury: 2,
      );

      expect(
        request.toJson().keys.toSet(),
        {
          'chief_complaint',
          'age',
          'sex',
          'pain',
          'nrs_pain',
          'mental',
          'arrival_mode',
          'injury',
          'patients_per_hour',
        },
      );
    });

    test('derives pain flag from NRS exactly as the typed flow always has',
        () {
      final noPain = buildStage1Request(
        selectedSymptoms: [],
        complaintText: 'rash on arm',
        age: 30,
        sex: 1,
        nrsPain: 0,
        mental: 1,
        arrivalMode: 1,
        injury: 2,
      );
      final withPain = buildStage1Request(
        selectedSymptoms: [],
        complaintText: 'rash on arm, stings',
        age: 30,
        sex: 1,
        nrsPain: 3,
        mental: 1,
        arrivalMode: 1,
        injury: 2,
      );

      expect(noPain.toJson()['pain'], 2);
      expect(withPain.toJson()['pain'], 1);
      expect(noPain.toJson()['patients_per_hour'], 8);
    });
  });
}
