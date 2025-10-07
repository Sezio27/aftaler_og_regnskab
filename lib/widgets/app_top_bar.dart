import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class AppTopBarContent extends StatelessWidget {
  final String? title;
  final bool showBackButton;
  final Widget? action;
  final double maxContentWidth;
  final double fixedHeight;

  const AppTopBarContent({
    super.key,
    this.title,
    this.showBackButton = false,
    this.action,
    required this.maxContentWidth,
    required this.fixedHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final logoPath = isDark ? 'assets/logo_white.png' : 'assets/logo_black.png';

    final Widget centerWidget = title != null && title!.isNotEmpty
        ? Text(title!, style: AppTypography.h2.copyWith(color: cs.onSurface))
        : SizedBox(width: 140, child: Image.asset(logoPath, fit: BoxFit.fitWidth));

    return SizedBox(
      height: fixedHeight,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Centered title or logo
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Center(child: centerWidget),
                ),

                // Back button pinned to the RIGHT (as requested)
                if (showBackButton)
                  Positioned(
                    left: 20,
                    top: 14,
                    bottom: 0,
                    
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: cs.onSurface, size: 28),
                      splashRadius: 24,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                    ),
                  ),

                // Optional custom action pinned to the LEFT (swap if you prefer)
                if (action != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(child: action!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showBackButton;
  final Widget? action;
  final double width;
  final double height;

  const AppTopBar({
    super.key,
    this.title,
    this.showBackButton = false,
    this.action,
    required this.width,
    required this.height,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return AppTopBarContent(
      title: title,
      showBackButton: showBackButton,
      action: action,
      maxContentWidth: width,
      fixedHeight: height,
    );
  }
}

class AppTopBarSliver extends StatelessWidget {
  final String? title;
  final bool showBackButton;
  final Widget? action;
  final double maxContentWidth;
  final double fixedHeight;

  const AppTopBarSliver({
    super.key,
    this.title,
    this.showBackButton = false,
    this.action,
    required this.maxContentWidth,
    required this.fixedHeight,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).colorScheme.surface;

    return SliverAppBar(
      automaticallyImplyLeading: false,
      backgroundColor: backgroundColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      floating: true,
      snap: true,
      pinned: false,
      expandedHeight: fixedHeight,
      collapsedHeight: fixedHeight,
      toolbarHeight: fixedHeight,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: AppTopBarContent(
          title: title,
          showBackButton: showBackButton,
          action: action,
          maxContentWidth: maxContentWidth,
          fixedHeight: fixedHeight,
        ),
      ),
    );
  }
}
