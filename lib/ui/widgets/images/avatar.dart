import 'package:aftaler_og_regnskab/ui/theme/colors.dart';
import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.imageUrl, this.name, this.size = 60});
  final String? imageUrl;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget placeholder() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.greyBackground.withAlpha(200),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: size * 0.55,
        color: cs.onSurface.withAlpha(150),
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return placeholder();

    return ClipOval(
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
