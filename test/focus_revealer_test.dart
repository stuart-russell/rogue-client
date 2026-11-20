import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/ui/focus_revealer.dart';

void main() {
  testWidgets('scrolls an off-screen focused control into view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final nodes = List.generate(10, (_) => FocusNode());
    addTearDown(() {
      for (final node in nodes) {
        node.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: FocusRevealer(
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < nodes.length; i++)
                    SizedBox(
                      height: 100,
                      child: Focus(focusNode: nodes[i], child: Text('item$i')),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, 0);

    nodes.last.requestFocus();
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(0));
  });
}
