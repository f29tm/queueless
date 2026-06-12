import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/utils/discharge_constants.dart';

void main() {
  group('Discharge (LWBS) constants', () {
    test('dischargeStatus is the LWBS status code', () {
      expect(dischargeStatus(), 'left_without_being_seen');
    });

    test('dischargeReason is the human-readable LWBS reason', () {
      expect(dischargeReason(), 'Patient left without being seen');
    });
  });
}
