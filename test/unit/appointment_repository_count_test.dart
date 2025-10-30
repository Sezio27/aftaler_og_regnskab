import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _seed(
  FakeFirebaseFirestore db,
  String uid,
  List<Map<String, dynamic>> docs,
) async {
  final col = db.collection('users/$uid/appointments');
  for (final d in docs) {
    await col.add(d);
  }
}

void main() {
  test('countAppointments returns 0 / 1 / 2 with seeded ranges', () async {
    final uid = 'u1';
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid));
    final db = FakeFirebaseFirestore();
    final repo = AppointmentRepository(auth: auth, firestore: db);

    // Seed nothing: expect 0
    await _seed(db, uid, []);
    var n = await repo.countAppointments(
      startInclusive: DateTime(2025, 1, 1),
      endInclusive: DateTime(2025, 1, 31),
    );
    expect(n, 0);

    // Seed one doc in range
    await _seed(db, uid, [
      {
        'dateTime': Timestamp.fromDate(DateTime(2025, 1, 10, 12)),
        'status': 'Betalt',
      },
    ]);
    n = await repo.countAppointments(
      startInclusive: DateTime(2025, 1, 1),
      endInclusive: DateTime(2025, 1, 31),
    );
    expect(n, 1);

    // Seed another in range → expect 2
    await _seed(db, uid, [
      {
        'dateTime': Timestamp.fromDate(DateTime(2025, 1, 15, 9)),
        'status': 'Betalt',
      },
    ]);
    n = await repo.countAppointments(
      startInclusive: DateTime(2025, 1, 1),
      endInclusive: DateTime(2025, 1, 31),
    );
    expect(n, 2);

    // Seed one outside range → still 2
    await _seed(db, uid, [
      {
        'dateTime': Timestamp.fromDate(DateTime(2025, 2, 1, 0)),
        'status': 'Betalt',
      },
    ]);
    n = await repo.countAppointments(
      startInclusive: DateTime(2025, 1, 1),
      endInclusive: DateTime(2025, 1, 31),
    );
    expect(n, 2);

    // Filter by status
    n = await repo.countAppointments(
      startInclusive: DateTime(2025, 1, 1),
      endInclusive: DateTime(2025, 1, 31),
      status: 'Afventer',
    );
    expect(n, 0);
  });
}
