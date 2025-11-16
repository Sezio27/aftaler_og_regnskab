import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/material.dart';

class ExpandableSection extends StatefulWidget {
  const ExpandableSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection>
    with TickerProviderStateMixin {
  late bool _open;
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _open = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    if (_open) _ctrl.value = 1;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.title, style: AppTypography.h3),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _toggle,
              icon: AnimatedRotation(
                duration: const Duration(milliseconds: 180),
                turns: _open ? 0.5 : 0.0,
                child: Icon(Icons.expand_more, color: cs.onSurface),
              ),
            ),
          ],
        ),

        ClipRect(
          child: SizeTransition(
            axis: Axis.vertical,
            axisAlignment: -1.0,
            sizeFactor: _anim,
            child: FadeTransition(opacity: _anim, child: widget.child),
          ),
        ),
      ],
    );
  }
}
