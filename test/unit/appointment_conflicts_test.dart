import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/utils/appointment_conflicts.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<void> seed({
    required String patientId,
    required String doctorName,
    required String date,
    required String time,
    String status = 'scheduled',
  }) {
    return db.collection('appointments').add({
      'patientId': patientId,
      'doctorName': doctorName,
      'doctorUid': 'uid-$doctorName',
      'date': date,
      'time': time,
      'status': status,
    });
  }

  group('AppointmentConflicts.findPatientClash', () {
    test('finds the patient\'s booking at the same date+time with a '
        'different doctor', () async {
      await seed(
        patientId: 'p1',
        doctorName: 'Dr. Salem',
        date: 'Thu, Jun 18',
        time: '09:00 AM',
      );

      final clash = await AppointmentConflicts.findPatientClash(
        db,
        patientId: 'p1',
        date: 'Thu, Jun 18',
        time: '09:00 AM',
      );

      expect(clash, isNotNull);
      expect(clash!.data()['doctorName'], 'Dr. Salem');
    });

    test(
      'returns null when the existing booking is at a different time',
      () async {
        await seed(
          patientId: 'p1',
          doctorName: 'Dr. Salem',
          date: 'Thu, Jun 18',
          time: '09:00 AM',
        );

        final clash = await AppointmentConflicts.findPatientClash(
          db,
          patientId: 'p1',
          date: 'Thu, Jun 18',
          time: '11:00 AM',
        );

        expect(clash, isNull);
      },
    );

    test(
      'returns null when the existing booking is on a different date',
      () async {
        await seed(
          patientId: 'p1',
          doctorName: 'Dr. Salem',
          date: 'Thu, Jun 18',
          time: '09:00 AM',
        );

        final clash = await AppointmentConflicts.findPatientClash(
          db,
          patientId: 'p1',
          date: 'Fri, Jun 19',
          time: '09:00 AM',
        );

        expect(clash, isNull);
      },
    );

    test('ignores cancelled and completed appointments', () async {
      await seed(
        patientId: 'p1',
        doctorName: 'Dr. Salem',
        date: 'Thu, Jun 18',
        time: '09:00 AM',
        status: 'cancelled',
      );
      await seed(
        patientId: 'p1',
        doctorName: 'Dr. Noor',
        date: 'Thu, Jun 18',
        time: '09:00 AM',
        status: 'completed',
      );

      final clash = await AppointmentConflicts.findPatientClash(
        db,
        patientId: 'p1',
        date: 'Thu, Jun 18',
        time: '09:00 AM',
      );

      expect(clash, isNull);
    });

    test('ignores other patients\' appointments at the same slot', () async {
      await seed(
        patientId: 'someone-else',
        doctorName: 'Dr. Salem',
        date: 'Thu, Jun 18',
        time: '09:00 AM',
      );

      final clash = await AppointmentConflicts.findPatientClash(
        db,
        patientId: 'p1',
        date: 'Thu, Jun 18',
        time: '09:00 AM',
      );

      expect(clash, isNull);
    });
  });
}
