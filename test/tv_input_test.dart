import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/ui/widgets.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Widget host(Size size, void Function(BuildContext) inspect) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Builder(
          builder: (context) {
            inspect(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  testWidgets('TV password fields request the visible-password keyboard', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    late TextInputType type;
    await tester.pumpWidget(
      host(const Size(1280, 720), (context) {
        type = tvSecureKeyboardType(context);
      }),
    );
    // Fire TV's IME ignores the first request for secure editors; the
    // visible-password variation still obscures the text but opens reliably.
    expect(type, TextInputType.visiblePassword);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('phone and desktop keep the normal keyboard type', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    late TextInputType type;
    await tester.pumpWidget(
      host(const Size(420, 800), (context) {
        type = tvSecureKeyboardType(context);
      }),
    );
    expect(type, TextInputType.text);

    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(
      host(const Size(1280, 720), (context) {
        type = tvSecureKeyboardType(context);
      }),
    );
    expect(type, TextInputType.text);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('TvTextInput renders its field on TV without taking focus', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(1280, 720)),
          child: Material(
            child: TvTextInput(
              child: TextField(decoration: InputDecoration(labelText: 'PIN')),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
