import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/client_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ClientList extends StatelessWidget {
  const ClientList({
    super.key,
    this.selectedId,
    required this.onPick,
    this.smallList = true,
    this.hasCvr,
  });

  final String? selectedId;
  final ValueChanged<ClientModel> onPick;
  final bool smallList;
  final bool? hasCvr;

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

    return smallList
        ? _SmallClientList(items: items, selectedId: selectedId, onPick: onPick)
        : _FullClientList(items: items, selectedId: selectedId, onPick: onPick);
  }
}

class _SmallClientList extends StatelessWidget {
  const _SmallClientList({
    required this.items,

    required this.selectedId,
    required this.onPick,
  });

  final List<ClientModel> items;

  final String? selectedId;
  final ValueChanged<ClientModel> onPick;

  @override
  Widget build(BuildContext context) {
    const tileH = 90.0, sepH = 6.0;
    final visible = items.length > 3 ? 2.5 : items.length;
    final boxH = visible * tileH + (visible - 1) * sepH;
    return Column(
      children: [
        SizedBox(
          height: boxH,
          child: ListView.separated(
            itemCount: items.length,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemBuilder: (_, i) => SizedBox(
              height: tileH,
              child: ClientTile(
                c: items[i],
                selected: items[i].id == selectedId,
                onTap: () => onPick(items[i]),
              ),
            ),
            separatorBuilder: (_, __) => const SizedBox(height: sepH),
          ),
        ),
        Divider(),
      ],
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
