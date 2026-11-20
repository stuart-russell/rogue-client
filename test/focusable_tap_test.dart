import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/ui/focusable_tap.dart';

void main() {
  testWidgets('takes focus and activates from Enter/Space and taps', (
    tester,
  ) async {
    // A remote can leave the highlight strategy in touch mode; the custom
    // ring must still follow the focus node.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );

    var taps = 0;
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FocusableTap(
              focusNode: node,
              onTap: () => taps++,
              builder: (context, focused) => SizedBox(
                width: 120,
                height: 60,
                child: Text(focused ? 'focused' : 'idle'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('idle'), findsOneWidget);

    node.requestFocus();
    await tester.pump();
    expect(find.text('focused'), findsOneWidget);

    // TV remotes send Enter/Select; desktop keyboards send Enter or Space.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(taps, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 3);

    // Pointer taps keep working.
    await tester.tap(find.byType(FocusableTap));
    await tester.pump();
    expect(taps, 4);
  });

  testWidgets(
    'holding Select opens long press, a short press taps on release',
    (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );

      var taps = 0;
      Offset? holdPosition;
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 120,
                child: FocusableTap(
                  focusNode: node,
                  onTap: () => taps++,
                  onLongPressStart: (details) =>
                      holdPosition = details.globalPosition,
                  builder: (context, focused) =>
                      Text(focused ? 'focused' : 'idle'),
                ),
              ),
            ),
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();

      // Short press: activate on release, no menu.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(taps, 1);
      expect(holdPosition, isNull);

      // Held Select: menu opens and the release must not also tap.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 700));
      expect(holdPosition, isNotNull);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(taps, 1);
    },
  );
}
