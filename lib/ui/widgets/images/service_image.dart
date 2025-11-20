import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:flutter/material.dart';

class ServiceImage extends StatelessWidget {
  const ServiceImage(this.url, {super.key});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Widget placeholder = Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.greyBackground.withAlpha(200),
      alignment: Alignment.center,
      child: Icon(
        Icons.hotel_class,
        size: 30,
        color: cs.onSurface.withAlpha(150),
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      child: (url == null || url!.isEmpty)
          ? placeholder
          : Image.network(
              url!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
              loadingBuilder: (c, child, p) => p == null ? child : placeholder,
            ),
    );
  }
}
