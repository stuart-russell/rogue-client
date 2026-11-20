import 'package:flutter/material.dart';

import '../theme.dart';

/// Draws a clear accent ring around whichever descendant has focus.
///
/// Material's own focus overlay is too subtle from a sofa, especially for
/// switches and text buttons. Wrapping a control (or a whole label + switch
/// row) in this makes the remote's position obvious without adding a focus
/// node that D-pad traversal can land on.
class FocusRing extends StatefulWidget {
  const FocusRing({super.key, required this.child, this.radius = 10});

  final Widget child;
  final double radius;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onFocusChange: (value) {
        if (_focused != value) setState(() => _focused = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _focused
              ? AppColors.accent.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: _focused ? AppColors.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
