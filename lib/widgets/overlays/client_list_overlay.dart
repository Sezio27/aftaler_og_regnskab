import 'package:aftaler_og_regnskab/model/client_model.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/lists/client_list.dart';
import 'package:aftaler_og_regnskab/widgets/custom_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ClientListOverlay extends StatefulWidget {
  const ClientListOverlay({
    super.key,
    required this.onPick,
    this.selectedId,
    this.closeOnPick = true,
    this.initialQuery = '',
  });

  final String? selectedId;
  final ValueChanged<ClientModel> onPick;
  final bool closeOnPick;
  final String initialQuery;

  @override
  State<ClientListOverlay> createState() => _ClientListOverlayState();
}

class _ClientListOverlayState extends State<ClientListOverlay> {
  late final TextEditingController _searchCtrl;
  late final ClientViewModel _vm;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
    _vm = context.read<ClientViewModel>();
    _vm.initClientFilters(initialQuery: widget.initialQuery);
    if (widget.initialQuery.isNotEmpty) {
      _vm.setClientSearch(widget.initialQuery);
    }
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
                  'Tilføj klient',
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
          CustomSearchBar(
            controller: _searchCtrl,
            onChanged: context.read<ClientViewModel>().setClientSearch,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClientList(
              selectedId: widget.selectedId,
              smallList: false,
              onPick: (c) {
                widget.onPick(c);
                if (widget.closeOnPick) {
                  context.pop();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
