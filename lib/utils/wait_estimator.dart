/// Pure wait-time estimation for the accumulative priority queue (APQ).
///
/// Extracted from `ArrivalCheckInScreen` so the math can be unit-tested
/// independently of Firestore and the widget tree. No I/O, no state — given
/// a triage level and the number of same-or-higher-priority patients ahead in
/// the lane, it returns the point estimate and the patient-facing range text.
///
/// Constants are derived from published KTAS/CTAS/ESI time-to-be-seen targets,
/// cross-checked against the project dataset's median ED length-of-stay per
/// acuity level. They are in-lane *service* estimates, NOT raw LOS.
class WaitEstimator {
  WaitEstimator._();

  /// Per-patient in-lane service time (minutes), keyed by Firestore triage
  /// level. EMERGENCY < MODERATE < LOW preserves the acuity gradient.
  static const Map<String, int> serviceMinutes = {
    'EMERGENCY': 12,
    'MODERATE': 20,
    'LOW': 25,
  };

  /// Fallback service time used when the level is unknown/unmapped.
  static const int defaultServiceMinutes = 20;

  /// Half-width of the displayed range, as a fraction of the point estimate
  /// (i.e. the band is `base ± 25%`).
  static const double rangeSpread = 0.25;

  /// Service minutes for a single patient at [level].
  static int serviceMinutesFor(String level) =>
      serviceMinutes[level] ?? defaultServiceMinutes;

  /// Point-estimate wait in minutes for [patientsAheadInLane] patients at
  /// [level]. Negative counts are treated as zero.
  static int baseWaitMinutes(String level, int patientsAheadInLane) {
    if (patientsAheadInLane <= 0) return 0;
    return patientsAheadInLane * serviceMinutesFor(level);
  }

  /// Low end (floor) of the displayed range for a given point estimate.
  static int rangeLow(int baseWait) => (baseWait * (1 - rangeSpread)).round();

  /// High end (ceiling) of the displayed range for a given point estimate.
  static int rangeHigh(int baseWait) => (baseWait * (1 + rangeSpread)).round();

  /// Patient-facing wait text. Returns [nextLabel] when nobody is ahead;
  /// otherwise a `"low–high min"` range around the point estimate.
  static String waitText(
    String level,
    int patientsAheadInLane, {
    String nextLabel = "You're next",
  }) {
    if (patientsAheadInLane <= 0) return nextLabel;
    final base = baseWaitMinutes(level, patientsAheadInLane);
    return "${rangeLow(base)}–${rangeHigh(base)} min";
  }
}
