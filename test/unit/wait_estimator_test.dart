import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/utils/wait_estimator.dart';

void main() {
  group('WaitEstimator.serviceMinutesFor — per-patient baselines', () {
    test('Emergency baseline is 12 minutes', () {
      expect(WaitEstimator.serviceMinutesFor('EMERGENCY'), 12);
    });

    test('Urgent (MODERATE) baseline is 20 minutes', () {
      expect(WaitEstimator.serviceMinutesFor('MODERATE'), 20);
    });

    test('Non-Urgent (LOW) baseline is 25 minutes', () {
      expect(WaitEstimator.serviceMinutesFor('LOW'), 25);
    });

    test('unknown level falls back to the default 20 minutes', () {
      expect(
        WaitEstimator.serviceMinutesFor('SOMETHING_ELSE'),
        WaitEstimator.defaultServiceMinutes,
      );
      expect(WaitEstimator.defaultServiceMinutes, 20);
    });
  });

  group('WaitEstimator.baseWaitMinutes — point estimate', () {
    test('scales linearly with patients ahead in lane', () {
      expect(WaitEstimator.baseWaitMinutes('EMERGENCY', 1), 12);
      expect(WaitEstimator.baseWaitMinutes('EMERGENCY', 3), 36);
      expect(WaitEstimator.baseWaitMinutes('MODERATE', 2), 40);
      expect(WaitEstimator.baseWaitMinutes('LOW', 4), 100);
    });

    test('is zero when nobody is ahead, and never negative', () {
      expect(WaitEstimator.baseWaitMinutes('EMERGENCY', 0), 0);
      expect(WaitEstimator.baseWaitMinutes('LOW', -3), 0);
    });
  });

  group('WaitEstimator ±25% range', () {
    test('low/high straddle the point estimate at the expected spread', () {
      // 3 Non-Urgent patients ahead → base 75 min, band 56–94.
      const base = 75;
      expect(WaitEstimator.rangeLow(base), 56); // round(75 * 0.75)
      expect(WaitEstimator.rangeHigh(base), 94); // round(75 * 1.25)
      expect(WaitEstimator.rangeLow(base), lessThan(base));
      expect(WaitEstimator.rangeHigh(base), greaterThan(base));
    });

    test('for every level the range stays within floor and ceiling', () {
      for (final level in const ['EMERGENCY', 'MODERATE', 'LOW']) {
        for (var ahead = 1; ahead <= 5; ahead++) {
          final base = WaitEstimator.baseWaitMinutes(level, ahead);
          final low = WaitEstimator.rangeLow(base);
          final high = WaitEstimator.rangeHigh(base);

          final floor = (base * (1 - WaitEstimator.rangeSpread)).round();
          final ceiling = (base * (1 + WaitEstimator.rangeSpread)).round();

          expect(low, floor);
          expect(high, ceiling);
          expect(low, lessThanOrEqualTo(base));
          expect(high, greaterThanOrEqualTo(base));
        }
      }
    });
  });

  group('WaitEstimator.waitText — patient-facing string', () {
    test('shows the "next" label when no one is ahead', () {
      expect(WaitEstimator.waitText('EMERGENCY', 0), "You're next");
      expect(WaitEstimator.waitText('LOW', 0), "You're next");
    });

    test('shows a low–high minute range when patients are ahead', () {
      // 2 Urgent patients ahead → base 40 min → 30–50 min.
      expect(WaitEstimator.waitText('MODERATE', 2), '30–50 min');
    });
  });
}
