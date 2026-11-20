import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/theme.dart';
import 'package:rogue/ui/focusable_tap.dart';
import 'package:rogue/ui/widgets.dart';

/// Mirrors the shell: sidebar on the left, a header search field and a grid on
/// the right. The header field is reachable with the D-pad, but Up/Down must
/// leave it instead of trapping the caret.
void main() {
  testWidgets('header search and content stay reachable with the D-pad', (
    tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final sidebar = List.generate(3, (_) => FocusNode());
    final cards = List.generate(4, (_) => FocusNode());
    final taps = List.filled(4, 0);
    final controller = TextEditingController();
    addTearDown(() {
      controller.dispose();
      for (final node in [...sidebar, ...cards]) {
        node.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    for (var i = 0; i < sidebar.length; i++)
                      FocusableTap(
                        focusNode: sidebar[i],
                        autofocus: i == 0,
                        onTap: () {},
                        builder: (context, focused) => SizedBox(
                          height: 44,
                          child: Text('side$i ${focused ? 'FOCUSED' : ''}'),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    SearchField(controller: controller, onChanged: (_) {}),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        children: [
                          for (var i = 0; i < cards.length; i++)
                            FocusableTap(
                              focusNode: cards[i],
                              onTap: () => taps[i]++,
                              builder: (context, focused) =>
                                  Text('card$i ${focused ? 'FOCUSED' : ''}'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(sidebar[0].hasPrimaryFocus, isTrue);

    final field = tester.widget<TextField>(find.byType(TextField)).focusNode!;

    // Right from the sidebar reaches the content; it may land on the header
    // field or directly on a poster.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(field.hasFocus || cards.any((node) => node.hasFocus), isTrue);

    // A focused header field must let Down through to the posters.
    if (field.hasFocus) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(field.hasFocus, isFalse);
    expect(cards.any((node) => node.hasPrimaryFocus), isTrue);

    final first = cards.indexWhere((node) => node.hasPrimaryFocus);
    expect(taps[first], 0);

    // Enter/Select activates the focused poster.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps[first], 1);

    // Down moves through the grid.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(cards.where((node) => node.hasPrimaryFocus), hasLength(1));

    // Header fields are traversable, and the keyboard's submit action lands
    // on the results instead of leaving focus in the caret.
    field.requestFocus();
    await tester.pump();
    expect(field.skipTraversal, isFalse);
    await tester.enterText(find.byType(TextField), 'test');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(field.hasFocus, isFalse);
    expect(cards.any((node) => node.hasPrimaryFocus), isTrue);

    // An empty field at the caret start lets Left fall through to the sidebar.
    controller.clear();
    field.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(field.hasFocus, isFalse);
    expect(sidebar.any((node) => node.hasPrimaryFocus), isTrue);
  });
}
