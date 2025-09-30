import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_search_bar.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_checklist_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_service_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/show_overlay_panel.dart';
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
                  thumbColor: cs.primary,
                  onValueChanged: (v) => setState(() => _tab = v!),
                  children: {
                    Tabs.services: _SegItem(
                      icon: Icons.face_retouching_natural,
                      text: 'Services',
                      active: _tab == Tabs.services,
                    ),
                    Tabs.checklists: _SegItem(
                      icon: Icons.event_note_outlined,
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
                        ? const _ServicesGrid() // grid skeleton
                        : const _ChecklistsList(), // list skeleton
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
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegItem extends StatelessWidget {
  const _SegItem({
    required this.icon,
    required this.text,
    required this.active,
  });
  final IconData icon;
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = active ? cs.onPrimary : cs.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Text(
            text,
            style: active
                ? AppTypography.segActive.copyWith(color: fg)
                : AppTypography.segPassive.copyWith(color: fg),
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
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
            // image placeholder
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
