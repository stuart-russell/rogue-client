import 'package:flutter/material.dart';

/// Keeps the focused control inside the visible part of its scrollables.
///
/// Android TV does not scroll a list when D-pad traversal moves focus to an
/// off-screen item. Custom cards use [FocusableTap], which highlights itself,
/// but Material controls (switches, buttons, segmented buttons) need this
/// listener as well so Settings and detail pages stay usable with a remote.
class FocusRevealer extends StatefulWidget {
  const FocusRevealer({super.key, required this.child});

  final Widget child;

  @override
  State<FocusRevealer> createState() => _FocusRevealerState();
}

class _FocusRevealerState extends State<FocusRevealer> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_revealFocused);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_revealFocused);
    super.dispose();
  }

  void _revealFocused() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null || !focusContext.mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final object = focusContext.findRenderObject();
      if (object == null || !object.attached) return;

      // Walk outwards so nested scrollables (a guide row inside the
      // horizontal timeline) all follow the focus.
      final scrollables = <ScrollableState>[];
      focusContext.visitAncestorElements((element) {
        if (element is StatefulElement) {
          final state = element.state;
          if (state is ScrollableState) scrollables.add(state);
        }
        return true;
      });
      for (final scrollable in scrollables) {
        if (!scrollable.position.hasContentDimensions) continue;
        scrollable.position.ensureVisible(
          object,
          alignment: 0.5,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
