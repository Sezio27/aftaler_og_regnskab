import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/client_tile.dart';
import 'package:aftaler_og_regnskab/widgets/small_list.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ClientList extends StatelessWidget {
  const ClientList({
    super.key,
    this.selectedId,
    required this.onPick,
    this.smallList = true,
    this.hasCvr,
    this.collapseWhenSelected = true,
  });

  final String? selectedId;
  final ValueChanged<ClientModel> onPick;
  final bool smallList;
  final bool? hasCvr;
  final bool collapseWhenSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Just read the precomputed list from VM (no streams here)
    final items = context.select<ClientViewModel, List<ClientModel>>(
      (vm) => hasCvr == null
          ? vm.allClients
          : hasCvr!
          ? vm.businessClients
          : vm.privateClients,
    );

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Ingen klienter fundet',
          style: AppTypography.b5.copyWith(color: cs.onSurface.withAlpha(200)),
        ),
      );
    }

    ClientModel? selectedItem;
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
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeIn,
        );

        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
          reverseCurve: const Interval(0.0, 0.01, curve: Curves.easeIn),
        );

        return SizeTransition(
          sizeFactor: size,
          axisAlignment: -1.0,
          child: FadeTransition(opacity: fade, child: child),
        );
      },

      child: (selectedItem != null)
          ? SizedBox(
              key: ValueKey('selected_${selectedItem!.id}'),
              height: 90,
              child: ClientTile(c: selectedItem!, selected: true),
            )
          : KeyedSubtree(
              key: const ValueKey('list'),
              child: smallList
                  ? SmallList<ClientModel>(
                      items: items,
                      selectedId: selectedId,
                      onPick: onPick,
                      idOf: (c) => c.id ?? '',
                      tileBuilder: (ctx, c, selected, onTap) => SizedBox(
                        height: 90,
                        child: ClientTile(
                          c: c,
                          selected: selected,
                          onTap: onTap,
                        ),
                      ),
                    )
                  : _FullClientList(
                      items: items,
                      selectedId: selectedId,
                      onPick: onPick,
                    ),
            ),
    );
  }
}

class _FullClientList extends StatelessWidget {
  const _FullClientList({
    required this.items,

    required this.selectedId,
    required this.onPick,
  });

  final List<ClientModel> items;
  final String? selectedId;
  final ValueChanged<ClientModel> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = items[i];
        return ClientTile(
          c: c,
          selected: c.id == selectedId,
          onTap: () => onPick(c),
        );
      },
    );
  }
}
