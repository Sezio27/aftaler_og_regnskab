import 'dart:typed_data';

import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/format_price.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
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
import 'package:aftaler_og_regnskab/widgets/status.dart';
import 'package:aftaler_og_regnskab/widgets/time_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class NewAppointmentScreen extends StatefulWidget {
  const NewAppointmentScreen({super.key, this.initialDate});
  final DateTime? initialDate;

  @override
  State<NewAppointmentScreen> createState() => _NewAppointmentScreenState();
}

class _NewAppointmentScreenState extends State<NewAppointmentScreen> {
  late final ClientViewModel _clientVM;
  late final ServiceViewModel _serviceVM;
  late final ChecklistViewModel _checklistVM;

  late final TextEditingController clientSearchCtrl;
  late final TextEditingController serviceSearchCtrl;
  late final TextEditingController checklistSearchCtrl;
  final _locationCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _customPriceCtrl = TextEditingController();

  PaymentStatus _status = PaymentStatus.uninvoiced;

  String? _selectedClientId;
  String? _selectedServiceId;

  final Set<String> _selectedChecklistIds = {};
  late DateTime _date;

  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);
  int? _active;
  List<({Uint8List bytes, String name, String? mimeType})> _images = [];

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
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

    final customPrice = parsePrice(_customPriceCtrl.text);

    // call the VM that resolves the final price etc.
    return await context.read<AppointmentViewModel>().addAppointment(
      clientId: _selectedClientId,
      serviceId: _selectedServiceId, // may be null
      dateTime: dateTime,
      checklistIds: _selectedChecklistIds.toList(),
      location: _locationCtrl.text,
      note: _noteCtrl.text,
      price: customPrice, // UI override (optional)
      images: _images,
      status: _status.label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clientVM = context.read<ClientViewModel>();
    final serviceVM = context.read<ServiceViewModel>();
    final checklistVM = context.read<ChecklistViewModel>();
    final isSaving = context.watch<AppointmentViewModel>().saving;

    final servicePrice = context.select<ServiceViewModel, double?>(
      (vm) => vm.priceFor(_selectedServiceId),
    );

    final priceHint = servicePrice != null
        ? formatPrice(servicePrice)
        : 'Indtast pris';

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 20),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: LayoutMetrics.horizontalPadding(context),
                  ),
                  child: TapRegion(
                    onTapOutside: (_) => _clearFocus(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ExpandableSection(
                          title: 'Vælg klient',
                          child: Column(
                            children: [
                              if (_selectedClientId == null) ...[
                                CupertinoSearchTextField(
                                  controller: clientSearchCtrl,
                                  placeholder: 'Søg',
                                  onChanged: clientVM.setClientSearch,
                                  onSubmitted: (_) =>
                                      FocusScope.of(context).unfocus(),
                                  itemColor: cs.onSurface.withAlpha(180),
                                  style: AppTypography.b2.copyWith(
                                    color: cs.onSurface,
                                  ),
                                  placeholderStyle: AppTypography.b2.copyWith(
                                    color: cs.onSurface.withAlpha(180),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.onPrimary,
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 10),
                              ],

                              ClientList(
                                selectedId: _selectedClientId,
                                onPick: (c) {
                                  setState(() => _selectedClientId = c.id);
                                },
                              ),
                              const SizedBox(height: 10),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                child: _selectedClientId != null
                                    ? TextButton.icon(
                                        onPressed: () {
                                          setState(
                                            () => _selectedClientId = null,
                                          );
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
                                          style: AppTypography.b3.copyWith(
                                            color: cs.primary,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        ExpandableSection(
                          title: 'Vælg service',
                          child: Column(
                            children: [
                              const SizedBox(height: 6),
                              if (_selectedServiceId == null) ...[
                                CupertinoSearchTextField(
                                  controller: serviceSearchCtrl,
                                  placeholder: 'Søg',
                                  onChanged: serviceVM.setServiceSearch,
                                  onSubmitted: (_) =>
                                      FocusScope.of(context).unfocus(),
                                  itemColor: cs.onSurface.withAlpha(180),
                                  style: AppTypography.b2.copyWith(
                                    color: cs.onSurface,
                                  ),
                                  placeholderStyle: AppTypography.b2.copyWith(
                                    color: cs.onSurface.withAlpha(180),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.onPrimary,
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 10),
                              ],

                              ServiceList(
                                selectedId: _selectedServiceId,
                                onPick: (s) {
                                  setState(() {
                                    _selectedServiceId = s.id;
                                    final formatted = s.price == null
                                        ? ''
                                        : formatPrice(s.price);
                                    _customPriceCtrl
                                      ..text = formatted
                                      ..selection = TextSelection.fromPosition(
                                        TextPosition(offset: formatted.length),
                                      );
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                child: _selectedServiceId != null
                                    ? TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _selectedServiceId = null;
                                            _customPriceCtrl.clear();
                                          });
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
                                          style: AppTypography.b3.copyWith(
                                            color: cs.primary,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        ExpandableSection(
                          title: 'Tilknyt checklister',
                          child: Column(
                            children: [
                              CupertinoSearchTextField(
                                controller: checklistSearchCtrl,
                                placeholder: 'Søg',
                                onChanged: checklistVM.setChecklistSearch,
                                onSubmitted: (_) =>
                                    FocusScope.of(context).unfocus(),
                                itemColor: cs.onSurface.withAlpha(180),
                                style: AppTypography.b2.copyWith(
                                  color: cs.onSurface,
                                ),
                                placeholderStyle: AppTypography.b2.copyWith(
                                  color: cs.onSurface.withAlpha(180),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.onPrimary,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

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
                              const SizedBox(height: 10),
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
                                  style: AppTypography.b3.copyWith(
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
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
                        const SizedBox(height: 45),
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
                        const SizedBox(height: 45),
                        _Section(
                          title: 'Tilpas pris (valgfri)',
                          child: SoftTextField(
                            hintText: priceHint,
                            suffixText: "DKK",
                            keyboardType: TextInputType.number,
                            hintStyle: priceHint == "Indtast pris"
                                ? null
                                : AppTypography.num6.copyWith(
                                    color: cs.onSurface.withAlpha(200),
                                  ),
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
                        const SizedBox(height: 45),
                        _Section(
                          title: 'Billeder',
                          child: ImagesPickerGrid(
                            initial: _images,
                            onChanged: (updatedImages) {
                              setState(() => _images = updatedImages);
                            },
                          ),
                        ),

                        const SizedBox(height: 45),
                        _Section(
                          title:
                              'Vælg status', // keep your section title, this row mirrors DatePicker
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: StatusChoice(
                              value: _status,
                              onChanged: (s) => setState(() => _status = s),
                            ),
                          ),
                        ),

                        const SizedBox(height: 45),
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
                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(25, 0, 25, 50),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cs.onPrimary, // filled vs unfilled
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: cs.onSurface.withAlpha(80),
                                      width: 0.6,
                                    ),
                                  ),
                                  child: CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    onPressed: () => context.pop(),
                                    child: Text(
                                      'Annuller',
                                      style: AppTypography.button2.copyWith(
                                        color: cs.primary, // text color
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cs.primary, // filled vs unfilled
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: cs.primary,
                                      width: 0.6,
                                    ),
                                  ),
                                  child: CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    onPressed: isSaving
                                        ? null
                                        : () async {
                                            final ok = await submit(context);
                                            if (!context.mounted) return;

                                            if (ok) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Aftale oprettet',
                                                  ),
                                                ),
                                              );
                                              context.pop();
                                            } else {
                                              final err =
                                                  context
                                                      .read<
                                                        AppointmentViewModel
                                                      >()
                                                      .error ??
                                                  'Ukendt fejl';
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(content: Text(err)),
                                              );
                                            }
                                          },
                                    child: Text(
                                      'Opret aftale',
                                      style: AppTypography.button2.copyWith(
                                        color: cs.onPrimary, // text color
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
                  ),
                ),
              ),
            ],
          ),
          if (isSaving) ...[
            const Positioned.fill(
              child: ModalBarrier(
                dismissible: false,
                color: Colors.black38, // dim background
              ),
            ),
            const Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(strokeWidth: 6),
                ),
              ),
            ),
          ],
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
