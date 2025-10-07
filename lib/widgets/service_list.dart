import 'package:aftaler_og_regnskab/model/serviceModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/service_tile.dart';
import 'package:aftaler_og_regnskab/widgets/small_list.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ServiceList extends StatelessWidget {
  const ServiceList({
    super.key,
    this.selectedId,
    required this.onPick,
    this.smallList = true,
    this.collapseWhenSelected = true,
  });

  final String? selectedId;
  final ValueChanged<ServiceModel> onPick;
  final bool smallList;
  final bool collapseWhenSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = context.select<ServiceViewModel, List<ServiceModel>>(
      (vm) => vm.allServices,
    );

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Ingen services fundet',
          style: AppTypography.b5.copyWith(color: cs.onSurface.withAlpha(200)),
        ),
      );
    }

    ServiceModel? selectedItem;
    if (collapseWhenSelected && selectedId != null) {
      for (final c in items) {
        if (c.id == selectedId) {
          selectedItem = c;
          break;
        }
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        final size = CurvedAnimation(
          parent: animation,
          curve: Curves.ease,
          reverseCurve: Curves.easeOut
        );

        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 1, curve: Curves.easeIn),
          reverseCurve: const Interval(0.0, 1, curve: Curves.easeOut),
        );

        return SizeTransition(
          sizeFactor: size,
          axisAlignment: -1.0,
          child: FadeTransition(opacity: fade, child: child),
        );
      },

      child: (selectedItem != null)
          ? SizedBox(
              key: ValueKey('selected_${selectedItem.id}'),
              height: 90,
              child: ServiceTile(s: selectedItem, selected: true),
            )
          : KeyedSubtree(
              key: const ValueKey('list'),
              child: smallList
                  ? SmallList<ServiceModel>(
                      items: items,
                      selectedId: selectedId,
                      onPick: onPick,
                      idOf: (c) => c.id ?? '',
                      tileBuilder: (ctx, s, selected, onTap) =>
                          ServiceTile(s: s, selected: selected, onTap: onTap),
                    )
                  : Text("to do"),
            ),
    );
  }
}
