import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:flutter/material.dart';

class ReadActionsRow extends StatelessWidget {
  const ReadActionsRow({
    super.key,
    required this.onEdit,
    required this.onDelete,
    this.horizontalPadding = 30,
  });

  final VoidCallback onEdit;
  final Future<void> Function() onDelete;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          Expanded(
            child: CustomButton(
              text: "Rediger",
              textStyle: AppTypography.button3.copyWith(
                color: cs.onSurface.withAlpha(200),
              ),
              onTap: onEdit,
              borderRadius: 12,
              icon: Icon(
                Icons.edit_outlined,
                color: cs.onSurface.withAlpha(200),
              ),
              color: cs.onPrimary,
              borderStroke: Border.all(color: cs.onSurface.withAlpha(200)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: CustomButton(
              text: "Slet",
              textStyle: AppTypography.button3.copyWith(
                color: cs.error.withAlpha(200),
              ),
              onTap: onDelete,
              borderRadius: 12,
              icon: Icon(Icons.delete, color: cs.error.withAlpha(200)),
              color: cs.onPrimary,
              borderStroke: Border.all(color: cs.error.withAlpha(200)),
            ),
          ),
        ],
      ),
    );
  }
}

class EditActionsRow extends StatelessWidget {
  const EditActionsRow({
    super.key,
    required this.saving,
    required this.onCancel,
    required this.onConfirm,
    this.horizontalPadding = 30,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          Expanded(
            child: CustomButton(
              text: 'Annuller',
              onTap: saving ? () {} : onCancel,
              borderRadius: 12,
              color: cs.onPrimary,
              textStyle: AppTypography.button3.copyWith(
                color: cs.onSurface.withAlpha(200),
              ),
              borderStroke: Border.all(color: cs.onSurface.withAlpha(200)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: CustomButton(
              text: !saving ? "Bekræft" : "",
              icon: saving
                  ? CircularProgressIndicator(color: Colors.white)
                  : null,
              onTap: saving ? () {} : onConfirm,
              borderRadius: 12,
              color: cs.primary.withAlpha(200),
              textStyle: AppTypography.button3.copyWith(color: cs.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class AddActionRow extends StatelessWidget {
  const AddActionRow({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    required this.saving,
    required this.name,
  });
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String name;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: "Annuller",
            color: cs.onPrimary,
            borderStroke: Border.all(color: cs.onSurface.withAlpha(200)),
            elevation: 0,
            borderRadius: 14,
            textStyle: AppTypography.button3.copyWith(
              color: cs.onSurface.withAlpha(200),
            ),
            onTap: saving ? () {} : onCancel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomButton(
            text: !saving ? "Tilføj $name" : "",
            icon: saving
                ? CircularProgressIndicator(color: Colors.white)
                : null,
            onTap: saving ? () {} : onConfirm,
            borderRadius: 14,
            textStyle: AppTypography.button3.copyWith(
              color: Colors.white.withAlpha(200),
            ),
          ),
        ),
      ],
    );
  }
}
