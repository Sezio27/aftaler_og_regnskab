// test/test_config.dart
import 'dart:async';
import 'package:intl/date_symbol_data_local.dart';

/// Runs before every test file's `main()`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Make DateFormat('da') work in tests that render dates.
  await initializeDateFormatting('da');

  // If you ever need to tweak global Provider checks, you could do it here.
  // Provider.debugCheckInvalidValueType = null;

  await testMain();
}
