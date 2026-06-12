import 'package:cloud_firestore/cloud_firestore.dart';

import 'lane_order.dart';

/// Pure, Firebase-free sort/filter helpers for the nurse queue list.
///
/// All methods are non-mutating: they copy before sorting so the caller's
/// snapshot list is never reordered in place. Kept out of the widget so the
/// ordering/filtering rules can be unit-tested directly.
class NurseQueueFilter {
  NurseQueueFilter._();

  /// Filter value used by the "Manual" chip — manual check-ins have no AI
  /// triage rather than a distinct triageLevel.
  static const String manual = 'MANUAL';

  static Map<String, dynamic> _data(QueryDocumentSnapshot<Object?> doc) =>
      (doc.data() as Map<String, dynamic>?) ?? const {};

  /// Keep only docs matching [level]. `null` → no filter (all docs).
  /// [manual] → only manual check-ins; otherwise an exact `triageLevel` match.
  static List<QueryDocumentSnapshot<Object?>> filterByLevel(
    List<QueryDocumentSnapshot<Object?>> docs,
    String? level,
  ) {
    if (level == null) return List.of(docs);
    if (level == manual) {
      return docs.where((d) => _data(d)['noAITriage'] == true).toList();
    }
    return docs.where((d) => _data(d)['triageLevel'] == level).toList();
  }

  /// Order by `arrivedAt` ascending (earliest arrival / longest wait first).
  /// Docs without a timestamp sort last.
  static List<QueryDocumentSnapshot<Object?>> sortByArrival(
    List<QueryDocumentSnapshot<Object?>> docs,
  ) {
    final list = List.of(docs);
    list.sort((a, b) {
      final ta = _data(a)['arrivedAt'];
      final tb = _data(b)['arrivedAt'];
      final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 1 << 62;
      final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 1 << 62;
      return ma.compareTo(mb);
    });
    return list;
  }

  /// Canonical lane order: Emergency → Urgent → Non-Urgent → Manual, ties by
  /// arrival. Delegates to [LaneOrder] so the list a nurse sees ranks
  /// patients exactly like the positions fanned out to patient phones.
  static List<QueryDocumentSnapshot<Object?>> sortByPriority(
    List<QueryDocumentSnapshot<Object?>> docs,
  ) {
    final list = List.of(docs);
    list.sort((a, b) => LaneOrder.compare(_data(a), _data(b)));
    return list;
  }

  /// Order by `estimatedWaitMinutes` descending (longest estimated wait first).
  /// Missing values are treated as 0.
  static List<QueryDocumentSnapshot<Object?>> sortByWaitTime(
    List<QueryDocumentSnapshot<Object?>> docs,
  ) {
    final list = List.of(docs);
    list.sort((a, b) {
      final wa = (_data(a)['estimatedWaitMinutes'] as num?) ?? 0;
      final wb = (_data(b)['estimatedWaitMinutes'] as num?) ?? 0;
      return wb.compareTo(wa);
    });
    return list;
  }
}
