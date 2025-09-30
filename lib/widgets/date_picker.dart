import 'package:aftaler_og_regnskab/theme/typography.dart';
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

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final double modalHeight;
  final String Function(DateTime date)? displayFormat;

  Future<DateTime?> _showWheelDatePicker(
    BuildContext context,
    DateTime initial,
  ) async {
    DateTime temp = initial;

    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (popupContext) => Localizations.override(
        context: popupContext,
        locale: const Locale('da'),

        child: Material(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: modalHeight,
              child: Column(
                children: [
                  // Action bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(popupContext).pop(),
                        child: const Text('Annuller'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(popupContext).pop(temp),
                        child: const Text('OK'),
                      ),
                    ],
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

  @override
  Widget build(BuildContext context) {
    String defaultLabel(DateTime d) =>
        '${d.day}. ${_monthShortDa[d.month - 1]} ${d.year}';
    final label = (displayFormat ?? defaultLabel)(value);

    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: () async {
          final picked = await _showWheelDatePicker(context, value);
          if (picked != null) onChanged(picked);
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: Colors.black.withOpacity(0.25), width: 1),
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        child: Text(label, style: AppTypography.num3),
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
