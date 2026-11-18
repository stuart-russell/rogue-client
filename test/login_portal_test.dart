import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/data/portals.dart';
import 'package:rogue/state/app_model.dart';
import 'package:rogue/state/favourites.dart';
import 'package:rogue/state/recents.dart';
import 'package:rogue/state/watch_progress.dart';
import 'package:rogue/theme.dart';
import 'package:rogue/ui/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedPortals extends PortalsStore {
  @override
  Future<List<PortalPreset>> load() async => const [
    PortalPreset(name: 'Rogue 1', url: 'http://a.example:8880'),
    PortalPreset(name: 'Empire', url: 'http://b.example:2086'),
  ];
}

class _NoRecents extends RecentsStore {
  @override
  Future<void> load() async {}
}

class _NoFavourites extends FavouritesStore {
  @override
  Future<void> load() async {}
}

class _NoProgress extends WatchProgress {
  @override
  Future<void> load() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('portal dropdown swaps the server url', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final model = AppModel(
      portalStore: _FixedPortals(),
      progress: _NoProgress(),
      favourites: _NoFavourites(),
      recents: _NoRecents(),
    );
    addTearDown(model.dispose);
    await model.init();

    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(theme: buildAppTheme(), home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Defaults to the first preset and shows its URL.
    expect(find.text('Rogue 1'), findsOneWidget);
    expect(find.text('http://a.example:8880'), findsOneWidget);

    // Choose the second preset.
    await tester.tap(find.text('Rogue 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empire').last);
    await tester.pumpAndSettle();

    expect(find.text('Empire'), findsOneWidget);
    expect(find.text('http://b.example:2086'), findsOneWidget);
    expect(find.text('http://a.example:8880'), findsNothing);

    // "Custom server…" reveals the free-text field.
    await tester.tap(find.text('Empire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom server…').last);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, 'http://b.example:2086'),
      findsOneWidget,
    );

    // And back to a preset hides it again.
    await tester.tap(find.text('Custom server…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rogue 1').last);
    await tester.pumpAndSettle();

    expect(find.text('http://a.example:8880'), findsOneWidget);
  });
}
