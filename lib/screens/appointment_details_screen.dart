import 'package:aftaler_og_regnskab/model/appointmentModel.dart';
import 'package:aftaler_og_regnskab/model/checklistModel.dart';
import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/model/serviceModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/appointment_checklist_card.dart';
import 'package:aftaler_og_regnskab/widgets/client_tile.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/date_picker.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/checklist_list_overlay.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/client_list_overlay.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/service_list_overlay.dart';
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
  String? _selectedServiceId;
  late DateTime? _payDate;
  late DateTime? _date;
  late TimeOfDay? _time;
  int? _active;
  void _toggle() => setState(() => _expandedStatus = !_expandedStatus);

  final Map<String, Map<int, bool>> _localCheckpointOverrides = {};
  Map<String, Set<int>> _lastServerProgress = {};
  bool _hasStagedChanges = false;
  bool _collapseChecklists = false;
  bool _saving = false;

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
    _selectedServiceId = widget.appointment.serviceId;
    _payDate = widget.appointment.payDate;

    final dt = widget.appointment.dateTime?.toLocal();
    if (dt != null) {
      _date = DateTime(dt.year, dt.month, dt.day);
      _time = TimeOfDay(hour: dt.hour, minute: dt.minute);
    } else {
      _date = null;
      _time = null;
    }
    _clientVM.prefetchClient(_selectedClientId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final clVm = context.read<ChecklistViewModel>();

      clVm.ensureSubscribedToAll();
      // Best-effort: make sure the ones used by this appointment are in cache
      clVm.prefetchByIds(widget.appointment.checklistIds);

      final svcVm = context.read<ServiceViewModel>();
      svcVm.initServiceFilters();
      final sid = _selectedServiceId;
      if ((sid ?? '').isNotEmpty) {
        svcVm.prefetchById(sid!); // no-op if already cached
      }
    });
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

  Set<int> _withOverrides(String checklistId, Set<int> server) {
    final base = <int>{...server};
    final ov = _localCheckpointOverrides[checklistId];
    if (ov == null) return base;
    ov.forEach((i, isChecked) {
      if (isChecked) {
        base.add(i);
      } else {
        base.remove(i);
      }
    });
    return base;
  }

  void _togglePointLocal(String checklistId, int index, bool nowChecked) {
    setState(() {
      (_localCheckpointOverrides[checklistId] ??= {})[index] = nowChecked;
      _hasStagedChanges = true;
    });
  }

  Map<String, Set<int>> _resolvedProgress() {
    // start with server state
    final result = <String, Set<int>>{
      for (final e in _lastServerProgress.entries) e.key: {...e.value},
    };
    // apply local overrides
    _localCheckpointOverrides.forEach((cid, edits) {
      final set = result[cid] ?? <int>{};
      edits.forEach((i, v) => v ? set.add(i) : set.remove(i));
      result[cid] = set;
    });
    return result;
  }

  Future<void> _saveChecklistProgress() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final payload = _resolvedProgress();
      await context
          .read<AppointmentViewModel>()
          .setAllChecklistProgressOnParent(
            appointmentId: widget.appointment.id!,
            progress: payload,
          );
      if (!mounted) return;
      setState(() {
        _localCheckpointOverrides.clear();
        _hasStagedChanges = false;
        _collapseChecklists = !_collapseChecklists;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeChecklist(String checklistId) async {
    final current = widget.appointment.checklistIds.toSet();
    if (!current.contains(checklistId)) return;

    final next = {...current}..remove(checklistId);

    await context.read<AppointmentViewModel>().setChecklistSelection(
      appointmentId: widget.appointment.id!,
      newSelection: next,
      removedIds: {checklistId}, // ensures server progress.<id> is deleted
    );

    // ⬇️ Clear any staged local overrides for this checklist so UI shows 0%
    if (!mounted) return;
    setState(() {
      _localCheckpointOverrides.remove(checklistId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hPad = LayoutMetrics.horizontalPadding(context);
    final currentClientId = _selectedClientId ?? widget.appointment.clientId!;
    final client = context.select<ClientViewModel, ClientModel?>(
      (vm) => vm.getClient(currentClientId),
    );

    final currentServiceId =
        (_selectedServiceId ?? widget.appointment.serviceId) ?? '';

    final service = context.select<ServiceViewModel, ServiceModel?>(
      (vm) => vm.getById(currentServiceId),
    );

    final clVm = context.watch<ChecklistViewModel>();
    final checklistIds = widget.appointment.checklistIds;

    final selectedChecklists = <ChecklistModel>[
      for (final id in checklistIds)
        if (clVm.getById(id) != null) clVm.getById(id)!,
    ];

    final isLoadingChecklists =
        checklistIds.isNotEmpty &&
        selectedChecklists.length < checklistIds.length;

    var addChecklist = [
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Tilføj checkliste'),
          onPressed: () async {
            final current = widget.appointment.checklistIds.toSet();
            await showOverlayPanel(
              context: context,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 25,
                ),
                child: ChecklistListOverlay(
                  initialSelectedIds: widget.appointment.checklistIds.toSet(),
                  onDone: (newSelection, resetIds) async {
                    final current = widget.appointment.checklistIds.toSet();
                    final removed = current.difference(newSelection);

                    await context
                        .read<AppointmentViewModel>()
                        .setChecklistSelection(
                          appointmentId: widget.appointment.id!,
                          newSelection: newSelection,
                          removedIds: removed,
                          resetProgressIds: resetIds,
                        );

                    if (!mounted) return;

                    // ⬇️ Clear staged local overrides locally so re-added lists start at 0%
                    setState(() {
                      for (final id in removed) {
                        _localCheckpointOverrides.remove(id);
                      }
                      for (final id in resetIds) {
                        _localCheckpointOverrides.remove(id);
                      }
                    });

                    context.read<ChecklistViewModel>().prefetchByIds(
                      newSelection.toList(),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    ];

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
                      editChild: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedServiceId != null &&
                              service != null) ...[
                            Text(
                              service.name ?? '—',
                              style: AppTypography.num8,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Fjern service',
                              icon: Icon(Icons.close, color: cs.error),
                              onPressed: () {
                                setState(() {
                                  _selectedServiceId = null;
                                  _hasStagedChanges =
                                      true; // show "Gem ændringer"
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
                                          _selectedServiceId =
                                              s.id; // stage selection
                                          _hasStagedChanges =
                                              true; // show "Gem ændringer"
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
                    if (checklistIds.isEmpty) ...[
                      Text(
                        'Ingen checklister tilknyttet',
                        style: AppTypography.b5.copyWith(
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),

                      if (_editing) ...addChecklist,
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
                      StreamBuilder<Map<String, Set<int>>>(
                        stream: context
                            .read<AppointmentViewModel>()
                            .watchChecklistProgressOnParent(
                              widget.appointment.id!,
                            ),
                        builder: (context, snap) {
                          final server =
                              snap.data ?? const <String, Set<int>>{};

                          // cache latest server state for resolving + saving
                          _lastServerProgress = server;

                          // keep your existing post-frame cleanup so overrides drop
                          // once server matches local changes
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            bool changed = false;
                            final outerKeys = List<String>.from(
                              _localCheckpointOverrides.keys,
                            );
                            for (final cid in outerKeys) {
                              final map = _localCheckpointOverrides[cid];
                              if (map == null) continue;
                              final eff = server[cid] ?? <int>{};
                              final innerKeys = List<int>.from(map.keys);
                              for (final i in innerKeys) {
                                final v = map[i]!;
                                final matchesServer =
                                    (v && eff.contains(i)) ||
                                    (!v && !eff.contains(i));
                                if (matchesServer) {
                                  map.remove(i);
                                  changed = true;
                                }
                              }
                              if (map.isEmpty) {
                                _localCheckpointOverrides.remove(cid);
                                changed = true;
                              }
                            }
                            if (changed) {
                              setState(() {});
                            }
                          });

                          return Column(
                            children: [
                              for (final c in selectedChecklists) ...[
                                AppointmentChecklistCard(
                                  checklist: c,
                                  completed: _withOverrides(
                                    c.id!,
                                    server[c.id!] ?? <int>{},
                                  ),
                                  onToggleItem: (index, nowChecked) =>
                                      _togglePointLocal(
                                        c.id!,
                                        index,
                                        nowChecked,
                                      ),

                                  collapse: _collapseChecklists,
                                  editing: _editing, // << NEW
                                  onRemove: _editing
                                      ? () =>
                                            _removeChecklist(c.id!) // << NEW
                                      : null,
                                ),
                                const SizedBox(height: 12),
                              ],

                              // ▼▼ NEW: Save button appears only when dirty ▼▼
                              if (_hasStagedChanges) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _saving
                                        ? null
                                        : _saveChecklistProgress,
                                    icon: _saving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.save_outlined),
                                    label: const Text('Gem ændringer'),
                                  ),
                                ),
                              ],

                              if (_editing) ...addChecklist,
                            ],
                          );
                        },
                      ),
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
