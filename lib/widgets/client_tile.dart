import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/avatar.dart';
import 'package:flutter/material.dart';

class ClientTile extends StatelessWidget {
  const ClientTile({
    super.key,
    required this.c,
    this.selected = false,
    this.onTap,
    this.border = true,
  });

  final ClientModel c;
  final bool selected;
  final VoidCallback? onTap;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.onPrimary,
          borderRadius: BorderRadius.circular(12),
          border: border
              ? Border.all(
                  color: selected ? cs.primary : cs.onSurface.withAlpha(50),
                  width: selected ? 1.4 : 1.0,
                )
              : null,
        ),
        child: Row(
          children: [
            Avatar(imageUrl: c.image, name: c.name),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name ?? '—',
                    style: AppTypography.b3.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Info(icon: Icons.phone, text: c.phone),
                      _Info(icon: Icons.mail, text: c.email),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({this.icon, this.text});
  final IconData? icon;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
        ],
        Text(
          text ?? '---',
          maxLines: 1,
          style: AppTypography.num6.copyWith(
            color: cs.onSurface.withAlpha(230),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
