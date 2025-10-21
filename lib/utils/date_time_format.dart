import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String daDate(DateTime dt) {
  final weekday = toBeginningOfSentenceCase(DateFormat.EEEE('da').format(dt));
  final day = DateFormat('d', 'da').format(dt);
  final month = toBeginningOfSentenceCase(DateFormat.MMMM('da').format(dt));
  return '$weekday den $day $month';
}

String daTimeOfDay(TimeOfDay t) {
  final temp = DateTime(2020, 1, 1, t.hour, t.minute);
  return DateFormat('HH:mm', 'da').format(temp);
}
