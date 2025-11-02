import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/details/action_buttons.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class AddChecklistPanel extends StatefulWidget {
  const AddChecklistPanel({super.key});

  @override
  State<AddChecklistPanel> createState() => _AddChecklistPanelState();
}

class _AddChecklistPanelState extends State<AddChecklistPanel> {
  int? _active;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<TextEditingController> _points = [TextEditingController()];

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _active = null);
  }

  void _addPoint() {
    setState(() => _points.add(TextEditingController()));
  }

  void _removePoint(int i) {
    final c = _points.removeAt(i);
    c.dispose();
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _points) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _createChecklist(ChecklistViewModel vm) async {
    FocusScope.of(context).unfocus();

    final pointTexts = _points
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final ok = await vm.addChecklist(
      name: _nameCtrl.text,
      description: _descCtrl.text,
      pointTexts: pointTexts,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Checkliste tilføjet')));
      context.pop();
    } else if (vm.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(vm.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.watch<ChecklistViewModel>();

    return TapRegion(
      onTapInside: (_) => _clearFocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          spacing: 14,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      'Tilføj ny checkliste',
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
            ),

            Text(
              'Opret en ny checkliste til brug under aftaler',
              style: AppTypography.b4.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 4),

            SoftTextField(
              title: 'Checkliste navn',
              controller: _nameCtrl,
              hintText: "F.eks. Bryllups makeup",
              showStroke: _active == 0,
              onTap: () => setState(() => _active = 0),
            ),

            SoftTextField(
              title: 'Beskrivelse',
              controller: _descCtrl,
              hintText: "Kort beskrivelse af checklisten...",
              maxLines: 5,
              showStroke: _active == 1,
              onTap: () => setState(() => _active = 1),
            ),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Punkter',
                    style: AppTypography.b3.copyWith(color: cs.onSurface),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addPoint,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tilføj punkt'),
                ),
              ],
            ),

            ...List.generate(_points.length, (i) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, right: 8),
                    child: Text(
                      '${i + 1}.',
                      style: AppTypography.input1.copyWith(color: cs.onSurface),
                    ),
                  ),

                  Expanded(
                    child: SoftTextField(
                      controller: _points[i],
                      hintText: 'Checkliste punkt…',
                      showStroke: _active == (100 + i),
                      onTap: () => setState(() => _active = 100 + i),
                    ),
                  ),
                  const SizedBox(width: 8),

                  if (_points.length > 1)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _removePoint(i),
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Fjern punkt',
                    ),
                ],
              );
            }),

            const SizedBox(height: 8),
            AddActionRow(
              name: 'checkliste',
              saving: vm.saving,
              onCancel: vm.saving ? () {} : () => context.pop(),
              onConfirm: vm.saving ? () {} : () => _createChecklist(vm),
            ),
          ],
        ),
      ),
    );
  }
}
