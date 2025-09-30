import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Compact button + Cupertino wheel time picker modal.
/// Rename/file as you like.
class TimePicker extends StatelessWidget {
  const TimePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.use24h = true,
    this.modalHeight = 300,
  });

  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;
  final bool use24h;
  final double modalHeight;

  Future<TimeOfDay?> _showWheelTimePicker(
    BuildContext context,
    TimeOfDay initial,
  ) async {
    final now = DateTime.now();
    DateTime temp = DateTime(
      now.year,
      now.month,
      now.day,
      initial.hour,
      initial.minute,
    );

    return showCupertinoModalPopup<TimeOfDay>(
      context: context,
      builder: (popupContext) => Material(
        // Material for TextButton ink + theme
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
                      onPressed: () => Navigator.of(
                        popupContext,
                      ).pop(TimeOfDay(hour: temp.hour, minute: temp.minute)),
                      child: const Text('OK'),
                    ),
                  ],
                ),
                const Divider(height: 0),
                // Wheel
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: use24h,
                    initialDateTime: temp,
                    onDateTimeChanged: (dt) => temp = dt,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = value.format(context);

    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: () async {
          final picked = await _showWheelTimePicker(context, value);
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
