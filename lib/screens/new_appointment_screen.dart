import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/client_list.dart';
import 'package:aftaler_og_regnskab/widgets/custom_search_bar.dart';
import 'package:aftaler_og_regnskab/widgets/date_picker.dart';
import 'package:aftaler_og_regnskab/widgets/images_picker_grid.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_checklist_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_client_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_service_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/show_overlay_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:aftaler_og_regnskab/widgets/time_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class NewAppointmentScreen extends StatelessWidget {
  const NewAppointmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 8),
                Text('Ny aftale', style: AppTypography.h2),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: const NewAppointmentForm(),
              ),
            ),
          ),

          // Sticky bottom actions
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: cs.surface,
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  color: Colors.black.withOpacity(0.06),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Annuller'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // TODO: validate + save
                    },
                    child: const Text('Opret aftale'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NewAppointmentForm extends StatefulWidget {
  const NewAppointmentForm({super.key});

  @override
  State<NewAppointmentForm> createState() => _NewAppointmentFormState();
}

class _NewAppointmentFormState extends State<NewAppointmentForm> {
  late final TextEditingController clientSearchCtrl;
  late final TextEditingController serviceSearchCtrl;
  String? _selectedClientId;

  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);
  int? _active;
  List<XFile> _images = [];

  @override
  void initState() {
    super.initState();
    clientSearchCtrl = TextEditingController();
    serviceSearchCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientViewModel>().initClientFilters();
    });
  }

  @override
  void dispose() {
    context.read<ClientViewModel>().clearSearch();
    clientSearchCtrl.dispose();
    serviceSearchCtrl.dispose();
    super.dispose();
  }

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _active = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.read<ClientViewModel>();

    return TapRegion(
      onTapOutside: (_) => _clearFocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            title: 'Vælg klient',
            child: Column(
              children: [
                CustomSearchBar(
                  controller: clientSearchCtrl,
                  onChanged: vm.setClientSearch,
                ),
                const SizedBox(height: 10),

                ClientList(
                  selectedId: _selectedClientId,
                  onPick: (c) {
                    setState(() => _selectedClientId = c.id);
                    // TODO: store c (or id) on the appointment draft if needed
                  },
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () async {
                    await showOverlayPanel(
                      context: context,
                      child: const AddClientPanel(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Tilføj ny klient',
                    style: AppTypography.b3.copyWith(color: cs.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Vælg service',
            child: Column(
              children: [
                CustomSearchBar(controller: serviceSearchCtrl),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () async {
                    await showOverlayPanel(
                      context: context,
                      child: const AddServicePanel(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Tilføj ny service',
                    style: AppTypography.b3.copyWith(color: cs.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Tilknyt checklister',
            child: Column(
              children: [
                CustomSearchBar(controller: serviceSearchCtrl),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () async {
                    await showOverlayPanel(
                      context: context,
                      child: const AddChecklistPanel(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Tilføj ny checkliste',
                    style: AppTypography.b3.copyWith(color: cs.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Vælg tidspunkt',
            child: Row(
              children: [
                Text("Dato:", style: AppTypography.button2),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: DatePicker(
                    value: _date,
                    minimumDate: DateTime(2000),
                    maximumDate: DateTime(2100),
                    onChanged: (d) => setState(() => _date = d),
                  ),
                ),
                const SizedBox(width: 20),
                Text("Tid:", style: AppTypography.button2),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TimePicker(
                    value: _time,
                    onChanged: (t) => setState(() => _time = t),
                    use24h: true,
                    modalHeight: 320,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Vælg lokation',
            child: SoftTextField(
              hintText: "Indtast addresse",
              fill: cs.onPrimary,
              strokeColor: _active != 0
                  ? cs.onSurface.withAlpha(50)
                  : cs.primary,
              strokeWidth: _active != 0 ? 1 : 1.5,
              borderRadius: 8,
              showStroke: true,
              onTap: () => setState(() => _active = 0),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Tilpas pris (valgfri)',
            child: SoftTextField(
              hintText:
                  "Standard pris: ", //insert price of service if selected otherwise "indtast pris"
              fill: cs.onPrimary,
              strokeColor: _active != 1
                  ? cs.onSurface.withAlpha(50)
                  : cs.primary,
              strokeWidth: _active != 1 ? 1 : 1.5,
              borderRadius: 8,
              showStroke: true,
              onTap: () => setState(() => _active = 1),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Billeder',
            child: ImagesPickerGrid(
              initial: _images,
              onChanged: (files) => setState(() => _images = files),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Note (valgfri)',
            child: SoftTextField(
              hintText: "Tilføj note til denne aftale",
              maxLines: 3,
              fill: cs.onPrimary,
              strokeColor: _active != 2
                  ? cs.onSurface.withAlpha(50)
                  : cs.primary,
              strokeWidth: _active != 2 ? 1 : 1.5,
              borderRadius: 8,
              showStroke: true,
              onTap: () => setState(() => _active = 2),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h3),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
