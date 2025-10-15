import 'package:aftaler_og_regnskab/model/checklistModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/material.dart';

class AppointmentChecklistCard extends StatefulWidget {
  const AppointmentChecklistCard({
    super.key,
    required this.checklist,
    required this.completed, // indices of done points
    required this.onChanged, // returns updated set
  });

  final ChecklistModel checklist;
  final Set<int> completed;
  final ValueChanged<Set<int>> onChanged;

  @override
  State<AppointmentChecklistCard> createState() =>
      _AppointmentChecklistCardState();
}

class _AppointmentChecklistCardState extends State<AppointmentChecklistCard> {
  bool _expanded = false;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);
  void _toggleIndex(int i) {
    final next = {...widget.completed};
    if (next.contains(i)) {
      next.remove(i);
    } else {
      next.add(i);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = widget.checklist.points.length;
    final done = widget.completed.length.clamp(0, total);
    final pct = total == 0 ? 0 : ((done / total) * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: cs.onPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withOpacity(0.35), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header block
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: title + description + counter
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.checklist.name ?? '—', style: AppTypography.b6),
                    if ((widget.checklist.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.checklist.description!,
                        style: AppTypography.num6.copyWith(
                          color: cs.onSurface.withOpacity(0.75),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '$done af $total færdige',
                      style: AppTypography.num7.copyWith(
                        color: cs.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right: pill + Åbn/Luk
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ProgressPill(percent: pct),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _toggleExpanded,
                    child: Text(
                      _expanded ? 'Luk' : 'Åbn',
                      style: AppTypography.b4.copyWith(color: cs.onSurface),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Body (expanded)
          if (_expanded && total > 0) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: cs.onSurface.withOpacity(0.25)),
            const SizedBox(height: 8),

            // Points
            ...List.generate(total, (i) {
              final text = widget.checklist.points[i];
              final checked = widget.completed.contains(i);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleIndex(i),
                  child: Row(
                    children: [
                      _CheckSquare(checked: checked),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: AppTypography.b4.copyWith(color: cs.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  // Hook up your add-flow (overlay/bottom sheet) here.
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'Tilføj punkt',
                  style: AppTypography.b4.copyWith(color: cs.onSurface),
                ),
              ),
            ),
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
        color: cs.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$percent%',
        style: AppTypography.b5.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
        ),
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
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: checked ? cs.primary.withOpacity(0.25) : cs.onPrimary,
        border: Border.all(
          color: checked
              ? cs.primary.withOpacity(0.0)
              : cs.onSurface.withOpacity(0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: checked ? Icon(Icons.check, size: 18, color: cs.onPrimary) : null,
    );
  }
}
