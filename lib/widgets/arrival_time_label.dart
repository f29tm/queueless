import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Formats a queue doc's `arrivedAt` for display on a nurse card.
///
/// Same calendar day → 24h clock time ("10:32"); an earlier day → date + time
/// ("Mar 4, 10:32"). Returns an empty string when there is no timestamp.
/// [now] is injectable for deterministic tests.
String formatArrivalTime(Timestamp? arrivedAt, {DateTime? now}) {
  if (arrivedAt == null) return '';
  final dt = arrivedAt.toDate();
  final ref = now ?? DateTime.now();
  final isToday =
      dt.year == ref.year && dt.month == ref.month && dt.day == ref.day;
  return isToday
      ? DateFormat('HH:mm').format(dt)
      : DateFormat('MMM d, HH:mm').format(dt);
}

/// Small grey arrival-time stamp shown in the top-right of a nurse patient card.
/// Renders nothing (a zero-size box) when there is no arrival timestamp.
class ArrivalTimeLabel extends StatelessWidget {
  final Timestamp? arrivedAt;

  const ArrivalTimeLabel({super.key, required this.arrivedAt});

  @override
  Widget build(BuildContext context) {
    final label = formatArrivalTime(arrivedAt);
    if (label.isEmpty) return const SizedBox.shrink();
    return Text(
      label,
      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
    );
  }
}
