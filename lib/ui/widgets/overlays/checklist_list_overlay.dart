import 'package:aftaler_og_regnskab/domain/checklist_model.dart';
import 'package:aftaler_og_regnskab/ui/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/ui/widgets/buttons/action_buttons.dart';
import 'package:aftaler_og_regnskab/ui/widgets/lists/checklist_list.dart';
import 'package:aftaler_og_regnskab/ui/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ChecklistListOverlay extends StatefulWidget {
  const ChecklistListOverlay({
    super.key,
    required this.initialSelectedIds,
    required this.onDone,
    this.initialQuery = '',
  });

  final Set<String> initialSelectedIds;
  final void Function(Set<String> newSelection) onDone;
  final String initialQuery;

  @override
  State<ChecklistListOverlay> createState() => _ChecklistListOverlayState();
}

class _ChecklistListOverlayState extends State<ChecklistListOverlay> {
  late final TextEditingController _searchCtrl;
  late final ChecklistViewModel _vm;
  late Set<String> _selected;
  final Set<String> _removedOnce = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
    _vm = context.read<ChecklistViewModel>();
    _vm.initChecklistFilters(initialQuery: widget.initialQuery);
    if (widget.initialQuery.isNotEmpty) {
      _vm.setChecklistSearch(widget.initialQuery);
    }
    _selected = {...widget.initialSelectedIds};
  }

  @override
  void dispose() {
    _vm.clearSearch();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TapRegion(
      onTapInside: (_) => _clearFocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Text(
                  'Tilføj checklister',
                  style: AppTypography.b1.copyWith(color: cs.onSurface),
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.pop(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SearchField(
            controller: _searchCtrl,
            onChanged: context.read<ChecklistViewModel>().setChecklistSearch,
            ctx: context,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ChecklistList(
              selectedIds: _selected,
              smallList: false,
              onToggle: (ChecklistModel item, bool nowSelected) {
                setState(() {
                  final id = item.id!;
                  if (nowSelected) {
                    _selected.add(id);
                  } else {
                    _selected.remove(id);
                    _removedOnce.add(id);
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          EditActionsRow(
            confirmColor: cs.primary,
            saving: _vm.saving,
            onCancel: () => context.pop(),
            onConfirm: () {
              widget.onDone({..._selected});
              context.pop();
            },
          ),
        ],
      ),
    );
  }
}
