import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/theme.dart';
import 'package:rogue/ui/focus_ring.dart';
import 'package:rogue/ui/focusable_tap.dart';

void main() {
  testWidgets('rings the focused descendant', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: FocusRing(
              child: FocusableTap(
                focusNode: node,
                onTap: () {},
                builder: (context, focused) => const SizedBox(
                  width: 160,
                  height: 60,
                  child: Text('control'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    AnimatedContainer ring() => tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(FocusRing),
        matching: find.byType(AnimatedContainer),
      ),
    );

    BoxBorder border() =>
        (ring().foregroundDecoration as BoxDecoration).border!;

    expect((border() as Border).top.color, Colors.transparent);

    node.requestFocus();
    await tester.pumpAndSettle();

    expect((border() as Border).top.color, AppColors.accent);
  });
}
