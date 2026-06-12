import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:queueless/services/triage_service.dart';

/// A minimal, valid Stage 1 request reused across the error cases — the
/// payload itself is irrelevant here; we only exercise the HTTP failure paths.
const _request = Stage1Request(
  chiefComplaint: 'chest pain',
  age: 45,
  sex: 1,
  pain: 1,
  nrsPain: 8.0,
  mental: 1,
  arrivalMode: 1,
  injury: 2,
  patientsPerHour: 8,
);

/// Runs [TriageService.predictStage1] with the global http client swapped for
/// [client] for the duration of the call. `runWithClient` (package:http) lets
/// us inject a MockClient without changing TriageService's static API.
Future<TriageResult> _runWith(MockClient client) {
  return http.runWithClient(
    () => TriageService.predictStage1(_request),
    () => client,
  );
}

void main() {
  group('TriageService HTTP error handling', () {
    test('500 response surfaces an error with the status code', () async {
      final client = MockClient((_) async => http.Response('boom', 500));

      final result = await _runWith(client);

      expect(result.isError, isTrue);
      expect(result.prediction, isEmpty);
      expect(result.errorMessage, contains('500'));
    });

    test('TimeoutException surfaces an error rather than throwing', () async {
      // Never completes within the request — the service's .timeout() fires.
      final client = MockClient((_) async {
        throw TimeoutException('request timed out');
      });

      final result = await _runWith(client);

      expect(result.isError, isTrue);
      expect(result.prediction, isEmpty);
      expect(result.errorMessage, isNotNull);
      expect(result.errorMessage, contains('TimeoutException'));
    });

    test('malformed JSON body surfaces an error, not an exception', () async {
      // HTTP 200 but the body is not the JSON object the parser expects.
      final client = MockClient(
        (_) async => http.Response('this is not json', 200),
      );

      final result = await _runWith(client);

      expect(result.isError, isTrue);
      expect(result.prediction, isEmpty);
      expect(result.errorMessage, isNotNull);
    });
  });
}
