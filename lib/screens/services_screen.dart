import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_checklist_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_service_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/show_overlay_panel.dart';
import 'package:aftaler_og_regnskab/widgets/seg_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final mediaQuery = MediaQuery.of(context);
    final slivers = <Widget>[
      SliverSafeArea(
        bottom: false,
        sliver: SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
          sliver: SliverToBoxAdapter(
            child: CupertinoSlidingSegmentedControl<Tabs>(
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
                  icon: Icons.event_note_outlined,
                  text: 'Checklister',
                  active: _tab == Tabs.checklists,
                ),
              },
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        sliver: SliverToBoxAdapter(
          child: CupertinoSearchTextField(
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
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                  color: cs.onSurface.withAlpha(180),
                  offset: const Offset(0, 1),
                  blurRadius: 0.1,
                  blurStyle: BlurStyle.outer,
                ),
              ],
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      if (_tab == Tabs.services)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: const _ServicesGrid(),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: const _ChecklistsList(),
        ),
      SliverFillRemaining(
        hasScrollBody: false,
        child: SizedBox(height: 30 + mediaQuery.padding.bottom),
      ),
    ];

    return Stack(
      children: [
        CustomScrollView(
          slivers: slivers,
        ),
        Positioned(
          right: 16,
          bottom: 36 + mediaQuery.padding.bottom,
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
    );
  }
}

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: .80,
      ),
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(.06)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Container(color: cs.surfaceVariant.withOpacity(.5)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bryllups makeup',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text('DKK 2,000'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistsList extends StatelessWidget {
  const _ChecklistsList();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const itemCount = 6;
    final totalItems = itemCount * 2 - 1;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index.isOdd) {
            return const SizedBox(height: 12);
          }

          return Container(
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
          );
        },
        childCount: totalItems,
      ),
    );
  }
}
