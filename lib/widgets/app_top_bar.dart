import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final bool showBackButton;
  final bool center;
  final Widget? action;
  final double width;
  final double height;

  const AppTopBar({
    super.key,
    this.title,
    this.subtitle,
    this.showBackButton = false,
    this.center = true,
    this.action,
    required this.width,
    required this.height,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final logoPath = isDark ? 'assets/logo_white.png' : 'assets/logo_black.png';

    final Widget titleOrLogo = (title != null && title!.isNotEmpty)
        ? Text(title!, style: AppTypography.h2.copyWith(color: cs.onSurface))
        : SizedBox(
            width: 140,
            child: Image.asset(logoPath, fit: BoxFit.fitWidth),
          );

    // Reusable: title/logo + optional subtitle
    Widget titleBlock({required bool centered}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          titleOrLogo,
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.input2.copyWith(
                color: cs.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      );
    }

    final backBtn = IconButton(
      icon: Icon(Icons.arrow_back, color: cs.onSurface, size: 28),
      splashRadius: 24,
      onPressed: () {
        HapticFeedback.selectionClick();
        if (context.canPop())
          context.pop();
        else
          context.go('/home');
      },
    );

    return SizedBox(
      height: height,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: center
                  // CENTERED layout: keep block exactly centered
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        if (showBackButton)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: backBtn,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: titleBlock(centered: true),
                        ),
                        if (action != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: action!,
                            ),
                          ),
                      ],
                    )
                  // LEFT-ALIGNED layout: back button, then block, action on right
                  : Row(
                      children: [
                        if (showBackButton) ...[
                          backBtn,
                          const SizedBox(width: 4),
                        ],
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: titleBlock(centered: false),
                        ),
                        const Spacer(),
                        if (action != null) action!,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
