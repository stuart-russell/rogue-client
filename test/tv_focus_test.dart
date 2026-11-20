import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/theme.dart';
import 'package:rogue/ui/focusable_tap.dart';
import 'package:rogue/ui/widgets.dart';

/// Mirrors the shell: sidebar on the left, a header search field and a grid on
/// the right. A D-pad must be able to leave the sidebar and reach the grid, and
/// must never fall into the (non-traversable) header search field.
void main() {
  testWidgets('D-pad reaches the content grid past the header search field', (
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
    final search = FocusNode();
    final taps = List.filled(4, 0);
    addTearDown(() {
      for (final node in [...sidebar, ...cards, search]) {
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
                    SearchField(
                      controller: TextEditingController(),
                      traversal: false,
                      onChanged: (_) {},
                    ),
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

    // Right from the sidebar must land on a poster, not the search box.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(cards.any((node) => node.hasFocus), isTrue);
    expect(search.hasFocus, isFalse);

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
    expect(search.hasFocus, isFalse);
  });
}
