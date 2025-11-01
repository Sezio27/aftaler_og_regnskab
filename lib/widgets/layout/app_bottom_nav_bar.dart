import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:flutter/material.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    this.maxContentWidth = 900,
    this.iconSize = 24,
  });

  final int? currentIndex;
  final ValueChanged<int> onItemSelected;
  final double maxContentWidth;
  final double iconSize;

  static const _items = <_BottomNavItem>[
    _BottomNavItem(icon: Icons.home_outlined, label: 'Hjem'),
    _BottomNavItem(icon: Icons.calendar_today_outlined, label: 'Kalender'),
    _BottomNavItem(icon: Icons.attach_money, label: 'Regnskab'),
    _BottomNavItem(icon: Icons.shopping_cart_outlined, label: 'Services'),
    _BottomNavItem(icon: Icons.settings_outlined, label: 'Indstillinger'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: LayoutMetrics.navBarHeight(context),
      child: Container(
        decoration: BoxDecoration(gradient: AppGradients.peach3),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _NavButton(
                        item: _items[i],
                        isSelected: currentIndex == i,
                        onTap: () => onItemSelected(i),
                        activeColor: Colors.white,
                        iconSize: iconSize,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.iconSize,
  });

  final _BottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Colors.white.withAlpha(235);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withAlpha(45) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                color: isSelected ? activeColor : inactiveColor,
                size: iconSize,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.none,
                child: Text(
                  textAlign: TextAlign.start,
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  style: isSelected
                      ? AppTypography.nav1.copyWith(color: Colors.white)
                      : AppTypography.nav2.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
