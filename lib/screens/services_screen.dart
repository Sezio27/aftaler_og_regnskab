import 'package:aftaler_og_regnskab/model/serviceModel.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/custom_search_bar.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_checklist_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_service_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/show_overlay_panel.dart';
import 'package:aftaler_og_regnskab/widgets/seg_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

enum Tabs { services, checklists }

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  Tabs _tab = Tabs.services;
  final _searchCtrl = TextEditingController();
  String _query = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceViewModel>().initServiceFilters();
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
    final vm = context.read<ServiceViewModel>();

    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 24, 18, 30),
            child: Column(
              children: [
                CupertinoSlidingSegmentedControl<Tabs>(
                  groupValue: _tab,
                  backgroundColor: cs.onPrimary,
                  thumbColor: cs.secondary,
                  onValueChanged: (v) => setState(() => _tab = v!),
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

                //Search
                CupertinoSearchTextField(
                  controller: _searchCtrl,
                  placeholder: 'Søg',
                  onChanged: (q) => setState(() => _query = q.trim()),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  itemColor: cs.onSurface.withAlpha(150),
                  style: AppTypography.b2.copyWith(color: cs.onSurface),
                  placeholderStyle: AppTypography.b2.copyWith(
                    color: cs.onSurface.withAlpha(150),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    boxShadow: [
                      BoxShadow(
                        color: cs.onSurface.withAlpha(180),
                        offset: Offset(0, 1),
                        blurRadius: 0.1,
                        blurStyle: BlurStyle.outer,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                // Body
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
            bottom: 36, // keep above your bottom nav
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
              foregroundColor: cs.onPrimary,
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
            BoxShadow(blurRadius: 2, color: cs.onSurface.withAlpha(50)),
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
    return Column(
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
              Text(
                service.price != null ? "${service.price!} Kr." : "Ingen pris",
                style: AppTypography.segPassiveNumber,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChecklistsList extends StatelessWidget {
  const _ChecklistsList();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(.06)),
          ],
        ),
        child: const ListTile(
          title: Text('Bryllups makeup'),
          subtitle: Text('Komplet checkliste til bryllups makeup\n8 punkter'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined),
              SizedBox(width: 12),
              Icon(Icons.delete_outline),
            ],
          ),
        ),
      ),
    );
  }
}
