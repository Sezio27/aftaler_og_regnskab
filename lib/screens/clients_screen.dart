import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/client_list.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_client_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/show_overlay_panel.dart';
import 'package:aftaler_og_regnskab/widgets/seg_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

enum Tabs { private, business }

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  Tabs _tab = Tabs.private;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientViewModel>().initClientFilters();
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
    final vm = context.read<ClientViewModel>();
    final privateCount = context.select<ClientViewModel, int>(
      (v) => v.privateCount,
    );
    final businessCount = context.select<ClientViewModel, int>(
      (v) => v.businessCount,
    );

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
            sliver: SliverToBoxAdapter(
              child: CupertinoSlidingSegmentedControl<Tabs>(
                groupValue: _tab,
                backgroundColor: cs.onPrimary,
                thumbColor: cs.secondary,
                onValueChanged: (v) => setState(() => _tab = v!),
                children: {
                  Tabs.private: SegItem(
                    icon: Icons.person_3_outlined,
                    text: 'Privat',
                    active: _tab == Tabs.private,
                    amount: '$privateCount',
                  ),
                  Tabs.business: SegItem(
                    icon: Icons.business_outlined,
                    text: 'Erhverv',
                    active: _tab == Tabs.business,
                    amount: '$businessCount',
                  ),
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            sliver: SliverToBoxAdapter(
              child: CupertinoSearchTextField(
                controller: _searchCtrl,
                placeholder: 'Søg',
                onChanged: vm.setClientSearch,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                itemColor: cs.onSurface.withAlpha(150),
                style: AppTypography.b2.copyWith(color: cs.onSurface),
                placeholderStyle: AppTypography.b2.copyWith(
                  color: cs.onSurface.withAlpha(150),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.onPrimary,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  boxShadow: [
                    BoxShadow(
                      color: cs.onSurface.withAlpha(180),
                      offset: const Offset(0, 1),
                      blurRadius: 0.1,
                      spreadRadius: 1,
                      blurStyle: BlurStyle.outer,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              18,
              0,
              18,
              LayoutMetrics.navBarHeight(context) + 16,
            ),
            sliver: SliverFillRemaining(
              hasScrollBody: true,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      child: _tab == Tabs.private
                          ? ClientList(
                              onPick: (c) {
                                final id = c.id;
                                if (id == null) return;
                                context.pushNamed(
                                  'clientDetails',
                                  pathParameters: {'id': id},
                                );
                              },
                              smallList: false,
                              hasCvr: false,
                            )
                          : ClientList(
                              onPick: (c) {
                                final id = c.id;
                                if (id == null) return;
                                context.pushNamed(
                                  'clientDetails',
                                  pathParameters: {'id': id},
                                );
                              },
                              smallList: false,
                              hasCvr: true,
                            ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8, right: 16),
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
