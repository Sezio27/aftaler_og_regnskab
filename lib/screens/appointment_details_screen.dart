import 'package:aftaler_og_regnskab/model/appointmentModel.dart';
import 'package:aftaler_og_regnskab/model/checklistModel.dart';
import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/appointment_checklist_card.dart';
import 'package:aftaler_og_regnskab/widgets/client_tile.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/date_picker.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/client_list_overlay.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/show_overlay_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:aftaler_og_regnskab/widgets/status.dart';
import 'package:aftaler_og_regnskab/widgets/time_picker.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AppointmentDetailsScreen extends StatelessWidget {
  const AppointmentDetailsScreen({super.key, required this.appointmentId});
  final String appointmentId;

  @override
  Widget build(BuildContext context) {
    final appVm = context.read<AppointmentViewModel>();

    return StreamBuilder<AppointmentModel?>(
      stream: appVm.watchAppointmentById(appointmentId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Fejl: ${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointment = snap.data;
        if (appointment == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
          return const SizedBox.shrink();
        }

        return _AppointmentDetailsView(appointment: appointment);
      },
    );
  }
}

class _AppointmentDetailsView extends StatefulWidget {
  const _AppointmentDetailsView({required this.appointment});
  final AppointmentModel appointment;

  @override
  State<_AppointmentDetailsView> createState() =>
      __AppointmentDetailsViewState();
}

class __AppointmentDetailsViewState extends State<_AppointmentDetailsView> {
  late final ClientViewModel _clientVM;
  bool _editing = false;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _locationCtrl;
  late PaymentStatus _status;
  late bool _expandedStatus;
  String? _selectedClientId;
  late DateTime? _payDate;
  late DateTime? _date;
  late TimeOfDay? _time;
  int? _active;
  void _toggle() => setState(() => _expandedStatus = !_expandedStatus);
  late Map<String, Set<int>> _doneByChecklist;

  @override
  void initState() {
    super.initState();
    _clientVM = context.read<ClientViewModel>();

    _priceCtrl = TextEditingController(text: widget.appointment.price ?? '');
    _locationCtrl = TextEditingController(
      text: widget.appointment.location ?? '',
    );
    _status = PaymentStatusX.fromString(widget.appointment.status!);
    _expandedStatus = false;
    _selectedClientId = widget.appointment.clientId;
    _payDate = widget.appointment.payDate;

    final dt = widget.appointment.dateTime?.toLocal();
    if (dt != null) {
      _date = DateTime(dt.year, dt.month, dt.day);
      _time = TimeOfDay(hour: dt.hour, minute: dt.minute);
    } else {
      _date = null;
      _time = null;
    }
    _doneByChecklist = {
      for (final id in widget.appointment.checklistIds) id: <int>{},
    };
    _clientVM.prefetchClient(_selectedClientId);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _active = null);
  }

  String daDate(DateTime dt) {
    final weekday = toBeginningOfSentenceCase(DateFormat.EEEE('da').format(dt));
    final day = DateFormat('d', 'da').format(dt);
    final month = toBeginningOfSentenceCase(DateFormat.MMMM('da').format(dt));
    return '$weekday den $day $month';
  }

  String daTimeOfDay(TimeOfDay t) {
    final temp = DateTime(2020, 1, 1, t.hour, t.minute);
    return DateFormat('HH:mm', 'da').format(temp);
  }

  DateTime? get combinedDateTime {
    if (_date == null || _time == null) return null;
    return DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hPad = LayoutMetrics.horizontalPadding(context);
    final currentId = _selectedClientId ?? widget.appointment.clientId!;
    final client = context.select<ClientViewModel, ClientModel?>(
      (vm) => vm.getClient(currentId),
    );
    final checklists = context.select<ChecklistViewModel, List<ChecklistModel>>(
      (vm) => vm.allChecklists,
    );
    final selectedChecklists = checklists
        .where((c) => widget.appointment.checklistIds.contains(c.id))
        .toList();

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hPad / 2,
          20,
          hPad / 2,
          20 + LayoutMetrics.navBarHeight(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomCard(
              field: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 26,
                ),
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

                      editChild: InkWell(
                        onTap: _toggle,
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
                      value: Text(
                        _payDate != null ? daDate(_payDate!) : "---",
                        style: AppTypography.num8,
                      ),
                      editChild: DatePicker(
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
                      value: Text(
                        widget.appointment.price == null
                            ? "---"
                            : "${widget.appointment.price!} DKK",
                        style: AppTypography.num8,
                      ),
                      editChild: SizedBox(
                        width: 140,
                        child: SoftTextField(
                          hintText: widget.appointment.price == null
                              ? "---"
                              : widget.appointment.price!,
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
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 26,
                ),
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

                      if (_editing) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _selectedClientId = null);
                          },
                          label: Text(
                            'Fjern',
                            style: AppTypography.b3.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            CustomCard(
              field: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 26,
                ),
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
                      editChild: DatePicker(
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
                      value: Text(
                        _time != null ? daTimeOfDay(_time!) : "---",
                        style: AppTypography.num8,
                      ),
                      editChild: TimePicker(
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
                      value: Text(
                        widget.appointment.location == null
                            ? "---"
                            : widget.appointment.location!,
                        style: AppTypography.num8,
                      ),
                      editChild: SizedBox(
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
                      label: 'CVR',
                      value: Text(
                        client != null ? client.cvr ?? "---" : "---",
                        style: AppTypography.num8,
                      ),
                      editChild: Text(
                        client != null ? client.cvr ?? "---" : "---",
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
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 26,
                ),
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
                    if (selectedChecklists.isEmpty) ...[
                      Text(
                        'Ingen checklister tilknyttet',
                        style: AppTypography.b5.copyWith(
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ] else ...[
                      for (final c in selectedChecklists) ...[
                        AppointmentChecklistCard(
                          checklist: c,
                          completed: _doneByChecklist[c.id] ?? <int>{},
                          onChanged: (next) => setState(() {
                            _doneByChecklist[c.id!] = next;
                            // TODO: persist progress per appointment+checklist in Firestore
                          }),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            CustomCard(
              field: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 26,
                ),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            CustomCard(
              field: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 26,
                ),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: "Rediger",
                    textStyle: AppTypography.button3.copyWith(
                      color: cs.onSurface,
                    ),
                    onTap: () => setState(() => _editing = true),
                    borderRadius: 12,
                    icon: Icon(Icons.edit_outlined),
                    color: cs.onPrimary,
                    borderStroke: Border.all(color: cs.onSurface),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: CustomButton(
                    text: "Slet",
                    textStyle: AppTypography.button3.copyWith(color: cs.error),
                    onTap: () async {
                      final ok =
                          await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Slet klient?'),
                              content: const Text('Dette kan ikke fortrydes.'),
                              actions: [
                                TextButton(
                                  onPressed: () => ctx.pop(false),
                                  child: const Text('Annuller'),
                                ),
                                TextButton(
                                  onPressed: () => ctx.pop(true),
                                  child: const Text('Slet'),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (!ok) return;
                      //TODO

                      context.pop();
                    },
                    borderRadius: 12,
                    icon: Icon(Icons.delete, color: cs.error),
                    color: cs.onPrimary,
                    borderStroke: Border.all(color: cs.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowField(
    BuildContext context, {
    required String label,
    required Widget value,
    required Widget editChild,
  }) {
    final editing = _editing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: AppTypography.b9)),
          editing ? editChild : value,
        ],
      ),
    );
  }
}
