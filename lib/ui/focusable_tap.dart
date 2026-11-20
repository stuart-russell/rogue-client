import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a tappable surface so it can be reached with a D-pad or keyboard,
/// with a visible focus highlight.
///
/// Plain [GestureDetector]s (used for most rows, cards and chips) are invisible
/// to Android TV's focus traversal, which left only the sidebar navigable. The
/// builder receives whether the item currently has focus so callers can draw
/// their own highlight.
///
/// A remote's centre button is a keyboard key, not a pointer, so a held OK is
/// translated into the same long-press callback as touch/right-click.
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
  static const Duration _longPressDelay = Duration(milliseconds: 450);

  static const Map<ShortcutActivator, Intent> _shortcuts = {
    SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  late FocusNode _node;
  bool _ownsNode = false;
  bool _focused = false;
  bool _longPressed = false;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _attachNode();
  }

  void _attachNode() {
    _node = widget.focusNode ?? FocusNode(debugLabel: 'FocusableTap');
    _ownsNode = widget.focusNode == null;
    _node.onKeyEvent = _onKey;
  }

  @override
  void didUpdateWidget(covariant FocusableTap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (_ownsNode) _node.dispose();
      _attachNode();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    if (_ownsNode) _node.dispose();
    super.dispose();
  }

  bool _isActivationKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.gameButtonA ||
      key == LogicalKeyboardKey.space;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled || !_isActivationKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    final canLongPress = widget.onLongPressStart != null;

    if (event is KeyDownEvent) {
      _holdTimer?.cancel();
      _longPressed = false;
      if (canLongPress) {
        _holdTimer = Timer(_longPressDelay, _fireLongPress);
      } else {
        // No menu on this surface: activate immediately, as before.
        widget.onTap();
      }
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) {
      // Some remotes/IMEs only reveal a hold through repeats; treat the
      // first repeat as the long press even if the timer has not fired yet.
      if (canLongPress && !_longPressed) _fireLongPress();
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      final wasLongPress = _longPressed;
      _holdTimer?.cancel();
      _holdTimer = null;
      _longPressed = false;
      // A short press activates on release; the hold already opened the menu.
      if (canLongPress && !wasLongPress && node.hasFocus) {
        widget.onTap();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _fireLongPress() {
    if (!mounted || !widget.enabled) return;
    _longPressed = true;
    final callback = widget.onLongPressStart;
    if (callback == null) return;

    final object = context.findRenderObject();
    final position = object is RenderBox && object.hasSize
        ? object.localToGlobal(object.size.center(Offset.zero))
        : Offset.zero;
    callback(LongPressStartDetails(globalPosition: position));
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      // Use focus changes rather than onShowFocusHighlight: the highlight
      // flag depends on FocusManager's input mode, which can stay in "touch"
      // on Android TV and leave every custom focus ring invisible.
      onFocusChange: (value) {
        if (!value) _holdTimer?.cancel();
        setState(() => _focused = value);
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
