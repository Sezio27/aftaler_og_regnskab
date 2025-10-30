// test/support/intl.dart
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> initTestIntl({String locale = 'da'}) async {
  Intl.defaultLocale = locale;
  await initializeDateFormatting(locale);
}
