import 'package:flutter/foundation.dart';

class Bench {
  // Firestore “reads” (approx. = docs delivered from server)
  int pagedReads = 0; // from .get() for non-live months
  int liveFirstReads = 0; // first snapshot docs for listeners
  int liveUpdateReads = 0; // subsequent changed docs from listeners

  // UI rebuilds
  int allAppointmentsBuilds = 0;

  void log(String label) {
    if (!kDebugMode) return;
    debugPrint('--- BENCH: $label ---');
    debugPrint(
      'Reads: paged=$pagedReads liveFirst=$liveFirstReads liveUpdate=$liveUpdateReads total=${pagedReads + liveFirstReads + liveUpdateReads}',
    );
    debugPrint('Rebuilds: AllAppointments.build=$allAppointmentsBuilds');
  }
}

// Set this from main() (debug only)
Bench? bench;
