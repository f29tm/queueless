import 'package:cloud_firestore/cloud_firestore.dart';
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

    testWidgets('no active doc renders nothing (SizedBox.shrink)', (
      tester,
    ) async {
      await tester.pumpWidget(_host(<String, dynamic>{}));
      expect(find.byKey(const Key('queueStatusCard')), findsNothing);
    });
  });

  group('QueueStatusCard — waiting_nurse position fallback', () {
    testWidgets(
      'shows a spinner first, then a calm checked-in fallback if no position '
      'lands within the timeout',
      (tester) async {
        await tester.pumpWidget(
          _host({
            'status': 'waiting_nurse',
            'queueNumber': 'Q12345',
            'triageLevel': 'LOW',
            // No currentPosition — fan-out hasn't run.
          }),
        );

        // Initially the "calculating" spinner.
        expect(
          find.textContaining('Calculating your position'),
          findsOneWidget,
        );

        // After the fallback delay it never keeps spinning.
        await tester.pump(const Duration(seconds: 4));
        expect(find.textContaining('Calculating your position'), findsNothing);
        expect(find.textContaining('checked in'), findsOneWidget);
        // Queue number is still shown the whole time.
        expect(find.text('Q12345'), findsOneWidget);
      },
    );

    testWidgets('no fallback when the position is already present', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host({
          'status': 'waiting_nurse',
          'queueNumber': 'Q12345',
          'triageLevel': 'LOW',
          'currentPosition': 4,
        }),
      );
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('#4'), findsOneWidget);
      expect(find.textContaining('checked in'), findsNothing);
    });
  });

  group('QueueStatusCard — waiting_doctor handoff confirmation', () {
    testWidgets(
      'fresh handoff shows the assessment-complete confirmation with a '
      'completion time and a dismiss control',
      (tester) async {
        await tester.pumpWidget(
          _host({
            'status': 'waiting_doctor',
            'triageCompletedAt': Timestamp.fromDate(DateTime.now()),
          }),
        );

        expect(find.text('Nurse assessment complete'), findsOneWidget);
        expect(find.textContaining('Completed at'), findsOneWidget);
        expect(find.byKey(const Key('handoffDismiss')), findsOneWidget);

        // Unmount to cancel the auto-collapse timer cleanly.
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('stale handoff (older than the window) collapses to nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host({
          'status': 'waiting_doctor',
          'triageCompletedAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        }),
      );
      expect(find.byKey(const Key('queueStatusCard')), findsNothing);
      expect(find.text('Nurse assessment complete'), findsNothing);
    });

    testWidgets('tapping ✕ collapses the handoff confirmation immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host({
          'status': 'waiting_doctor',
          'triageCompletedAt': Timestamp.fromDate(DateTime.now()),
        }),
      );
      expect(find.byKey(const Key('queueStatusCard')), findsOneWidget);

      await tester.tap(find.byKey(const Key('handoffDismiss')));
      await tester.pump();

      expect(find.byKey(const Key('queueStatusCard')), findsNothing);
    });

    testWidgets('missing timestamp still shows the confirmation (defensive)', (
      tester,
    ) async {
      await tester.pumpWidget(_host({'status': 'waiting_doctor'}));
      expect(find.text('Nurse assessment complete'), findsOneWidget);
    });
  });
}
