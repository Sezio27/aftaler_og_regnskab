import 'package:aftaler_og_regnskab/model/checklistModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ChecklistDetailsScreen extends StatelessWidget {
  const ChecklistDetailsScreen({super.key, required this.checklistId});
  final String checklistId;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ChecklistViewModel>();
    return StreamBuilder<ChecklistModel?>(
      stream: vm.watchChecklistById(checklistId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Fejl: ${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final checklist = snap.data;
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

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  List<TextEditingController> _pointCtrls = [];
  int? _active;

  void _loadFromModel() {
    _nameCtrl.text = widget.checklist.name ?? '';
    _descCtrl.text = widget.checklist.description ?? '';
    for (final c in _pointCtrls) {
      c.dispose();
    }
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

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _active = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hPad = LayoutMetrics.horizontalPadding(context);
    final vm = context.watch<ChecklistViewModel>();

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hPad,
          10,
          hPad,
          LayoutMetrics.navBarHeight(context) + 30,
        ),
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
                              // Title
                              _editing
                                  ? SoftTextField(
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
                                    )
                                  : Text(
                                      widget.checklist.name!,
                                      style: AppTypography.h3,
                                    ),

                              const SizedBox(height: 20),

                              //Description
                              _editing
                                  ? SoftTextField(
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
                                    )
                                  : widget.checklist.description != null
                                  ? Text(
                                      widget.checklist.description!,
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
                        final pts = widget.checklist.points;
                        if (!_editing) {
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
                        }

                        if (_pointCtrls.isEmpty) {
                          _loadFromModel();
                        }
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _editing
                  ? Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: "Annuller",
                            onTap: () {
                              _loadFromModel();
                              setState(() => _editing = false);
                            },

                            textStyle: AppTypography.button3.copyWith(
                              color: cs.onSurface.withAlpha(200),
                            ),

                            borderRadius: 12,
                            color: cs.onPrimary,
                            borderStroke: Border.all(
                              color: cs.onSurface.withAlpha(200),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: CustomButton(
                            text: vm.saving ? "Gemmer..." : "Bekræft",
                            textStyle: AppTypography.button3.copyWith(
                              color: cs.onPrimary,
                            ),
                            onTap: vm.saving
                                ? () {}
                                : () async {
                                    final pts = _pointCtrls
                                        .map((c) => c.text.trim())
                                        .where((s) => s.isNotEmpty)
                                        .toList();

                                    final ok = await context
                                        .read<ChecklistViewModel>()
                                        .updateChecklistFields(
                                          widget.checklist.id!,
                                          name: _nameCtrl.text,
                                          description: _descCtrl.text,
                                          points: pts,
                                        );

                                    if (!mounted) return;
                                    if (ok) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Opdateret'),
                                        ),
                                      );
                                      setState(() {
                                        _editing = false;
                                      });
                                    } else {
                                      final err =
                                          context
                                              .read<ChecklistViewModel>()
                                              .error ??
                                          'Ukendt fejl';
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(err)),
                                      );
                                    }
                                  },
                            borderRadius: 12,

                            color: cs.primary.withAlpha(200),
                            borderStroke: Border.all(
                              color: cs.onPrimary.withAlpha(200),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: "Rediger",
                            textStyle: AppTypography.button3.copyWith(
                              color: cs.onSurface.withAlpha(200),
                            ),
                            onTap: () {
                              setState(() {
                                _editing = true;
                                _loadFromModel();
                              });
                            },
                            borderRadius: 12,
                            icon: Icon(
                              Icons.edit_outlined,
                              color: cs.onSurface.withAlpha(200),
                            ),
                            color: cs.onPrimary,
                            borderStroke: Border.all(
                              color: cs.onSurface.withAlpha(200),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: CustomButton(
                            text: "Slet",
                            textStyle: AppTypography.button3.copyWith(
                              color: cs.error.withAlpha(200),
                            ),
                            onTap: () async {
                              final ok =
                                  await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Slet klient?'),
                                      content: const Text(
                                        'Dette kan ikke fortrydes.',
                                      ),
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
                              context.pop();
                            },
                            borderRadius: 12,
                            icon: Icon(
                              Icons.delete,
                              color: cs.error.withAlpha(200),
                            ),
                            color: cs.onPrimary,
                            borderStroke: Border.all(
                              color: cs.error.withAlpha(200),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
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
