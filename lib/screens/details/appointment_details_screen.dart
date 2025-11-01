import 'dart:typed_data';
import 'package:aftaler_og_regnskab/model/appointment_model.dart';
import 'package:aftaler_og_regnskab/model/checklist_model.dart';
import 'package:aftaler_og_regnskab/model/client_model.dart';
import 'package:aftaler_og_regnskab/model/service_model.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/date_time_format.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/utils/persistence_ops.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/cards/appointment_checklist_card.dart';
import 'package:aftaler_og_regnskab/widgets/lists/client_tile.dart';
import 'package:aftaler_og_regnskab/widgets/cards/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/pickers/date_picker.dart';
import 'package:aftaler_og_regnskab/widgets/details/action_buttons.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/checklist_list_overlay.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/client_list_overlay.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/service_list_overlay.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/show_overlay_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:aftaler_og_regnskab/widgets/status.dart';
import 'package:aftaler_og_regnskab/widgets/pickers/time_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class AppointmentDetailsScreen extends StatefulWidget {
  const AppointmentDetailsScreen({super.key, required this.appointmentId});
  final String appointmentId;

  @override
  State<AppointmentDetailsScreen> createState() =>
      _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  late final AppointmentViewModel _vm;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _vm = context.read<AppointmentViewModel>();
    _vm.subscribeToAppointment(widget.appointmentId);
    _subscribed = true;
  }

  @override
  void dispose() {
    if (_subscribed) {
      _vm.unsubscribeFromAppointment(widget.appointmentId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppointmentViewModel, AppointmentModel?>(
      selector: (_, vm) => vm.getAppointment(widget.appointmentId),
      builder: (context, appointment, _) {
        if (appointment == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
          return const SizedBox.shrink();
        }

        return _AppointmentDetailsView(
          key: ValueKey(appointment.id),
          appointment: appointment,
        );
      },
    );
  }
}

class _AppointmentDetailsView extends StatefulWidget {
  const _AppointmentDetailsView({super.key, required this.appointment});
  final AppointmentModel appointment;

  @override
  State<_AppointmentDetailsView> createState() =>
      __AppointmentDetailsViewState();
}

class __AppointmentDetailsViewState extends State<_AppointmentDetailsView> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final hPad = LayoutMetrics.horizontalPadding(context);

    return SingleChildScrollView(
      key: const PageStorageKey('appointmentDetailsScroll'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hPad / 2,
          10,
          hPad / 2,
          50 + LayoutMetrics.navBarHeight(context),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _editing
              ? _AppointmentEditPane(
                  key: const ValueKey('edit'),
                  appointment: widget.appointment,
                  onCancel: () => setState(() => _editing = false),
                  onSaved: () => setState(() => _editing = false),
                )
              : _AppointmentReadPane(
                  key: const ValueKey('read'),
                  appointment: widget.appointment,
                  onEdit: () => setState(() => _editing = true),
                  onDelete: () async {
                    await handleDelete(
                      context: context,
                      componentLabel: 'Aftale',
                      onDelete: () =>
                          context.read<AppointmentViewModel>().delete(
                            widget.appointment.id!,
                            widget.appointment.status!,
                            widget.appointment.price,
                            widget.appointment.dateTime!,
                          ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _AppointmentReadPane extends StatefulWidget {
  const _AppointmentReadPane({
    super.key,
    required this.appointment,
    required this.onEdit,
    required this.onDelete,
  });
  final AppointmentModel appointment;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  State<_AppointmentReadPane> createState() => __AppointmentReadPaneState();
}

class __AppointmentReadPaneState extends State<_AppointmentReadPane> {
  late DateTime? _date;
  late TimeOfDay? _time;

  Map<String, Set<int>> _ticks = {};
  bool _loadingTicks = true;
  bool _hasUnsaved = false;
  bool _savingTicks = false;

  @override
  void initState() {
    super.initState();
    final clientId = widget.appointment.clientId;
    if (clientId != null) {
      context.read<ClientViewModel>().prefetchClient(clientId);
    }

    final serviceId = widget.appointment.serviceId;
    if (serviceId != null) {
      context.read<ServiceViewModel>().prefetchService(serviceId);
    }

    final checklistIds = widget.appointment.checklistIds;
    if (checklistIds.isNotEmpty) {
      context.read<ChecklistViewModel>().prefetchChecklists(checklistIds);
    }

    final dt = widget.appointment.dateTime?.toLocal();
    if (dt != null) {
      _date = DateTime(dt.year, dt.month, dt.day);
      _time = TimeOfDay(hour: dt.hour, minute: dt.minute);
    } else {
      _date = null;
      _time = null;
    }
    _loadTicks();
  }

  Future<void> _loadTicks() async {
    final appVm = context.read<AppointmentViewModel>();
    final server = await appVm
        .checklistProgressStream(widget.appointment.id!)
        .first;

    final ids = widget.appointment.checklistIds;
    final map = <String, Set<int>>{
      for (final id in ids) id: {...(server[id] ?? const <int>{})},
    };

    if (!mounted) return;
    setState(() {
      _ticks = map;
      _loadingTicks = false;
      _hasUnsaved = false;
    });
  }

  void _toggleTick(String checklistId, int index, bool checked) {
    if (_loadingTicks) return;
    setState(() {
      final set = _ticks[checklistId] ??= <int>{};
      if (checked) {
        set.add(index);
      } else {
        set.remove(index);
      }
      _hasUnsaved = true;
    });
  }

  Future<void> _saveTicks() async {
    if (_savingTicks || !_hasUnsaved) return;
    setState(() => _savingTicks = true);
    try {
      await context.read<AppointmentViewModel>().saveChecklistProgress(
        appointmentId: widget.appointment.id!,
        progress: _ticks,
      );
      if (!mounted) return;
      setState(() => _hasUnsaved = false);
    } finally {
      if (mounted) setState(() => _savingTicks = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientId = widget.appointment.clientId;
    final serviceId = widget.appointment.serviceId;
    final checklistIds = widget.appointment.checklistIds;
    final images = widget.appointment.imageUrls;

    final client = context.select<ClientViewModel, ClientModel?>((vm) {
      return clientId == null ? null : vm.getClient(clientId);
    });

    final service = context.select<ServiceViewModel, ServiceModel?>((vm) {
      return serviceId == null ? null : vm.getService(serviceId);
    });

    final checklists = context.select<ChecklistViewModel, List<ChecklistModel>>(
      (vm) => [
        for (final id in checklistIds)
          if (vm.getById(id) != null) vm.getById(id)!,
      ],
    );

    final isLoadingChecklists =
        checklistIds.isNotEmpty && checklists.length < checklistIds.length;

    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomCard(
          field: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.credit_card_outlined, size: 22),
                    const SizedBox(width: 10),
                    Text("Status og fakturering", style: AppTypography.b7),
                  ],
                ),
                const SizedBox(height: 20),
                _rowField(
                  context,
                  label: 'Betalingsstatus',
                  value: StatusIconRect(status: widget.appointment.status!),
                ),

                const SizedBox(height: 5),
                Divider(thickness: 0.8, color: cs.onSurface),
                const SizedBox(height: 5),
                _rowField(
                  context,
                  label: 'Betalingsdato',
                  value: Text(
                    widget.appointment.payDate != null
                        ? daDate(widget.appointment.payDate!)
                        : "---",
                    style: AppTypography.num8,
                  ),
                ),
                const SizedBox(height: 5),
                Divider(thickness: 0.8, color: cs.onSurface),
                const SizedBox(height: 5),
                _rowField(
                  context,
                  label: 'Pris',
                  value: Text(
                    widget.appointment.price == null
                        ? "---"
                        : "${widget.appointment.price!} DKK",
                    style: AppTypography.num8,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        CustomCard(
          field: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outlined, size: 22),
                    const SizedBox(width: 10),
                    Text("Klient", style: AppTypography.b7),
                  ],
                ),
                const SizedBox(height: 20),

                if (widget.appointment.clientId == null) ...[
                  Text("Ingen klient tilknyttet", style: AppTypography.b5),
                ] else ...[
                  if (client == null)
                    const SizedBox(
                      height: 90,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    ClientTile(c: client, border: false),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        CustomCard(
          field: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note_outlined, size: 22),
                    const SizedBox(width: 10),
                    Text("Aftaleoplysninger", style: AppTypography.b7),
                  ],
                ),

                const SizedBox(height: 20),

                _rowField(
                  context,
                  label: 'Dato',
                  value: Text(
                    _date != null ? daDate(_date!) : "---",
                    style: AppTypography.num8,
                  ),
                ),

                const SizedBox(height: 5),
                Divider(thickness: 0.8, color: cs.onSurface),
                const SizedBox(height: 5),

                _rowField(
                  context,
                  label: 'Tid',
                  value: Text(
                    _time != null ? daTimeOfDay(_time!) : "---",
                    style: AppTypography.num8,
                  ),
                ),

                const SizedBox(height: 5),
                Divider(thickness: 0.8, color: cs.onSurface),
                const SizedBox(height: 5),
                _rowField(
                  context,
                  label: 'Lokation',
                  value: Text(
                    widget.appointment.location == null
                        ? "---"
                        : widget.appointment.location!,
                    style: AppTypography.num8,
                  ),
                ),

                const SizedBox(height: 5),
                Divider(thickness: 0.8, color: cs.onSurface),
                const SizedBox(height: 5),

                _rowField(
                  context,
                  label: 'CVR',
                  value: Text(
                    client != null ? client.cvr ?? "---" : "---",
                    style: AppTypography.num8,
                  ),
                ),
                const SizedBox(height: 5),
                Divider(thickness: 0.8, color: cs.onSurface),
                const SizedBox(height: 5),
                _rowField(
                  context,
                  label: 'Service',
                  value: Text(
                    service?.name ?? '---',
                    style: AppTypography.num8,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        CustomCard(
          field: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.checklist, size: 22),
                    const SizedBox(width: 10),
                    Text("Checklister", style: AppTypography.b7),
                  ],
                ),
                const SizedBox(height: 20),
                if (widget.appointment.checklistIds.isEmpty) ...[
                  Text(
                    'Ingen checklister tilknyttet',
                    style: AppTypography.b5.copyWith(
                      color: cs.onSurface.withAlpha(150),
                    ),
                  ),
                ] else if (isLoadingChecklists || _loadingTicks) ...[
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text('Henter checklister…', style: AppTypography.b6),
                    ],
                  ),
                ] else ...[
                  Column(
                    children: [
                      for (final c in checklists) ...[
                        AppointmentChecklistCard(
                          checklist: c,
                          completed: _ticks[c.id!] ?? const <int>{},
                          onToggleItem: (i, checked) =>
                              _toggleTick(c.id!, i, checked),
                          editing: false,
                          onRemove: null,
                          collapse: false,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_hasUnsaved) ...[
                        const SizedBox(height: 6),
                        Align(
                          child: TextButton.icon(
                            onPressed: _savingTicks ? null : _saveTicks,
                            icon: _savingTicks
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined, size: 20),
                            label: Text(
                              'Gem ændringer',
                              style: AppTypography.h4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        CustomCard(
          field: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.image_outlined, size: 22),
                    const SizedBox(width: 10),
                    Text("Billeder", style: AppTypography.b7),
                  ],
                ),
                const SizedBox(height: 20),

                LayoutBuilder(
                  builder: (ctx, c) {
                    final cross = c.maxWidth >= 520 ? 3 : 2;
                    if (images.isEmpty) {
                      return Text(
                        'Ingen billeder tilføjet',
                        style: AppTypography.b5.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(150),
                        ),
                      );
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: images.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemBuilder: (ctx, i) => _ImageTile(url: images[i]),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        CustomCard(
          field: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.create_outlined, size: 22),
                    const SizedBox(width: 10),
                    Text("Noter", style: AppTypography.b7),
                  ],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    widget.appointment.note == null ||
                            widget.appointment.note!.isEmpty
                        ? "Ingen note"
                        : widget.appointment.note!,
                    style: AppTypography.b5.copyWith(
                      color: cs.onSurface.withAlpha(150),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        ReadActionsRow(onEdit: widget.onEdit, onDelete: widget.onDelete),
      ],
    );
  }
}

class _AppointmentEditPane extends StatefulWidget {
  const _AppointmentEditPane({
    super.key,
    required this.appointment,
    required this.onCancel,
    required this.onSaved,
  });
  final AppointmentModel appointment;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  State<_AppointmentEditPane> createState() => __AppointmentEditPaneState();
}

class __AppointmentEditPaneState extends State<_AppointmentEditPane> {
  int? _active;
  late DateTime? _payDate;
  String? _selectedClientId;
  String? _selectedServiceId;
  late Set<String> _selectedChecklistIds;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _noteCtrl;
  late PaymentStatus _status;
  late bool _expandedStatus;
  late final ClientViewModel _clientVM;
  late final ServiceViewModel _serviceVM;
  late final ChecklistViewModel _checklistVM;
  late DateTime? _date;
  late TimeOfDay? _time;
  late List<String> _currentImages;
  final bool _savingImages = false;
  late List<String> _draftImageUrls;
  final List<String> _removedImages = [];
  List<({Uint8List bytes, String name, String? mimeType})> _newImages = [];

  void _toggleStatus() => setState(() => _expandedStatus = !_expandedStatus);

  @override
  void dispose() {
    _clientVM.clearSearch();
    _serviceVM.clearSearch();
    _checklistVM.clearSearch();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
      text: widget.appointment.price?.toString() ?? '',
    );
    _locationCtrl = TextEditingController(
      text: widget.appointment.location ?? '',
    );
    _noteCtrl = TextEditingController(text: widget.appointment.note ?? '');
    _status = PaymentStatusX.fromString(widget.appointment.status ?? '');
    _expandedStatus = false;
    _payDate = widget.appointment.payDate;
    _selectedClientId = widget.appointment.clientId;
    _selectedServiceId = widget.appointment.serviceId;
    _selectedChecklistIds = {...widget.appointment.checklistIds};

    _clientVM = context.read<ClientViewModel>();
    _serviceVM = context.read<ServiceViewModel>();
    _checklistVM = context.read<ChecklistViewModel>();

    if (_selectedClientId != null && _selectedClientId!.isNotEmpty) {
      _clientVM.prefetchClient(_selectedClientId!);
    }
    if ((_selectedServiceId ?? '').isNotEmpty) {
      _serviceVM.prefetchService(_selectedServiceId!);
    }
    _checklistVM.prefetchChecklists(widget.appointment.checklistIds);

    final dt = widget.appointment.dateTime?.toLocal();
    if (dt != null) {
      _date = DateTime(dt.year, dt.month, dt.day);
      _time = TimeOfDay(hour: dt.hour, minute: dt.minute);
    } else {
      _date = null;
      _time = null;
    }

    _currentImages = List<String>.from(widget.appointment.imageUrls);
    _draftImageUrls = List<String>.from(_currentImages);
    _newImages = [];
  }

  DateTime? _combinedDateTime() {
    if (_date == null || _time == null) return null;
    return DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
  }

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _active = null);
  }

  void _removeChecklistLocal(String id) {
    setState(() {
      _selectedChecklistIds.remove(id);
    });
  }

  void _removeDraftUrlAt(int i) {
    setState(() {
      _removedImages.add(_draftImageUrls[i]);
      _draftImageUrls.removeAt(i);
    });
  }

  void _removeNewLocalAt(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Future<void> _addImagesStaged() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty || !mounted) return;

    final newImages = <({Uint8List bytes, String name, String? mimeType})>[];
    for (final p in picked) {
      final bytes = await p.readAsBytes();
      final name = p.name.isNotEmpty
          ? p.name
          : '${DateTime.now().millisecondsSinceEpoch}.jpg';
      newImages.add((
        bytes: bytes,
        name: name,
        mimeType: p.mimeType ?? 'image/jpeg',
      ));
    }

    setState(() => _newImages.addAll(newImages));
  }

  Future<void> _save() async {
    final priceText = _priceCtrl.text.trim();
    double? customPrice;
    if (priceText.isNotEmpty) {
      customPrice = double.tryParse(priceText.replaceAll(',', '.'));
    }

    await handleSave(
      context: context,
      validate: () {
        final noClient =
            _selectedClientId == null || _selectedClientId!.trim().isEmpty;
        if (noClient) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Vælg en kunde, før du gemmer.'),
            ),
          );
          return 'Mangler kunde';
        }
        return null;
      },
      onSave: () =>
          context.read<AppointmentViewModel>().updateAppointmentFields(
            widget.appointment,
            clientId: _selectedClientId,
            serviceId: _selectedServiceId ?? '',
            checklistIds: _selectedChecklistIds.toList(),
            dateTime: _combinedDateTime(),
            payDate: _payDate,
            location: _locationCtrl.text,
            note: _noteCtrl.text,
            price: customPrice ?? 0.0,
            status: _status.label,
            currentImageUrls: _currentImages, // original URLs from initState
            removedImageUrls: _removedImages, // URLs user removed in UI
            newImages: _newImages,
          ),

      errorText: () =>
          context.read<AppointmentViewModel>().error ?? 'Ukendt fejl',
      onSuccess: widget.onSaved, // flips back to read mode
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final client = context.select<ClientViewModel, ClientModel?>((vm) {
      return _selectedClientId == null
          ? null
          : vm.getClient(_selectedClientId!);
    });
    final service = context.select<ServiceViewModel, ServiceModel?>((vm) {
      return _selectedServiceId == null
          ? null
          : vm.getService(_selectedServiceId!);
    });

    final checklists = context.select<ChecklistViewModel, List<ChecklistModel>>(
      (vm) => [
        for (final id in _selectedChecklistIds)
          if (vm.getById(id) != null) vm.getById(id)!,
      ],
    );

    final isLoadingChecklists =
        _selectedChecklistIds.isNotEmpty &&
        checklists.length < _selectedChecklistIds.length;

    return TapRegion(
      onTapInside: (_) => _clearFocus(),
      onTapOutside: (_) => _clearFocus(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomCard(
            field: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.credit_card_outlined, size: 22),
                      const SizedBox(width: 10),
                      Text("Status og fakturering", style: AppTypography.b7),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _rowField(
                    context,
                    label: 'Betalingsstatus',
                    value: InkWell(
                      onTap: _toggleStatus,
                      child: StatusIconRect(status: _status.label),
                    ),
                  ),
                  _expandedStatus
                      ? Column(
                          children: [
                            const SizedBox(height: 20),
                            StatusChoice(
                              value: _status,
                              onChanged: (s) {
                                setState(() {
                                  _status = s;
                                  _expandedStatus = false;
                                });
                              },
                            ),
                            const SizedBox(height: 5),
                          ],
                        )
                      : const SizedBox.shrink(),

                  const SizedBox(height: 5),
                  Divider(thickness: 0.8, color: cs.onSurface),
                  const SizedBox(height: 5),

                  _rowField(
                    context,
                    label: 'Betalingsdato',
                    value: DatePicker(
                      value: _payDate,
                      minimumDate: DateTime(2000),
                      maximumDate: DateTime(2100),
                      displayFormat: daDate,
                      onChanged: (d) => setState(() => _payDate = d),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Divider(thickness: 0.8, color: cs.onSurface),
                  const SizedBox(height: 5),
                  _rowField(
                    context,
                    label: 'Pris',
                    value: SizedBox(
                      width: 140,
                      child: SoftTextField(
                        hintText: widget.appointment.price == null
                            ? "---"
                            : '${widget.appointment.price!}',
                        suffixText: "DKK",
                        keyboardType: TextInputType.number,
                        hintStyle: AppTypography.num6,
                        controller: _priceCtrl,
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
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          CustomCard(
            field: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outlined, size: 22),
                      const SizedBox(width: 10),
                      Text("Klient", style: AppTypography.b7),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_selectedClientId == null) ...[
                    TextButton.icon(
                      onPressed: () async {
                        await showOverlayPanel(
                          context: context,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 40,
                              horizontal: 25,
                            ),
                            child: ClientListOverlay(
                              selectedId: _selectedClientId,
                              onPick: (c) {
                                setState(() => _selectedClientId = c.id);
                              },
                            ),
                          ),
                        );
                        if (!mounted) return;
                      },
                      icon: const Icon(Icons.add),
                      label: Text(
                        'Tilføj klient',
                        style: AppTypography.b3.copyWith(color: cs.primary),
                      ),
                    ),
                  ] else ...[
                    if (client == null)
                      const SizedBox(
                        height: 90,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      ClientTile(c: client, border: false),

                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _selectedClientId = null);
                      },
                      label: Text(
                        'Fjern',
                        style: AppTypography.b3.copyWith(color: cs.onSurface),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          CustomCard(
            field: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_note_outlined, size: 22),
                      const SizedBox(width: 10),
                      Text("Aftaleoplysninger", style: AppTypography.b7),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _rowField(
                    context,
                    label: 'Dato',
                    value: DatePicker(
                      value: _date,
                      minimumDate: DateTime(2000),
                      maximumDate: DateTime(2100),
                      displayFormat: daDate,
                      onChanged: (d) => setState(
                        () => _date = DateTime(d.year, d.month, d.day),
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),
                  Divider(thickness: 0.8, color: cs.onSurface),
                  const SizedBox(height: 5),

                  _rowField(
                    context,
                    label: 'Tid',
                    value: TimePicker(
                      value: _time,
                      onChanged: (t) => setState(() => _time = t),
                    ),
                  ),

                  const SizedBox(height: 5),
                  Divider(thickness: 0.8, color: cs.onSurface),
                  const SizedBox(height: 5),

                  _rowField(
                    context,
                    label: 'Lokation',
                    value: SizedBox(
                      width: 200,
                      child: SoftTextField(
                        hintText: widget.appointment.location == null
                            ? "---"
                            : widget.appointment.location!,
                        hintStyle: AppTypography.num6.copyWith(),
                        controller: _locationCtrl,
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
                  ),

                  const SizedBox(height: 5),
                  Divider(thickness: 0.8, color: cs.onSurface),
                  const SizedBox(height: 5),

                  _rowField(
                    context,
                    label: 'Service',
                    value: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedServiceId != null && service != null) ...[
                          Text(service.name ?? '—', style: AppTypography.num8),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Fjern service',
                            icon: Icon(Icons.close, color: cs.error),
                            onPressed: () {
                              setState(() {
                                _selectedServiceId = null;
                              });
                            },
                          ),
                        ] else
                          TextButton.icon(
                            onPressed: () async {
                              await showOverlayPanel(
                                context: context,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 40,
                                    horizontal: 25,
                                  ),
                                  child: ServiceListOverlay(
                                    selectedId: _selectedServiceId,
                                    onPick: (s) {
                                      setState(() {
                                        _selectedServiceId = s.id;
                                      });
                                    },
                                  ),
                                ),
                              );
                              if (!mounted) return;
                            },
                            icon: const Icon(Icons.add),
                            label: Text(
                              'Tilføj service',
                              style: AppTypography.b3.copyWith(
                                color: cs.primary,
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
          const SizedBox(height: 14),
          CustomCard(
            field: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist, size: 22),
                      const SizedBox(width: 10),
                      Text("Checklister", style: AppTypography.b7),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_selectedChecklistIds.isEmpty) ...[
                    Text(
                      'Ingen checklister tilknyttet',
                      style: AppTypography.b5.copyWith(
                        color: cs.onSurface.withAlpha(150),
                      ),
                    ),
                  ] else if (isLoadingChecklists) ...[
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text('Henter checklister…', style: AppTypography.b6),
                      ],
                    ),
                  ] else ...[
                    Column(
                      children: [
                        for (final c in checklists) ...[
                          AppointmentChecklistCard(
                            checklist: c,
                            editing: true,
                            onRemove: () => _removeChecklistLocal(c.id!),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Tilføj checkliste'),
                      onPressed: () async {
                        await showOverlayPanel(
                          context: context,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 40,
                              horizontal: 25,
                            ),
                            child: ChecklistListOverlay(
                              initialSelectedIds: _selectedChecklistIds,
                              onDone: (newSelection) async {
                                if (!mounted) return;
                                setState(
                                  () =>
                                      _selectedChecklistIds = {...newSelection},
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          CustomCard(
            field: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.image_outlined, size: 22),
                      const SizedBox(width: 10),
                      Text("Billeder", style: AppTypography.b7),
                    ],
                  ),
                  const SizedBox(height: 20),

                  LayoutBuilder(
                    builder: (ctx, c) {
                      final cross = c.maxWidth >= 520 ? 3 : 2;
                      final total = _draftImageUrls.length + _newImages.length;

                      if (total == 0) {
                        return Text(
                          'Ingen billeder tilføjet',
                          style: AppTypography.b5.copyWith(
                            color: cs.onSurface.withAlpha(150),
                          ),
                        );
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: total,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemBuilder: (ctx, i) {
                          if (i < _draftImageUrls.length) {
                            final url = _draftImageUrls[i];
                            return _ImageTile(
                              url: url,
                              canRemove: true,
                              onRemove: () => _removeDraftUrlAt(i),
                            );
                          } else {
                            final j = i - _draftImageUrls.length;
                            final img = _newImages[j];
                            return _ImageTile(
                              bytes: img.bytes,
                              canRemove: true,
                              onRemove: () => _removeNewLocalAt(j),
                            );
                          }
                        },
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _savingImages ? null : _addImagesStaged,
                        icon: _savingImages
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: const Text('Tilføj billeder'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          CustomCard(
            field: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.create_outlined, size: 22),
                      const SizedBox(width: 10),
                      Text("Noter", style: AppTypography.b7),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SoftTextField(
                      hintText: "Tilføj note til denne aftale",
                      controller: _noteCtrl,
                      maxLines: 3,
                      fill: cs.onPrimary,
                      strokeColor: _active != 3
                          ? cs.onSurface.withAlpha(50)
                          : cs.primary,
                      strokeWidth: _active != 3 ? 1 : 1.5,
                      borderRadius: 8,
                      showStroke: true,
                      onTap: () => setState(() => _active = 3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          Selector<AppointmentViewModel, bool>(
            selector: (_, vm) => vm.saving,
            builder: (context, saving, _) => EditActionsRow(
              saving: saving,
              onCancel: widget.onCancel,
              onConfirm: _save,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    this.url,
    this.bytes,
    this.onRemove,
    this.canRemove = false,
  });
  final String? url;
  final Uint8List? bytes;
  final VoidCallback? onRemove;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          bytes != null
              ? Image.memory(
                  bytes!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Colors.black12),
                )
              : Image.network(url!, fit: BoxFit.cover),
          if (canRemove)
            Positioned(
              right: 6,
              top: 6,
              child: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: cs.surface.withOpacity(.9),
                  padding: EdgeInsets.zero,
                ),
                tooltip: 'Fjern',
              ),
            ),
        ],
      ),
    );
  }
}

Widget _rowField(
  BuildContext context, {
  required String label,
  required Widget value,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: AppTypography.b9)),
        value,
      ],
    ),
  );
}
