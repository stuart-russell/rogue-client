import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/ui/ambient.dart';

void main() {
  testWidgets('performance backdrop skips the blur', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AmbientBackdrop(
            image: 'https://example.com/backdrop.jpg',
            accent: Colors.red,
            performance: true,
          ),
        ),
      ),
    );
    expect(find.byType(ImageFiltered), findsNothing);
  });

  testWidgets('normal backdrop blurs the artwork', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AmbientBackdrop(
            image: 'https://example.com/backdrop.jpg',
            accent: Colors.red,
          ),
        ),
      ),
    );
    expect(find.byType(ImageFiltered), findsOneWidget);
  });
}
