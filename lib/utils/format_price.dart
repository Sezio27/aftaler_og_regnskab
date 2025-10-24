String formatPrice(num? value, {String placeholder = '---'}) {
  if (value == null) return placeholder;

  final d = value.toDouble();
  final rounded = (d * 100).round() / 100.0;
  var s = rounded.toStringAsFixed(2);
  s = s.replaceFirst(
    RegExp(r'\.?0+$'),
    '',
  ); // remove trailing 0s and optional '.'
  return s;
}

double? parsePrice(String? input) {
  final raw = input?.trim();
  if (raw == null || raw.isEmpty) return null;

  // Keep only digits, separators, and minus
  var s = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '');

  if (s.isEmpty) return null;

  final hasComma = s.contains(',');
  final hasDot = s.contains('.');

  if (hasComma && hasDot) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (hasComma && !hasDot) {
    s = s.replaceAll(',', '.');
  }
  return double.tryParse(s);
}

String formatDKK(num? value, {String placeholder = '---'}) {
  final s = formatPrice(value, placeholder: placeholder);
  if (s == placeholder) return placeholder;
  return '$s Kr.';
}
