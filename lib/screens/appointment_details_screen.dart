import 'dart:io';

import 'package:aftaler_og_regnskab/model/appointmentModel.dart';
import 'package:aftaler_og_regnskab/model/checklistModel.dart';
import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/model/serviceModel.dart';
import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/date_time_format.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/utils/persistence_ops.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/appointment_checklist_card.dart';
import 'package:aftaler_og_regnskab/widgets/client_tile.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/date_picker.dart';
import 'package:aftaler_og_regnskab/widgets/details/action_buttons.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/checklist_list_overlay.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/client_list_overlay.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/service_list_overlay.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/show_overlay_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:aftaler_og_regnskab/widgets/status.dart';
import 'package:aftaler_og_regnskab/widgets/time_picker.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
          hPad,
          10,
          hPad,
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
                      onDelete: () => context
                          .read<AppointmentViewModel>()
                          .delete(widget.appointment.id!),
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

  // Read-pane state
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
      context.read<ChecklistViewModel>().prefetchByIds(checklistIds);
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
                  Text('Ingen checklister tilknyttet', style: AppTypography.b5),
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
                    style: AppTypography.b5,
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
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    this.url,
    this.file,
    this.onRemove,
    this.canRemove = false,
    this.isXFile = false,
  });
  final String? url;
  final XFile? file;
  final VoidCallback? onRemove;
  final bool canRemove;
  final bool isXFile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          isXFile
              ? Image.file(File(file!.path), fit: BoxFit.cover)
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
