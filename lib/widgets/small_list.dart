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
    const tileH = 90.0, sepH = 6.0;
    final visible = items.length > 3 ? 2.7 : items.length;
    final boxH = visible * tileH + (visible - 1) * sepH;
    return Column(
      children: [
        SizedBox(
          height: boxH,
          child: ListView.separated(
            itemCount: items.length,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemBuilder: (ctx, i) {
              final item = items[i];
              final sel = idOf(item) == selectedId;
              return SizedBox(
                height: tileH,
                child: tileBuilder(ctx, item, sel, () => onPick(item)),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: sepH),
          ),
        ),
        Divider(),
      ],
    );
  }
}
