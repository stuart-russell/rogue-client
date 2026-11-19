import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/ui/focusable_tap.dart';

void main() {
  testWidgets('takes focus and activates from Enter/Space and taps', (
    tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
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
}
