import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/checklist_list.dart';
import 'package:aftaler_og_regnskab/widgets/client_list.dart';
import 'package:aftaler_og_regnskab/widgets/custom_search_bar.dart';
import 'package:aftaler_og_regnskab/widgets/date_picker.dart';
import 'package:aftaler_og_regnskab/widgets/expandable_section.dart';
import 'package:aftaler_og_regnskab/widgets/images_picker_grid.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_checklist_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_client_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_service_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/show_overlay_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:aftaler_og_regnskab/widgets/service_list.dart';
import 'package:aftaler_og_regnskab/widgets/time_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class NewAppointmentScreen extends StatefulWidget {
  const NewAppointmentScreen({super.key});

  @override
  State<NewAppointmentScreen> createState() => _NewAppointmentScreenState();
}

class _NewAppointmentScreenState extends State<NewAppointmentScreen> {
  final _formKey = GlobalKey<_NewAppointmentFormState>();

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
                child: NewAppointmentForm(key: _formKey),
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
                    onPressed: () async {
                      final ok =
                          await _formKey.currentState?.submit(context) ??
                          false; // <-- call form
                      if (!context.mounted) return;

                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Aftale oprettet')),
                        );
                        context.pop();
                      } else {
                        final err =
                            context.read<AppointmentViewModel>().error ??
                            'Ukendt fejl';
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(err)));
                      }
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
  late final ClientViewModel _clientVM;
  late final ServiceViewModel _serviceVM;
  late final ChecklistViewModel _checklistVM;

  late final TextEditingController clientSearchCtrl;
  late final TextEditingController serviceSearchCtrl;
  late final TextEditingController checklistSearchCtrl;
  final _locationCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _customPriceCtrl = TextEditingController();

  static const List<String> _statusList = [
    'Betalt',
    'Afventer',
    'Forfalden',
    'Ufaktureret',
  ];
  String _status = 'Ufaktureret';

  String? _selectedClientId;
  String? _selectedServiceId;

  final Set<String> _selectedChecklistIds = {};

  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);
  int? _active;
  List<XFile> _images = [];

  @override
  void initState() {
    super.initState();
    _clientVM = context.read<ClientViewModel>();
    _serviceVM = context.read<ServiceViewModel>();
    _checklistVM = context.read<ChecklistViewModel>();
    clientSearchCtrl = TextEditingController();
    serviceSearchCtrl = TextEditingController();
    checklistSearchCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clientVM.initClientFilters();
      _serviceVM.initServiceFilters();
      _checklistVM.initChecklistFilters();
    });
  }

  @override
  void dispose() {
    _clientVM.clearSearch();
    _serviceVM.clearSearch();
    _checklistVM.clearSearch();
    clientSearchCtrl.dispose();
    serviceSearchCtrl.dispose();
    checklistSearchCtrl.dispose();
    _locationCtrl.dispose();
    _noteCtrl.dispose();
    _customPriceCtrl.dispose();
    super.dispose();
  }

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _active = null);
  }

  DateTime _combine(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  Future<bool> submit(BuildContext context) async {
    final dateTime = _combine(_date, _time);

    // call the VM that resolves the final price etc.
    return await context.read<AppointmentViewModel>().addAppointment(
      clientId: _selectedClientId,
      serviceId: _selectedServiceId, // may be null
      dateTime: dateTime,
      checklistIds: _selectedChecklistIds.toList(),
      location: _locationCtrl.text,
      note: _noteCtrl.text,
      customPriceText: _customPriceCtrl.text, // UI override (optional)
      images: _images,
      status: _status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clientVM = context.read<ClientViewModel>();
    final serviceVM = context.read<ServiceViewModel>();
    final checklistVM = context.read<ChecklistViewModel>();

    final servicePrice = context.select<ServiceViewModel, String?>(
      (vm) => vm.priceFor(_selectedServiceId),
    );

    final priceHint = servicePrice != null && servicePrice.isNotEmpty
        ? 'Standard pris: $servicePrice'
        : 'Indtast pris';

    return TapRegion(
      onTapOutside: (_) => _clearFocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExpandableSection(
            initiallyExpanded: true,
            title: 'Vælg klient',
            child: Column(
              children: [
                CustomSearchBar(
                  controller: clientSearchCtrl,
                  onChanged: clientVM.setClientSearch,
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _selectedClientId != null
                      ? TextButton.icon(
                          onPressed: () {
                            setState(() => _selectedClientId = null);
                          },
                          label: Text(
                            'Fotryd',
                            style: AppTypography.b3.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                        )
                      : TextButton.icon(
                          onPressed: () async {
                            await showOverlayPanel(
                              context: context,
                              child: const AddClientPanel(),
                            );
                            if (!mounted) return;
                          },
                          icon: const Icon(Icons.add),
                          label: Text(
                            'Tilføj ny klient',
                            style: AppTypography.b3.copyWith(color: cs.primary),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ExpandableSection(
            title: 'Vælg service',
            initiallyExpanded: false,
            child: Column(
              children: [
                const SizedBox(height: 6),
                CustomSearchBar(
                  controller: serviceSearchCtrl,
                  onChanged: serviceVM.setServiceSearch,
                ),
                const SizedBox(height: 10),

                //Her
                ServiceList(
                  selectedId: _selectedServiceId,
                  onPick: (s) {
                    setState(() => _selectedServiceId = s.id);
                    // TODO: store c (or id) on the appointment draft if needed
                  },
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _selectedServiceId != null
                      ? TextButton.icon(
                          onPressed: () {
                            setState(() => _selectedServiceId = null);
                          },
                          label: Text(
                            'Fotryd',
                            style: AppTypography.b3.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                        )
                      : TextButton.icon(
                          onPressed: () async {
                            await showOverlayPanel(
                              context: context,
                              child: const AddServicePanel(),
                            );
                            if (!mounted) return;
                          },
                          icon: const Icon(Icons.add),
                          label: Text(
                            'Tilføj ny service',
                            style: AppTypography.b3.copyWith(color: cs.primary),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ExpandableSection(
            title: 'Tilknyt checklister',
            child: Column(
              children: [
                CustomSearchBar(
                  controller: checklistSearchCtrl,
                  onChanged: checklistVM.setChecklistSearch,
                ),
                const SizedBox(height: 10),
                //TODO
                ChecklistList(
                  selectedIds: _selectedChecklistIds,
                  onToggle: (item, nowSelected) {
                    setState(() {
                      final id = item.id!;
                      if (nowSelected) {
                        _selectedChecklistIds.add(id);
                      } else {
                        _selectedChecklistIds.remove(id);
                      }
                    });
                  },
                ),

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
          const SizedBox(height: 30),
          _Section(
            title: 'Vælg lokation',
            child: SoftTextField(
              hintText: "Indtast addresse",
              controller: _locationCtrl,
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
          const SizedBox(height: 30),
          _Section(
            title: 'Tilpas pris (valgfri)',
            child: SoftTextField(
              hintText: priceHint,
              controller: _customPriceCtrl,
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
          const SizedBox(height: 30),
          _Section(
            title: 'Billeder',
            child: ImagesPickerGrid(
              initial: _images,
              onChanged: (files) => setState(() => _images = files),
            ),
          ),
          const SizedBox(height: 30),
          _Section(
            title: 'Note (valgfri)',
            child: SoftTextField(
              hintText: "Tilføj note til denne aftale",
              controller: _noteCtrl,
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

          const SizedBox(height: 16),
          _Section(
            title:
                'Vælg tidspunkt', // keep your section title, this row mirrors DatePicker
            child: Row(
              children: [
                Text("Status:", style: AppTypography.button2),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    items: _statusList
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v ?? _status),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    isDense: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.onPrimary,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(50),
                          width: 1,
                        ),
                      ),
                    ),
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
