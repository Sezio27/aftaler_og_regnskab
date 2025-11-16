import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/ui/widgets/buttons/custom_button.dart';
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
              color: cs.surface,
              elevation: 2,
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
              color: cs.surface,
              elevation: 2,
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
    this.confirmColor,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final double horizontalPadding;
  final Color? confirmColor;

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
              color: cs.surface,
              textStyle: AppTypography.button3.copyWith(color: cs.onSurface),
              elevation: 2,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: CustomButton(
              text: !saving ? "Bekræft" : "",
              onTap: saving ? () {} : onConfirm,
              loading: saving,
              borderRadius: 12,
              gradient: confirmColor == null ? AppGradients.peach3 : null,
              color: confirmColor,
              textStyle: AppTypography.button3.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
              elevation: 2,
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
            color: cs.surface,
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
