import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/data/portals.dart';
import 'package:rogue/state/app_model.dart';
import 'package:rogue/state/favourites.dart';
import 'package:rogue/state/recents.dart';
import 'package:rogue/state/watch_progress.dart';
import 'package:rogue/theme.dart';
import 'package:rogue/updates/app_version.dart';
import 'package:rogue/ui/home_shell.dart';
import 'package:rogue/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoPortals extends PortalsStore {
  @override
  Future<List<PortalPreset>> load() async => const [];
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shell renders every tab with an empty catalogue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final model = AppModel(
      portalStore: _NoPortals(),
      progress: _NoProgress(),
      favourites: _NoFavourites(),
      recents: _NoRecents(),
    );
    addTearDown(model.dispose);
    await model.init();

    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(theme: buildAppTheme(), home: const HomeShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TV Guide'), findsWidgets);
    expect(find.text('Nothing here yet'), findsOneWidget);

    for (final tab in ['Movies', 'Series', 'Search', 'Settings']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();
    }

    expect(find.text('Account, playback and local cache'), findsOneWidget);

    // Updates panel is part of Settings even when no channel is configured.
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Rogue ${AppVersion.running.semver}'), findsOneWidget);
    expect(find.text('Updates are disabled in this build.'), findsOneWidget);

    // Appearance swatches live at the top of Settings and apply immediately.
    expect(find.text('Appearance'), findsOneWidget);
    for (final palette in kPalettes) {
      expect(find.text(palette.name), findsOneWidget);
    }

    await tester.tap(find.text('Midnight'));
    await tester.pumpAndSettle();
    expect(model.preferences.paletteId, 'midnight');
    expect(AppColors.accent, midnightPalette.accent);

    // Put the default back so later tests are not affected.
    await tester.tap(find.text('Rogue'));
    await tester.pumpAndSettle();
    expect(model.preferences.paletteId, 'rogue');
  });

  testWidgets('TV sidebar collapses while focus is in the page', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await _pumpShell(tester);

    final sidebar = find.byKey(const ValueKey('sidebar'));
    expect(tester.getSize(sidebar).width, 224);
    expect(find.text('Movies'), findsOneWidget);

    // Focus moves into the guide content, so the rail collapses to icons.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 64);
    expect(find.text('Movies'), findsNothing);

    // Moving focus back onto the rail expands it again.
    // The icon sits inside a canRequestFocus:false InkWell, so use the
    // FocusableTap node immediately above it.
    final inkNode = Focus.of(
      tester.element(find.byIcon(Icons.live_tv_rounded)),
    );
    inkNode.ancestors.first.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 224);
    expect(find.text('Movies'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('D-pad activates sidebar tabs and stays in Settings', (
    tester,
  ) async {
    final model = await _pumpShell(tester);

    // TV Guide is selected and autofocused. Down -> Movies, OK opens it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Browse the film library on your panel'), findsOneWidget);

    // Movies -> Series -> Search -> Recents -> Favourites -> Settings.
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Account, playback and local cache'), findsOneWidget);

    // Right must enter the painted Settings page, not a hidden tab that
    // IndexedStack kept laid out.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final focus = FocusManager.instance.primaryFocus;
    expect(focus, isNotNull);
    expect(
      focus!.context!.findAncestorWidgetOfExactType<SettingsScreen>(),
      isNotNull,
    );

    // Palette cards are focusable and OK applies them.
    Focus.of(tester.element(find.text('Midnight'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.preferences.paletteId, 'midnight');
  });
}

Future<AppModel> _pumpShell(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final model = AppModel(
    portalStore: _NoPortals(),
    progress: _NoProgress(),
    favourites: _NoFavourites(),
    recents: _NoRecents(),
  );
  addTearDown(model.dispose);
  await model.init();

  await tester.pumpWidget(
    AppScope(
      model: model,
      child: MaterialApp(theme: buildAppTheme(), home: const HomeShell()),
    ),
  );
  await tester.pumpAndSettle();
  return model;
}
