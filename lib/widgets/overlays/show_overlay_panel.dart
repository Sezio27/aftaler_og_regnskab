import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<T?> showOverlayPanel<T>({
  required BuildContext context,
  required Widget child,
  bool dismissOnTapOutside = true,
  Color barrierColor = const Color(0xB3000000),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissOnTapOutside,
    barrierLabel: 'overlay',
    barrierColor: barrierColor,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, __, ___) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeInOut);
      return SafeArea(
        child: Stack(
          children: [
            if (dismissOnTapOutside)
              Positioned.fill(
                child: GestureDetector(onTap: () => context.pop()),
              ),
            Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: .95, end: 1).animate(curved),
                child: FadeTransition(
                  opacity: curved,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Material(
                      color: Colors.white,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 100),
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(ctx).viewInsets.bottom,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 520,
                            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
