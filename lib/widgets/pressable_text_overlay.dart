import 'package:flutter/material.dart';

class PressableTextOverlay extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Widget? overlayChild;

  const PressableTextOverlay({
    super.key,
    required this.text,
    this.style,
    this.overlayChild,
  });

  @override
  State<PressableTextOverlay> createState() => _PressableTextOverlayState();
}

class _PressableTextOverlayState extends State<PressableTextOverlay> {
  final _link = LayerLink();
  OverlayEntry? _entry;

  void _showOverlay() {
    if (_entry != null) return;

    _entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // barrier to dismiss on outside tap
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideOverlay,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.shrink(),
            ),
          ),
          // anchored panel
          CompositedTransformFollower(
            link: _link,
            offset: const Offset(0, 28), // below the text
            showWhenUnlinked: false,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
                child:
                    widget.overlayChild ??
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Overlay content'),
                          SizedBox(height: 8),
                          Text('Add buttons, list, etc.'),
                        ],
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _hideOverlay() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: _showOverlay,
        child: Text(
          widget.text,
          style:
              widget.style ??
              TextStyle(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
        ),
      ),
    );
  }
}
