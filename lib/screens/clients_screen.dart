import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_search_bar.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_checklist_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_client_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_service_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/show_overlay_panel.dart';
import 'package:aftaler_og_regnskab/widgets/seg_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

enum Tabs { private, business }

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  Tabs _tab = Tabs.private;
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
                  thumbColor: cs.secondary,
                  onValueChanged: (v) => setState(() => _tab = v!),
                  children: {
                    Tabs.private: SegItem(
                      icon: Icons.person_3_outlined,
                      text: 'Privat',
                      active: _tab == Tabs.private,
                      amount: "5",
                    ),
                    Tabs.business: SegItem(
                      icon: Icons.business_outlined,
                      text: 'Erhverv',
                      active: _tab == Tabs.business,
                      amount: "5",
                    ),
                  },
                ),

                const SizedBox(height: 12),

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
                    child: _tab == Tabs.private
                        ? const Text("Private")
                        : const Text("Erhverv"),
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
                await showOverlayPanel(
                  context: context,
                  child: const AddClientPanel(),
                );
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
