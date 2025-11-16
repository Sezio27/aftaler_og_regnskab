import 'package:aftaler_og_regnskab/domain/checklist_model.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/material.dart';

class AppointmentChecklistCard extends StatefulWidget {
  const AppointmentChecklistCard({
    super.key,
    required this.checklist,
    this.completed,
    this.onToggleItem,
    this.collapse = false,
    this.editing = false,
    this.onRemove,
  });

  final ChecklistModel checklist;
  final Set<int>? completed;
  final void Function(int index, bool nowChecked)? onToggleItem;
  final bool collapse;
  final bool editing;
  final VoidCallback? onRemove;

  @override
  State<AppointmentChecklistCard> createState() =>
      _AppointmentChecklistCardState();
}

class _AppointmentChecklistCardState extends State<AppointmentChecklistCard> {
  bool _expanded = false;

  void _toggleExpanded() {
    if (widget.editing) return;
    setState(() => _expanded = !_expanded);
  }

  @override
  void didUpdateWidget(covariant AppointmentChecklistCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.collapse && _expanded) || (widget.editing && _expanded)) {
      setState(() => _expanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool isEdit = widget.editing;
    final int total = widget.checklist.points.length;
    final Set<int> completed = widget.completed ?? const <int>{};

    int? done, pct;
    if (!isEdit) {
      done = completed.length.clamp(0, total);
      pct = total == 0 ? 0 : ((done / total) * 100).round();
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withAlpha(100), width: 0.8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.checklist.name ?? '—', style: AppTypography.b3),
                  if ((widget.checklist.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.checklist.description!,
                      style: AppTypography.b6,
                    ),
                  ],

                  if (!isEdit) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$done af $total færdige',
                      style: AppTypography.num5.copyWith(
                        color: cs.onSurface.withAlpha(180),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!isEdit) ...[
                    _ProgressPill(percent: pct!),
                    const SizedBox(width: 20),
                  ],
                  const SizedBox(width: 20),
                  if (isEdit)
                    InkWell(
                      onTap: widget.onRemove,
                      child: Text(
                        'Fjern',
                        style: AppTypography.b8.copyWith(color: cs.error),
                      ),
                    )
                  else
                    InkWell(
                      onTap: _toggleExpanded,
                      child: Text(
                        _expanded ? 'Luk' : 'Åbn',
                        style: AppTypography.b8.copyWith(color: cs.onSurface),
                      ),
                    ),
                ],
              ),
            ],
          ),

          if (_expanded && !isEdit && total > 0) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: cs.onSurface.withAlpha(100)),
            const SizedBox(height: 8),

            ...List.generate(total, (i) {
              final text = widget.checklist.points[i];
              final checked = widget.completed!.contains(i);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onToggleItem!(i, !checked),
                  child: Row(
                    children: [
                      _CheckSquare(checked: checked),
                      const SizedBox(width: 12),
                      Text(
                        text,
                        style: AppTypography.b9.copyWith(color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$percent%',
        style: AppTypography.segActiveNumber.copyWith(color: cs.primary),
      ),
    );
  }
}

class _CheckSquare extends StatelessWidget {
  const _CheckSquare({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: checked ? cs.primary : cs.onPrimary,
        border: Border.all(
          color: checked ? cs.primary.withAlpha(0) : cs.onSurface.withAlpha(60),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.onPrimary.withAlpha(100),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: checked ? Icon(Icons.check, size: 18, color: cs.onPrimary) : null,
    );
  }
}
