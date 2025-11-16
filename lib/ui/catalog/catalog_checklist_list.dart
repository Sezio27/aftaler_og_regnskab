import 'package:aftaler_og_regnskab/domain/checklist_model.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/ui/widgets/cards/custom_card.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class CatalogChecklistList extends StatelessWidget {
  const CatalogChecklistList({super.key});
  @override
  Widget build(BuildContext context) {
    final items = context.select<ChecklistViewModel, List<ChecklistModel>>(
      (vm) => vm.allChecklists,
    );
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => InkWell(
        splashFactory: NoSplash.splashFactory,
        onTap: () => context.pushNamed(
          "checklistDetails",
          pathParameters: {'id': items[i].id!},
        ),
        child: CustomCard(
          field: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${items[i].name}", style: AppTypography.h4),
                      SizedBox(height: 10),
                      Text(
                        items[i].description ?? "---",
                        style: AppTypography.b6,
                      ),
                    ],
                  ),
                ),

                Text(
                  '${items[i].points.length} ${items[i].points.length == 1 ? "punkt" : "punkter"}',
                  style: AppTypography.num5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
