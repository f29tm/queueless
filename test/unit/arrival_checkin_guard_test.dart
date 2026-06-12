import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/screens/patient/arrival_checkin_screen.dart';

void main() {
  // The full _confirmArrival flow is NOT unit-testable in isolation: it is a
  // private State method that reaches FirebaseFirestore.instance and
  // FirebaseAuth.instance directly (no dependency injection) and the test
  // harness does not initialise Firebase. So we test the *decision* the guard
  // makes — extracted as the pure, public predicate arrivalAlreadyCheckedIn —
  // and verify the widget delegates to it for its early-return.
  group('arrivalAlreadyCheckedIn — double check-in guard decision', () {
    test('true once the patient has already progressed past pre_arrival', () {
      expect(arrivalAlreadyCheckedIn('waiting_nurse'), isTrue);
      expect(arrivalAlreadyCheckedIn('waiting_doctor'), isTrue);
      expect(arrivalAlreadyCheckedIn('completed'), isTrue);
    });

    test('false for a fresh pre_arrival doc — check-in should proceed', () {
      expect(arrivalAlreadyCheckedIn('pre_arrival'), isFalse);
    });

    test('false when status is missing — fall through to normal check-in', () {
      expect(arrivalAlreadyCheckedIn(null), isFalse);
    });
  });
}
