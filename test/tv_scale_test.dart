import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/ui/tv_scale.dart';

void main() {
  testWidgets('gives the child a larger logical canvas and scales it back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late Size logical;
    await tester.pumpWidget(
      MaterialApp(
        home: TvScale(
          scale: 0.5,
          child: Builder(
            builder: (context) {
              logical = MediaQuery.sizeOf(context);
              return const SizedBox.expand(
                child: ColoredBox(color: Colors.red),
              );
            },
          ),
        ),
      ),
    );

    expect(logical, const Size(800, 400));
    expect(tester.getSize(find.byType(TvScale)), const Size(400, 200));
  });
}
