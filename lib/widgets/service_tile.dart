import 'package:aftaler_og_regnskab/model/service_model.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/format_price.dart';
import 'package:flutter/material.dart';

class ServiceTile extends StatelessWidget {
  const ServiceTile({
    super.key,
    required this.s,
    this.selected = false,
    this.onTap,
  });

  final ServiceModel s;
  final bool selected;
  final VoidCallback? onTap;

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
          border: Border.all(
            color: selected ? cs.primary : cs.onSurface.withAlpha(50),
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            ServiceThumb(imageUrl: s.image, name: s.name),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    s.name ?? '—',
                    style: AppTypography.b3.copyWith(color: cs.onSurface),
                  ),

                  Row(
                    children: [
                      _Info(icon: Icons.schedule, text: s.duration),
                      Text(
                        " timer",
                        style: AppTypography.num6.copyWith(
                          color: cs.onSurface.withAlpha(230),
                        ),
                      ),
                      const SizedBox(width: 46),
                      _Info(
                        text: s.price != null ? formatPrice(s.price) : null,
                      ),
                      Text(
                        " Kr.",
                        style: AppTypography.num6.copyWith(
                          color: cs.onSurface.withAlpha(230),
                        ),
                      ),
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
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 4),
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

class ServiceThumb extends StatelessWidget {
  const ServiceThumb({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 56,
    this.radius = 8, // set to 0 for hard square
    this.placeholderIcon = Icons.hotel_class,
  });

  final String? imageUrl;
  final String? name; // optional, if you ever want to show initials, etc.
  final double size;
  final double radius;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget placeholder() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.greyBackground.withAlpha(200),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        placeholderIcon,
        size: size * 0.5,
        color: cs.onSurface.withAlpha(150),
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return placeholder();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : SizedBox(
                width: size,
                height: size,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      ),
    );
  }
}
