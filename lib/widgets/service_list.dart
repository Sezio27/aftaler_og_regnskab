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
    this.hasCvr,
  });

  final String? selectedId;
  final ValueChanged<ServiceModel> onPick;
  final bool smallList;
  final bool? hasCvr;

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

    return smallList
        ? SmallList<ServiceModel>(
            items: items,
            selectedId: selectedId,
            onPick: onPick,
            idOf: (s) => s.id ?? '',
            tileBuilder: (ctx, s, selected, onTap) =>
                ServiceTile(s: s, selected: selected, onTap: onTap),
          )
        : Text("to do");
  }
}
