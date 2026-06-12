import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/widgets/arrival_time_label.dart';

void main() {
  group('ArrivalTimeLabel — arrival timestamp on the patient card', () {
    testWidgets('shows 24h HH:mm for a Timestamp arriving today',
        (tester) async {
      final now = DateTime.now();
      final today1032 = DateTime(now.year, now.month, now.day, 10, 32);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ArrivalTimeLabel(
            arrivedAt: Timestamp.fromDate(today1032),
          ),
        ),
      ));
      expect(find.text('10:32'), findsOneWidget);
    });

    testWidgets('renders nothing when arrivedAt is null', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ArrivalTimeLabel(arrivedAt: null)),
      ));
      // No timestamp text — an empty shrink instead.
      expect(find.byType(Text), findsNothing);
    });
  });
}
