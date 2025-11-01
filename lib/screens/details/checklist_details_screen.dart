import 'package:aftaler_og_regnskab/model/checklist_model.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/persistence_ops.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/cards/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/details/action_buttons.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ChecklistDetailsScreen extends StatefulWidget {
  const ChecklistDetailsScreen({super.key, required this.checklistId});
  final String checklistId;

  @override
  State<ChecklistDetailsScreen> createState() => _ChecklistDetailsScreenState();
}

class _ChecklistDetailsScreenState extends State<ChecklistDetailsScreen> {
  late final ChecklistViewModel _vm;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _vm = context.read<ChecklistViewModel>();
    _vm.subscribeToChecklist(widget.checklistId);
    _subscribed = true;
  }

  @override
  void dispose() {
    if (_subscribed) {
      _vm.unsubscribeFromChecklist(widget.checklistId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ChecklistViewModel>();
    return Selector<ChecklistViewModel, ChecklistModel?>(
      selector: (_, vm) => vm.getChecklist(widget.checklistId),
      builder: (context, checklist, _) {
        if (checklist == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
          return const SizedBox.shrink();
        }

        return _ChecklistDetailsView(
          key: ValueKey(checklist.id),
          checklist: checklist,
        );
      },
    );
  }
}

class _ChecklistDetailsView extends StatefulWidget {
  const _ChecklistDetailsView({super.key, required this.checklist});
  final ChecklistModel checklist;

  @override
  State<_ChecklistDetailsView> createState() => _ChecklistDetailsViewState();
}

class _ChecklistDetailsViewState extends State<_ChecklistDetailsView> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final hPad = LayoutMetrics.horizontalPadding(context);

    return SingleChildScrollView(
      key: const PageStorageKey('checklistDetailsScroll'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hPad,
          10,
          hPad,
          LayoutMetrics.navBarHeight(context) + 30,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _editing
              ? _ChecklistEditPane(
                  key: const ValueKey('edit'),
                  checklist: widget.checklist,
                  onCancel: () => setState(() => _editing = false),
                  onSaved: () => setState(() => _editing = false),
                )
              : _ChecklistReadPane(
                  key: const ValueKey('read'),
                  checklist: widget.checklist,
                  onEdit: () => setState(() => _editing = true),
                  onDelete: () async {
                    await handleDelete(
                      context: context,
                      componentLabel: 'Service',
                      onDelete: () => context.read<ChecklistViewModel>().delete(
                        widget.checklist.id!,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ChecklistReadPane extends StatelessWidget {
  const _ChecklistReadPane({
    super.key,
    required this.checklist,
    required this.onEdit,
    required this.onDelete,
  });
  final ChecklistModel checklist;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomCard(
          field: Padding(
            padding: const EdgeInsets.all(35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(checklist.name!, style: AppTypography.h3),
                          const SizedBox(height: 20),
                          checklist.description != null
                              ? Text(
                                  checklist.description!,
                                  style: AppTypography.b2,
                                )
                              : Text(
                                  "Ingen beskrivelse",
                                  style: AppTypography.b2,
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 30),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.primary.withAlpha(60),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.checklist, size: 32, color: cs.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                Row(
                  children: [
                    Icon(CupertinoIcons.cube_box, color: cs.primary, size: 20),
                    const SizedBox(width: 12),
                    Text("Punkter", style: AppTypography.b3),
                  ],
                ),

                const SizedBox(height: 24),

                Builder(
                  builder: (_) {
                    final pts = checklist.points;

                    if (pts.isEmpty) {
                      return Text(
                        'Ingen punkter tilføjet',
                        style: AppTypography.b6.copyWith(
                          color: cs.onSurface.withAlpha(200),
                        ),
                      );
                    } else {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < pts.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            _PointRow(index: i + 1, text: pts[i]),
                          ],
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        ReadActionsRow(onEdit: onEdit, onDelete: onDelete),
      ],
    );
  }
}

class _ChecklistEditPane extends StatefulWidget {
  const _ChecklistEditPane({
    super.key,
    required this.checklist,
    required this.onCancel,
    required this.onSaved,
  });
  final ChecklistModel checklist;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  State<_ChecklistEditPane> createState() => __ChecklistEditPaneState();
}

class __ChecklistEditPaneState extends State<_ChecklistEditPane> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late List<TextEditingController> _pointCtrls = [];
  int? _active;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.checklist.name ?? '');
    _descCtrl = TextEditingController(text: widget.checklist.description ?? '');
    _pointCtrls = [
      for (final p in widget.checklist.points) TextEditingController(text: p),
    ];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _pointCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await handleSave(
      context: context,
      validate: () {
        final name = _nameCtrl.text.trim();
        if (name.isEmpty) return 'Angiv navn på checklisten';
        return null;
      },

      onSave: () {
        final pts = _pointCtrls
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return context.read<ChecklistViewModel>().updateChecklistFields(
          widget.checklist.id!,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text,
          points: pts,
        );
      },
      errorText: () =>
          context.read<ChecklistViewModel>().error ?? 'Ukendt fejl',
      onSuccess: widget.onSaved,
    );
  }

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _active = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TapRegion(
      onTapInside: (_) => _clearFocus(),
      onTapOutside: (_) => _clearFocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomCard(
            field: Padding(
              padding: const EdgeInsets.all(35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SoftTextField(
                              hintText: widget.checklist.name!,
                              hintStyle: AppTypography.b2.copyWith(
                                color: cs.onSurface.withAlpha(150),
                              ),
                              controller: _nameCtrl,
                              fill: cs.onPrimary,
                              strokeColor: _active != 1
                                  ? cs.onSurface.withAlpha(50)
                                  : cs.primary,
                              strokeWidth: _active != 1 ? 1 : 1.5,
                              borderRadius: 8,
                              showStroke: true,
                              onTap: () => setState(() => _active = 1),
                            ),

                            const SizedBox(height: 20),

                            //Description
                            SoftTextField(
                              hintText:
                                  widget.checklist.description ??
                                  "Tilføj beskrivelse",
                              hintStyle: AppTypography.b2.copyWith(
                                color: cs.onSurface.withAlpha(150),
                              ),
                              controller: _descCtrl,
                              fill: cs.onPrimary,
                              strokeColor: _active != 2
                                  ? cs.onSurface.withAlpha(50)
                                  : cs.primary,
                              strokeWidth: _active != 2 ? 1 : 1.5,
                              borderRadius: 8,
                              showStroke: true,
                              onTap: () => setState(() => _active = 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 30),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.primary.withAlpha(60),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.checklist,
                          size: 32,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.cube_box,
                        color: cs.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text("Punkter", style: AppTypography.b3),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (_) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < _pointCtrls.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '${i + 1}',
                                  style: AppTypography.num6.copyWith(
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SoftTextField(
                                    hintText: 'Punkt',
                                    controller: _pointCtrls[i],
                                    fill: cs.onPrimary,
                                    borderRadius: 8,
                                    showStroke: true,
                                    strokeColor: cs.onSurface.withAlpha(50),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Fjern',
                                  icon: Icon(
                                    Icons.close,
                                    color: cs.onSurface.withAlpha(180),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      final c = _pointCtrls.removeAt(i);
                                      c.dispose();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Tilføj punkt'),
                              onPressed: () => setState(() {
                                _pointCtrls.add(TextEditingController());
                              }),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Selector<ChecklistViewModel, bool>(
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

class _PointRow extends StatelessWidget {
  const _PointRow({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('$index', style: AppTypography.num6.copyWith(color: cs.primary)),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: AppTypography.b4, softWrap: true)),
        ],
      ),
    );
  }
}
