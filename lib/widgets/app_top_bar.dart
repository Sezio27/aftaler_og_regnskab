import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final Widget? action;
  final double height;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = false,
    this.action,
    this.height = kToolbarHeight * 1.7,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Container(
        decoration: BoxDecoration(gradient: AppGradients.peach3),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showBackButton) ...[
                  const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                  const SizedBox(width: 20),
                ],
                // Title + (optional) subtitle
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.h3.copyWith(color: Colors.white),
                      ),

                      if (subtitle != null) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: EdgeInsets.only(left: 10),
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.h4.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 12), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
