import 'package:flutter/material.dart';

class SmallList<T> extends StatelessWidget {
  const SmallList({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onPick,
    required this.idOf,
    required this.tileBuilder,
  });

  final List<T> items;
  final String? selectedId;
  final ValueChanged<T> onPick;
  final String Function(T item) idOf;
  final Widget Function(
    BuildContext context,
    T item,
    bool selected,
    VoidCallback onTap,
  )
  tileBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            final sel = idOf(item) == selectedId;
            return SizedBox(
              height: 90,
              child: tileBuilder(ctx, item, sel, () => onPick(item)),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 6),
        ),
        const Divider(),
      ],
    );
  }
}
