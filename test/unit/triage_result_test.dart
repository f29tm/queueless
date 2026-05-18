import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/services/triage_service.dart';

void main() {
  // ── TriageResult.triageLevel ─────────────────────────────────────────────────

  group('TriageResult.triageLevel', () {
    test('Emergency -> EMERGENCY', () {
      final r = TriageResult(
        prediction: 'Emergency',
        confidence: 0.9,
        probabilities: {},
        deferred: false,
        entropy: 0.1,
        stage: 1,
      );
      expect(r.triageLevel, 'EMERGENCY');
    });

    test('Urgent -> MODERATE', () {
      final r = TriageResult(
        prediction: 'Urgent',
        confidence: 0.8,
        probabilities: {},
        deferred: false,
        entropy: 0.2,
        stage: 1,
      );
      expect(r.triageLevel, 'MODERATE');
    });

    test('Non-Urgent -> LOW', () {
      final r = TriageResult(
        prediction: 'Non-Urgent',
        confidence: 0.7,
        probabilities: {},
        deferred: false,
        entropy: 0.3,
        stage: 1,
      );
      expect(r.triageLevel, 'LOW');
    });

    test('unknown prediction -> LOW', () {
      final r = TriageResult(
        prediction: 'anything_else',
        confidence: 0.5,
        probabilities: {},
        deferred: false,
        entropy: 0.5,
        stage: 1,
      );
      expect(r.triageLevel, 'LOW');
    });
  });

  // ── TriageResult.priorityNumber ──────────────────────────────────────────────

  group('TriageResult.priorityNumber', () {
    test('Emergency -> 1', () {
      final r = TriageResult(
        prediction: 'Emergency',
        confidence: 0.9,
        probabilities: {},
        deferred: false,
        entropy: 0.1,
        stage: 1,
      );
      expect(r.priorityNumber, 1);
    });

    test('Urgent -> 2', () {
      final r = TriageResult(
        prediction: 'Urgent',
        confidence: 0.8,
        probabilities: {},
        deferred: false,
        entropy: 0.2,
        stage: 1,
      );
      expect(r.priorityNumber, 2);
    });

    test('Non-Urgent -> 3', () {
      final r = TriageResult(
        prediction: 'Non-Urgent',
        confidence: 0.7,
        probabilities: {},
        deferred: false,
        entropy: 0.3,
        stage: 1,
      );
      expect(r.priorityNumber, 3);
    });
  });

  // ── TriageResult.toFirestore ─────────────────────────────────────────────────

  group('TriageResult.toFirestore', () {
    final result = TriageResult(
      prediction: 'Emergency',
      confidence: 0.941,
      probabilities: {
        'Emergency': 0.941,
        'Urgent': 0.056,
        'Non-Urgent': 0.003,
      },
      deferred: false,
      entropy: 0.23,
      stage: 1,
    );

    test('contains all required keys', () {
      final map = result.toFirestore();
      expect(map.containsKey('aiPrediction'), isTrue);
      expect(map.containsKey('confidence'), isTrue);
      expect(map.containsKey('probabilities'), isTrue);
      expect(map.containsKey('deferred'), isTrue);
      expect(map.containsKey('entropy'), isTrue);
      expect(map.containsKey('triageLevel'), isTrue);
      expect(map.containsKey('priorityNumber'), isTrue);
    });

    test('Emergency prediction maps triageLevel=EMERGENCY, priorityNumber=1', () {
      final map = result.toFirestore();
      expect(map['triageLevel'], 'EMERGENCY');
      expect(map['priorityNumber'], 1);
    });
  });

  // ── TriageResult.error ───────────────────────────────────────────────────────

  group('TriageResult.error', () {
    test('isError=true, errorMessage set, prediction is empty string', () {
      final r = TriageResult.error('network failure');
      expect(r.isError, isTrue);
      expect(r.errorMessage, 'network failure');
      expect(r.prediction, '');
    });
  });

  // ── Stage1Request.toJson ─────────────────────────────────────────────────────

  group('Stage1Request.toJson', () {
    const request = Stage1Request(
      chiefComplaint: 'chest pain radiating to left arm',
      age: 45,
      sex: 1,
      pain: 1,
      nrsPain: 8.0,
      mental: 1,
      arrivalMode: 1,
      injury: 2,
      patientsPerHour: 8,
    );

    test('contains all 9 required keys', () {
      final json = request.toJson();
      expect(json.containsKey('chief_complaint'), isTrue);
      expect(json.containsKey('age'), isTrue);
      expect(json.containsKey('sex'), isTrue);
      expect(json.containsKey('pain'), isTrue);
      expect(json.containsKey('nrs_pain'), isTrue);
      expect(json.containsKey('mental'), isTrue);
      expect(json.containsKey('arrival_mode'), isTrue);
      expect(json.containsKey('injury'), isTrue);
      expect(json.containsKey('patients_per_hour'), isTrue);
    });

    test('chief_complaint equals chiefComplaint field value', () {
      expect(request.toJson()['chief_complaint'], 'chest pain radiating to left arm');
    });

    test('nrs_pain equals nrsPain field as double', () {
      final val = request.toJson()['nrs_pain'];
      expect(val, 8.0);
      expect(val, isA<double>());
    });
  });

  // ── Stage2Request.toJson ─────────────────────────────────────────────────────

  group('Stage2Request.toJson', () {
    const stage1 = Stage1Request(
      chiefComplaint: 'headache',
      age: 30,
      sex: 2,
      pain: 1,
      nrsPain: 5.0,
      mental: 1,
      arrivalMode: 1,
      injury: 2,
      patientsPerHour: 8,
    );

    const request = Stage2Request(
      stage1: stage1,
      sbp: 120.0,
      dbp: 80.0,
      hr: 72.0,
      rr: 16.0,
      bt: 37.0,
      saturation: 98.0,
      ktasRn: 3,
    );

    test('contains all 16 keys (9 Stage1 + 7 vitals)', () {
      final json = request.toJson();
      // Stage 1 keys
      expect(json.containsKey('chief_complaint'), isTrue);
      expect(json.containsKey('age'), isTrue);
      expect(json.containsKey('sex'), isTrue);
      expect(json.containsKey('pain'), isTrue);
      expect(json.containsKey('nrs_pain'), isTrue);
      expect(json.containsKey('mental'), isTrue);
      expect(json.containsKey('arrival_mode'), isTrue);
      expect(json.containsKey('injury'), isTrue);
      expect(json.containsKey('patients_per_hour'), isTrue);
      // Stage 2 vitals keys
      expect(json.containsKey('sbp'), isTrue);
      expect(json.containsKey('dbp'), isTrue);
      expect(json.containsKey('hr'), isTrue);
      expect(json.containsKey('rr'), isTrue);
      expect(json.containsKey('bt'), isTrue);
      expect(json.containsKey('saturation'), isTrue);
      expect(json.containsKey('ktas_rn'), isTrue);
      expect(json.length, 16);
    });

    test('Stage1 fields are spread to top level, not nested', () {
      final json = request.toJson();
      expect(json['chief_complaint'], 'headache');
      expect(json.containsKey('stage1'), isFalse);
    });
  });
}
