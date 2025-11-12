import 'package:aftaler_og_regnskab/ui/catalog/catalog_checklist_list.dart';
import 'package:aftaler_og_regnskab/ui/catalog/catalog_service_grid.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/ui/widgets/overlays/add_checklist_panel.dart';
import 'package:aftaler_og_regnskab/ui/widgets/overlays/add_service_panel.dart';
import 'package:aftaler_og_regnskab/ui/widgets/overlays/show_overlay_panel.dart';
import 'package:aftaler_og_regnskab/ui/widgets/search_field.dart';
import 'package:aftaler_og_regnskab/ui/widgets/seg_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

enum Tabs { services, checklists }

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final ServiceViewModel _serviceVM;
  late final ChecklistViewModel _checklistVM;

  Tabs _tab = Tabs.services;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _serviceVM = context.read<ServiceViewModel>();
    _checklistVM = context.read<ChecklistViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _serviceVM.initServiceFilters();
      _checklistVM.initChecklistFilters();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 24, 18, 30),
            child: Column(
              children: [
                CupertinoSlidingSegmentedControl<Tabs>(
                  groupValue: _tab,
                  backgroundColor: cs.surface,
                  thumbColor: cs.secondary,
                  onValueChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _tab = v;

                      _searchCtrl.clear();
                    });

                    FocusScope.of(context).unfocus();
                    _serviceVM.setServiceSearch('');
                    _checklistVM.setChecklistSearch('');
                  },
                  children: {
                    Tabs.services: SegItem(
                      icon: Icons.face_3,
                      text: 'Services',
                      active: _tab == Tabs.services,
                    ),
                    Tabs.checklists: SegItem(
                      icon: Icons.checklist,
                      text: 'Checklister',
                      active: _tab == Tabs.checklists,
                    ),
                  },
                ),

                const SizedBox(height: 16),
                SearchField(
                  controller: _searchCtrl,
                  onChanged: (q) => setState(() {
                    _tab == Tabs.services
                        ? _serviceVM.setServiceSearch(q)
                        : _checklistVM.setChecklistSearch(q);
                  }),
                  ctx: context,
                ),

                const SizedBox(height: 24),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _tab == Tabs.services
                        ? const CatalogServiceGrid()
                        : const CatalogChecklistList(),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            right: 16,
            bottom: 36,
            child: FloatingActionButton(
              onPressed: () async {
                if (_tab == Tabs.services) {
                  await showOverlayPanel(
                    context: context,
                    child: const AddServicePanel(),
                  );
                } else {
                  await showOverlayPanel(
                    context: context,
                    child: const AddChecklistPanel(),
                  );
                }
              },
              elevation: 2,
              shape: const CircleBorder(),
              backgroundColor: cs.secondary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}
