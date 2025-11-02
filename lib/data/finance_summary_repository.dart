import 'package:aftaler_og_regnskab/model/finance_model.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FinanceSummaryRepository {
  FinanceSummaryRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String get _uidOrThrow {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _doc(Segment segment) {
    final uid = _uidOrThrow;
    return _db
        .collection('users')
        .doc(uid)
        .collection('finance_summary')
        .doc(segment.name);
  }

  Future<FinanceModel> fetchSummary(Segment segment) async {
    final snap = await _doc(segment).get();
    if (!snap.exists) return FinanceModel();
    final data = snap.data()!;
    final totalCount = (data['Aftaler'] as num?)?.toInt() ?? 0;
    final paidSum = (data['Total'] as num?)?.toDouble() ?? 0.0;

    final counts = <PaymentStatus, int>{
      for (final s in PaymentStatus.values)
        if (s != PaymentStatus.all) s: (data[s.label] as num?)?.toInt() ?? 0,
    };

    return FinanceModel(
      totalCount: totalCount,
      paidSum: paidSum,
      counts: counts,
    );
  }

  Future<void> updateOnAdd(PaymentStatus status, double price, DateTime date) {
    return _updateSummaries((totals) {
      totals['Aftaler'] = FieldValue.increment(1);
      totals[status.label] = FieldValue.increment(1);
      if (status == PaymentStatus.paid) {
        totals['Total'] = FieldValue.increment(price);
      }
      return totals;
    }, date);
  }

  Future<void> updateOnStatusChange(
    PaymentStatus oldStatus,
    PaymentStatus newStatus,
    double price,
    DateTime date,
  ) {
    return _updateSummaries((totals) {
      totals[oldStatus.label] = FieldValue.increment(-1);
      totals[newStatus.label] = FieldValue.increment(1);
      if (oldStatus == PaymentStatus.paid) {
        totals['Total'] = FieldValue.increment(-price);
      }
      if (newStatus == PaymentStatus.paid) {
        totals['Total'] = FieldValue.increment(price);
      }
      return totals;
    }, date);
  }

  Future<void> updateOnFields(
    PaymentStatus oldStatus,
    PaymentStatus newStatus,
    double oldPrice,
    double newPrice,
    DateTime? oldDate,
    DateTime? newDate,
  ) {
    return _db.runTransaction((tx) async {
      for (final seg in Segment.values) {
        final doc = _doc(seg);
        final wasIn = _inSegment(seg, oldDate);
        final isIn = _inSegment(seg, newDate);
        final updates = <String, Object?>{};
        if (wasIn && !isIn) {
          updates['Aftaler'] = FieldValue.increment(-1);
          updates[oldStatus.label] = FieldValue.increment(-1);
          if (oldStatus == PaymentStatus.paid) {
            updates['Total'] = FieldValue.increment(-oldPrice);
          }
        } else if (!wasIn && isIn) {
          updates['Aftaler'] = FieldValue.increment(1);
          updates[newStatus.label] = FieldValue.increment(1);
          if (newStatus == PaymentStatus.paid) {
            updates['Total'] = FieldValue.increment(newPrice);
          }
        } else if (wasIn && isIn) {
          if (oldStatus != newStatus) {
            updates[oldStatus.label] = FieldValue.increment(-1);
            updates[newStatus.label] = FieldValue.increment(1);
          }
          if (oldStatus == PaymentStatus.paid &&
              newStatus == PaymentStatus.paid) {
            updates['Total'] = FieldValue.increment(newPrice - oldPrice);
          } else if (oldStatus == PaymentStatus.paid) {
            updates['Total'] = FieldValue.increment(-oldPrice);
          } else if (newStatus == PaymentStatus.paid) {
            updates['Total'] = FieldValue.increment(newPrice);
          }
        }
        if (updates.isNotEmpty) {
          tx.set(doc, updates, SetOptions(merge: true));
        }
      }
    });
  }

  Future<void> updateOnDelete(
    PaymentStatus status,
    double price,
    DateTime date,
  ) {
    return _updateSummaries((totals) {
      totals['Aftaler'] = FieldValue.increment(-1);
      totals[status.label] = FieldValue.increment(-1);
      if (status == PaymentStatus.paid) {
        totals['Total'] = FieldValue.increment(-price);
      }
      return totals;
    }, date);
  }

  Future<void> _updateSummaries(
    Map<String, Object?> Function(Map<String, Object?>) build,
    DateTime date,
  ) {
    final segments = <Segment>[Segment.total];
    final now = DateTime.now();
    if (date.year == now.year) segments.add(Segment.year);
    if (date.year == now.year && date.month == now.month) {
      segments.add(Segment.month);
    }
    return _db.runTransaction((tx) async {
      for (final seg in segments) {
        final doc = _doc(seg);
        final updates = build(<String, Object?>{});
        tx.set(doc, updates, SetOptions(merge: true));
      }
    });
  }

  bool _inSegment(Segment seg, DateTime? dt) {
    if (seg == Segment.total) return true;
    if (dt == null) return false;
    final now = DateTime.now();
    if (seg == Segment.year) return dt.year == now.year;
    return dt.year == now.year && dt.month == now.month;
  }
}
