// lib/utils/perf.dart
import 'dart:developer' as dev;

class Performance {
  static T run<T>(String name, T Function() fn) {
    dev.Timeline.startSync(name);
    try {
      return fn();
    } finally {
      dev.Timeline.finishSync();
    }
  }

  static Future<T> runAsync<T>(String name, Future<T> Function() body) async {
    final task = dev.TimelineTask(); // spans across awaits
    task.start(name);
    try {
      return await body();
    } finally {
      task.finish();
    }
  }

  static void mark(String name) => dev.Timeline.instantSync(name);
}
