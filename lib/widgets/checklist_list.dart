import 'package:aftaler_og_regnskab/model/checklistModel.dart';
import 'package:aftaler_og_regnskab/model/serviceModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/checklist_tile.dart';
import 'package:aftaler_og_regnskab/widgets/service_tile.dart';
import 'package:aftaler_og_regnskab/widgets/small_list.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChecklistList extends StatelessWidget {
  const ChecklistList({
    super.key,
    this.selectedId,
    required this.onPick,
    this.smallList = true,
  });

  final String? selectedId;
  final ValueChanged<ChecklistModel> onPick;
  final bool smallList;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = context.select<ChecklistViewModel, List<ChecklistModel>>(
      (vm) => vm.allChecklists,
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

    ChecklistModel? selectedItem;
    if (selectedId != null) {
      for (final c in items) {
        if (c.id == selectedId) {
          selectedItem = c;
          break;
        }
      }
    }

    return  (selectedItem != null)
          ? SizedBox(
              key: ValueKey('selected_${selectedItem.id}'),
              height: 90,
              child: ChecklistTile(c: selectedItem, selected: true),
            )
          : KeyedSubtree(
              key: const ValueKey('list'),
              child: smallList
                  ? SmallList<ChecklistModel>(
                      items: items,
                      selectedId: selectedId,
                      onPick: onPick,
                      idOf: (c) => c.id ?? '',
                      tileBuilder: (ctx, s, selected, onTap) =>
                          ChecklistTile(c: s, selected: selected, onTap: onTap),
                    )
                  : Text("to do"),
            );
    
  }
}
