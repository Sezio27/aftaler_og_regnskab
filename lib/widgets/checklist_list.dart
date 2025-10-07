import 'package:aftaler_og_regnskab/model/checklistModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/checklist_tile.dart';
import 'package:aftaler_og_regnskab/widgets/small_list.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChecklistList extends StatelessWidget {
  const ChecklistList({
    super.key,
    required this.selectedIds,
    required this.onToggle,
    this.smallList = true,
  });

  final Set<String> selectedIds;
  final void Function(ChecklistModel item, bool selected) onToggle;
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
          'Ingen checklister fundet',
          style: AppTypography.b5.copyWith(color: cs.onSurface.withAlpha(200)),
        ),
      );
    }

    return Column(
      children: [
        for (final c in items) ...[
          ChecklistTile(
            c: c,
            selected: selectedIds.contains(c.id),
            onChanged: (sel) => onToggle(c, sel),
          ),
          SizedBox(height: 4),
        ],
      ],
    );
  }
}
