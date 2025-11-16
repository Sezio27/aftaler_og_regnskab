import 'package:aftaler_og_regnskab/domain/checklist_model.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ChecklistTile extends StatelessWidget {
  const ChecklistTile({
    super.key,
    required this.c,
    this.selected = false,
    required this.onChanged,
  });

  final ChecklistModel c;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => onChanged(!selected),
      splashFactory: NoSplash.splashFactory,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.onSurface.withAlpha(60),
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Transform.scale(
              scale: 1.3,
              child: CupertinoCheckbox(
                value: selected,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: cs.primary,
                checkColor: CupertinoColors.white,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name ?? '—',
                    style: AppTypography.b3.copyWith(color: cs.onSurface),
                  ),
                  if ((c.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      c.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.num6.copyWith(
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
