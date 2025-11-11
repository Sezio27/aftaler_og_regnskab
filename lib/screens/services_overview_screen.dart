import 'package:aftaler_og_regnskab/model/checklist_model.dart';
import 'package:aftaler_og_regnskab/model/service_model.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/format_price.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/cards/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_checklist_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_service_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/show_overlay_panel.dart';
import 'package:aftaler_og_regnskab/widgets/search_field.dart';
import 'package:aftaler_og_regnskab/widgets/seg_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

enum Tabs { services, checklists }

class ServicesOverviewScreen extends StatefulWidget {
  const ServicesOverviewScreen({super.key});

  @override
  State<ServicesOverviewScreen> createState() => _ServicesOverviewScreenState();
}

class _ServicesOverviewScreenState extends State<ServicesOverviewScreen> {
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
                      icon: Icons.face_retouching_natural,
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
                        ? const _ServicesGrid()
                        : const _ChecklistsList(),
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

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = context.select<ServiceViewModel, List<ServiceModel>>(
      (vm) => vm.allServices,
    );

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: .80,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(blurRadius: 3, color: cs.onSurface.withAlpha(70)),
          ],
        ),
        child: ServiceItem(service: items[i]),
      ),
    );
  }
}

class _ServiceImage extends StatelessWidget {
  const _ServiceImage(this.url);
  final String? url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Fills all available space
    final Widget placeholder = Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.greyBackground.withAlpha(200),
      alignment: Alignment.center,
      child: Icon(
        Icons.hotel_class,
        size: 30,
        color: cs.onSurface.withAlpha(150),
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      child: (url == null || url!.isEmpty)
          ? placeholder
          : Image.network(
              url!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
              loadingBuilder: (c, child, p) => p == null ? child : placeholder,
            ),
    );
  }
}

class ServiceItem extends StatelessWidget {
  const ServiceItem({super.key, required this.service});
  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.pushNamed(
        "serviceDetails",
        pathParameters: {'id': service.id!},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // image placeholder
          Expanded(child: _ServiceImage(service.image)),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name ?? "", style: AppTypography.b3),
                SizedBox(height: 12),
                Text(formatDKK(service.price), style: AppTypography.num3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistsList extends StatelessWidget {
  const _ChecklistsList();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = context.select<ChecklistViewModel, List<ChecklistModel>>(
      (vm) => vm.allChecklists,
    );
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(.06)),
          ],
        ),
        child: InkWell(
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
      ),
    );
  }
}
