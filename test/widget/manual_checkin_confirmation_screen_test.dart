import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/screens/patient/manual_checkin_confirmation_screen.dart';

Widget _buildWithArgs(Object? arguments) {
  return MaterialApp(
    home: Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: RouteSettings(arguments: arguments),
        builder: (_) => const ManualCheckinConfirmationScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('shows queue number Q123456789', (tester) async {
    await tester.pumpWidget(_buildWithArgs({'queueNumber': 'Q123456789'}));
    await tester.pumpAndSettle();
    expect(find.text('Q123456789'), findsOneWidget);
  });

  testWidgets('shows "—" placeholder when queueNumber is missing', (
    tester,
  ) async {
    await tester.pumpWidget(_buildWithArgs(<dynamic, dynamic>{}));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('AppBar title shows "You\'re Registered"', (tester) async {
    await tester.pumpWidget(_buildWithArgs({'queueNumber': 'Q123'}));
    await tester.pumpAndSettle();
    expect(find.text("You're Registered"), findsOneWidget);
  });

  testWidgets('"Got it — Go Home" CTA button is found', (tester) async {
    await tester.pumpWidget(_buildWithArgs({'queueNumber': 'Q123'}));
    await tester.pumpAndSettle();
    expect(find.text('Got it — Go Home'), findsOneWidget);
  });
}
