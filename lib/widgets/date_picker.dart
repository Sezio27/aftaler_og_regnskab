// lib/widgets/date_picker.dart
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Minimal, reusable button-style date picker (kept for places where you want a control).
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

  final DateTime value;
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
    final label = (displayFormat ?? defaultLabel)(value);

    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: () async {
          final picked = await context.pickCupertinoDate(
            initial: value,
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
                  // Toolbar
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
                  // Wheel
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
  'jan.',
  'feb.',
  'mar.',
  'apr.',
  'maj',
  'jun.',
  'jul.',
  'aug.',
  'sep.',
  'okt.',
  'nov.',
  'dec.',
];
