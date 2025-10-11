// lib/utils/perf_timer.dart
class PerfTimer {
  static final Map<String, DateTime> _marks = {};

  static void start(String key) => _marks[key] = DateTime.now();

  static void stop(String key, {String label = 'first frame'}) {
    final t0 = _marks.remove(key);
    if (t0 == null) return; // safe if start wasn't called
    final ms = DateTime.now().difference(t0).inMilliseconds;
    // ignore: avoid_print
    print('$key → $label: ${ms}ms');
  }
}
