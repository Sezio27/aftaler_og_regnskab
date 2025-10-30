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
        .doc(segment.name); // e.g. "month", "year", "total"
  }

  /// Fetch a summary document, returning a FinanceModel with default values if missing.
  Future<FinanceModel> fetchSummary(Segment segment) async {
    final snap = await _doc(segment).get();
    if (!snap.exists) return FinanceModel();
    final data = snap.data()!;
    final totalCount = (data['totalCount'] as num?)?.toInt() ?? 0;
    final paidSum = (data['paidSum'] as num?)?.toDouble() ?? 0.0;

    // Rebuild counts keyed by PaymentStatus rather than strings.
    final rawCounts = (data['counts'] as Map<String, dynamic>? ?? {});
    final counts = <PaymentStatus, int>{
      for (final s in PaymentStatus.values)
        if (s != PaymentStatus.all)
          s: (rawCounts[s.label] as num?)?.toInt() ?? 0,
    };

    return FinanceModel(
      totalCount: totalCount,
      paidSum: paidSum,
      counts: counts,
    );
  }

  /// Helper to increment a summary based on an appointment being added.
  Future<void> updateOnAdd(PaymentStatus status, double price, DateTime date) {
    return _updateSummaries((totals) {
      totals['totalCount'] = FieldValue.increment(1);
      totals['counts.${status.label}'] = FieldValue.increment(1);
      if (status == PaymentStatus.paid) {
        totals['paidSum'] = FieldValue.increment(price);
      }
      return totals;
    }, date);
  }

  /// Helper to update a summary when only the status changes.
  Future<void> updateOnStatusChange(
    PaymentStatus oldStatus,
    PaymentStatus newStatus,
    double price,
    DateTime date,
  ) {
    return _updateSummaries((totals) {
      totals['counts.${oldStatus.label}'] = FieldValue.increment(-1);
      totals['counts.${newStatus.label}'] = FieldValue.increment(1);
      if (oldStatus == PaymentStatus.paid) {
        totals['paidSum'] = FieldValue.increment(-price);
      }
      if (newStatus == PaymentStatus.paid) {
        totals['paidSum'] = FieldValue.increment(price);
      }
      return totals;
    }, date);
  }

  /// Helper to update a summary when fields change (status, price or date).
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
          // moved OUT of segment
          updates['totalCount'] = FieldValue.increment(-1);
          updates['counts.${oldStatus.label}'] = FieldValue.increment(-1);
          if (oldStatus == PaymentStatus.paid) {
            updates['paidSum'] = FieldValue.increment(-oldPrice);
          }
        } else if (!wasIn && isIn) {
          // moved INTO segment
          updates['totalCount'] = FieldValue.increment(1);
          updates['counts.${newStatus.label}'] = FieldValue.increment(1);
          if (newStatus == PaymentStatus.paid) {
            updates['paidSum'] = FieldValue.increment(newPrice);
          }
        } else if (wasIn && isIn) {
          // stayed within segment: adjust counts/sums
          if (oldStatus != newStatus) {
            updates['counts.${oldStatus.label}'] = FieldValue.increment(-1);
            updates['counts.${newStatus.label}'] = FieldValue.increment(1);
          }
          if (oldStatus == PaymentStatus.paid &&
              newStatus == PaymentStatus.paid) {
            updates['paidSum'] = FieldValue.increment(newPrice - oldPrice);
          } else if (oldStatus == PaymentStatus.paid) {
            updates['paidSum'] = FieldValue.increment(-oldPrice);
          } else if (newStatus == PaymentStatus.paid) {
            updates['paidSum'] = FieldValue.increment(newPrice);
          }
        }
        if (updates.isNotEmpty) {
          tx.set(doc, updates, SetOptions(merge: true));
        }
      }
    });
  }

  /// Helper to decrement a summary based on a deletion.
  Future<void> updateOnDelete(
    PaymentStatus status,
    double price,
    DateTime date,
  ) {
    return _updateSummaries((totals) {
      totals['totalCount'] = FieldValue.increment(-1);
      totals['counts.${status.label}'] = FieldValue.increment(-1);
      if (status == PaymentStatus.paid) {
        totals['paidSum'] = FieldValue.increment(-price);
      }
      return totals;
    }, date);
  }

  // Internal: apply updates to all relevant summaries (total, year, month)
  Future<void> _updateSummaries(
    Map<String, Object?> Function(Map<String, Object?>) build,
    DateTime date,
  ) {
    final segments = <Segment>[Segment.total];
    final now = DateTime.now();
    if (date.year == now.year) segments.add(Segment.year);
    if (date.year == now.year && date.month == now.month)
      segments.add(Segment.month);
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
