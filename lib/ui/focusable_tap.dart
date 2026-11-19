import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a tappable surface so it can be reached with a D-pad or keyboard,
/// with a visible focus highlight.
///
/// Plain [GestureDetector]s (used for most rows, cards and chips) are invisible
/// to Android TV's focus traversal, which left only the sidebar navigable. The
/// builder receives whether the item currently has focus so callers can draw
/// their own highlight.
class FocusableTap extends StatefulWidget {
  const FocusableTap({
    super.key,
    required this.onTap,
    required this.builder,
    this.onLongPressStart,
    this.onSecondaryTapUp,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
  });

  final VoidCallback onTap;

  /// `(context, focused)` — draw the focus ring when `focused` is true.
  final Widget Function(BuildContext context, bool focused) builder;
  final void Function(LongPressStartDetails details)? onLongPressStart;
  final void Function(TapUpDetails details)? onSecondaryTapUp;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;

  @override
  State<FocusableTap> createState() => _FocusableTapState();
}

class _FocusableTapState extends State<FocusableTap> {
  bool _focused = false;

  static const Map<ShortcutActivator, Intent> _shortcuts = {
    SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      onShowFocusHighlight: (value) {
        setState(() => _focused = value);
        if (value) {
          // D-pad traversal does not scroll lists by itself.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Scrollable.maybeOf(context)?.position.ensureVisible(
              context.findRenderObject()!,
              alignment: 0.5,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
            );
          });
        }
      },
      mouseCursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      shortcuts: _shortcuts,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (widget.enabled) widget.onTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        onLongPressStart: widget.onLongPressStart,
        onSecondaryTapUp: widget.onSecondaryTapUp,
        child: widget.builder(context, _focused),
      ),
    );
  }
}
