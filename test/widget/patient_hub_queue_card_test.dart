import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/screens/patient/queue_status_card.dart';

Widget _host(Map<String, dynamic> data) {
  return MaterialApp(
    home: Scaffold(
      body: QueueStatusCard(data: data, isArabic: false, onCheckIn: () {}),
    ),
  );
}

void main() {
  group('QueueStatusCard — per-status rendering', () {
    testWidgets('pre_arrival shows the "Check In Now" call to action', (
      tester,
    ) async {
      await tester.pumpWidget(_host({'status': 'pre_arrival'}));
      expect(find.text('Check In Now'), findsOneWidget);
    });

    testWidgets('waiting_nurse at position 1 shows "Being seen now"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host({
          'status': 'waiting_nurse',
          'queueNumber': 'Q12345',
          'triageLevel': 'MODERATE',
          'currentPosition': 1,
        }),
      );
      expect(find.text('Being seen now'), findsOneWidget);
    });

    testWidgets('waiting_nurse at position 2 shows the "You\'re next" prompt', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host({
          'status': 'waiting_nurse',
          'queueNumber': 'Q12345',
          'triageLevel': 'MODERATE',
          'currentPosition': 2,
        }),
      );
      expect(find.textContaining("You're next"), findsOneWidget);
    });

    testWidgets('waiting_doctor shows the assessment-complete message', (
      tester,
    ) async {
      await tester.pumpWidget(_host({'status': 'waiting_doctor'}));
      expect(find.text('Nurse assessment complete'), findsOneWidget);
    });

    testWidgets('no active doc renders nothing (SizedBox.shrink)', (
      tester,
    ) async {
      await tester.pumpWidget(_host(<String, dynamic>{}));
      expect(find.byKey(const Key('queueStatusCard')), findsNothing);
    });
  });
}
