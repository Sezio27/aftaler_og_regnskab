import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final ml = MaterialLocalizations.of(context);
    final start = ml.firstDayOfWeekIndex;

    final ds = DateFormat('EEE', locale).dateSymbols;
    final base = ds.STANDALONESHORTWEEKDAYS;

    final labels = List<String>.generate(
      7,
      (i) => base[(start + i) % 7],
    ).map((s) => s.capitalize()).toList(growable: false);

    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(child: Text(label, style: AppTypography.b8)),
          ),
      ],
    );
  }
}
