extension PhoneFormat on String? {
  String toGroupedPhone({int group = 2, String sep = ' '}) {
    final raw = (this ?? '').trim();

    final hasPlus = raw.startsWith('+');
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    var cc = '';
    var rest = digits;

    if (hasPlus && digits.length > 2) {
      cc = '+${digits.substring(0, 2)}';
      rest = digits.substring(2);
    }

    final buf = StringBuffer();
    for (var i = 0; i < rest.length; i++) {
      if (i > 0 && i % group == 0) buf.write(sep);
      buf.write(rest[i]);
    }

    return cc.isEmpty ? buf.toString() : '$cc $buf';
  }
}
