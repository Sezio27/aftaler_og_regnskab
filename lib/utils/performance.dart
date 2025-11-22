import 'package:flutter/material.dart';

class PerfTimer {
  static final Map<String, DateTime> _marks = {};

  static void start(String key) => _marks[key] = DateTime.now();

  static void stop(String key, {String label = 'first frame'}) {
    final t0 = _marks.remove(key);
    if (t0 == null) return;
    final ms = DateTime.now().difference(t0).inMilliseconds;

    debugPrint('$key → $label: ${ms}ms');
  }
}
