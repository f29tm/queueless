import 'package:cloud_firestore/cloud_firestore.dart';

import 'triage_levels.dart';
import 'wait_estimator.dart';

/// THE canonical ordering of the nurse waiting lane.
///
/// Every surface that ranks waiting patients — the position fan-out, the
/// nurse dashboard's priority sort, the staff dashboard list — must use this
/// comparator, or the "#N" a patient sees will disagree with the "#N" a nurse
/// sees. The rule, per the clinical flow:
///
///   Emergency (1) → Urgent (2) → Non-Urgent (3) → Manual / unassessed (4)
///
/// ties broken by `createdAt` ascending (first come, first served). Manual
/// check-ins carry `triageLevel: 'PENDING'` and rank last regardless of any
/// stored `priorityNumber`, because nobody has assessed their acuity yet.
class LaneOrder {
  LaneOrder._();

  /// Rank of one queue doc in the lane (lower = seen sooner).
  static int rank(Map<String, dynamic> data) {
    final level = data['triageLevel'] as String?;
    if (level == TriageLevels.emergency ||
        level == TriageLevels.moderate ||
        level == TriageLevels.low) {
      return TriageLevels.priorityOf(level!);
    }
    if (level == null) {
      // No level at all — trust an explicit priorityNumber if present.
      return (data['priorityNumber'] as num?)?.toInt() ?? 4;
    }
    return 4; // PENDING / unknown — assessed after every AI-triaged patient.
  }

  /// Canonical comparator: rank ASC, then createdAt ASC. Docs whose
  /// `createdAt` server timestamp hasn't resolved yet sort last within their
  /// rank — a brand-new arrival never jumps ahead of an equal-priority peer.
  static int compare(Map<String, dynamic> a, Map<String, dynamic> b) {
    final ra = rank(a);
    final rb = rank(b);
    if (ra != rb) return ra.compareTo(rb);
    final ta = a['createdAt'];
    final tb = b['createdAt'];
    final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 1 << 62;
    final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 1 << 62;
    return ma.compareTo(mb);
  }

  /// Cumulative point-estimate waits (minutes) for an already-sorted lane.
  ///
  /// Position 1 is being seen now (wait 0); each patient behind waits for the
  /// actual service time of every patient ahead of them — so an Emergency
  /// ahead of you costs 12 min and a Non-Urgent costs 25, instead of pricing
  /// everyone at your own level's rate.
  static List<int> expectedWaits(List<Map<String, dynamic>> sortedLane) {
    final waits = List<int>.filled(sortedLane.length, 0);
    var cumulative = 0;
    for (var i = 0; i < sortedLane.length; i++) {
      waits[i] = cumulative;
      final level = (sortedLane[i]['triageLevel'] as String?) ?? '';
      cumulative += WaitEstimator.serviceMinutesFor(level);
    }
    return waits;
  }
}
