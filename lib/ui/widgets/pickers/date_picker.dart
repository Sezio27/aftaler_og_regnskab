import 'package:aftaler_og_regnskab/ui/theme/typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DatePicker extends StatelessWidget {
  const DatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.minimumDate,
    this.maximumDate,
    this.modalHeight = 300,
    this.displayFormat,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final double modalHeight;
  final String Function(DateTime date)? displayFormat;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String defaultLabel(DateTime d) =>
        '${d.day}. ${_monthShortDa[d.month - 1]} ${d.year}';

    final String label = (value != null)
        ? (displayFormat ?? defaultLabel)(value!)
        : '---';

    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: () async {
          final picked = await context.pickCupertinoDate(
            initial: value ?? DateTime.now(),
            minimumDate: minimumDate,
            maximumDate: maximumDate,
            modalHeight: modalHeight,
          );
          if (picked != null) onChanged(picked);
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: cs.onSurface.withOpacity(0.25), width: 1),
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
        ),
        child: Text(label, style: AppTypography.num3),
      ),
    );
  }
}

extension DatePickerContextExt on BuildContext {
  Future<DateTime?> pickCupertinoDate({
    required DateTime initial,
    DateTime? minimumDate,
    DateTime? maximumDate,
    double modalHeight = 300,
    Locale locale = const Locale('da'),
  }) async {
    DateTime temp = initial;

    return showCupertinoModalPopup<DateTime>(
      context: this,
      builder: (popupContext) => Localizations.override(
        context: popupContext,
        locale: locale,
        child: Material(
          color: Theme.of(this).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: modalHeight,
              child: Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(popupContext).pop(),
                          child: const Text('Annuller'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(popupContext).pop(temp),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0),

                  Expanded(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: initial,
                      minimumDate: minimumDate,
                      maximumDate: maximumDate,
                      onDateTimeChanged: (dt) => temp = dt,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const List<String> _monthShortDa = [
  'Jan.',
  'Feb.',
  'Mar.',
  'Apr.',
  'Maj',
  'Jun.',
  'Jul.',
  'Aug.',
  'Sep.',
  'Okt.',
  'Nov.',
  'Dec.',
];
