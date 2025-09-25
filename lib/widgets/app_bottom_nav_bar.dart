import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  static const _items = <_BottomNavItem>[
    _BottomNavItem(icon: Icons.home_outlined, label: 'Hjem'),
    _BottomNavItem(icon: Icons.calendar_today_outlined, label: 'Kalender'),
    _BottomNavItem(icon: Icons.attach_money, label: 'Regnskab'),
    _BottomNavItem(icon: Icons.shopping_cart_outlined, label: 'Services'),
    _BottomNavItem(icon: Icons.settings_outlined, label: 'Indstillinger'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(gradient: AppGradients.peach3),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 10,
            right: 10,
            top: 12,
            bottom: 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _NavButton(
                        item: _items[i],
                        isSelected: currentIndex == i,
                        onTap: () => onItemSelected(i),
                        activeColor: colorScheme.onPrimary,
                      ),
                    ),
                ],
              ),
            ],
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
  });

  final _BottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Colors.white.withOpacity(0.72);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 28,
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.none,
                child: Text(
                  textAlign: TextAlign.start,
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  style: isSelected
                      ? AppTypography.onPrimary(context, AppTypography.nav1)
                      : AppTypography.onPrimary(context, AppTypography.nav2),
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
