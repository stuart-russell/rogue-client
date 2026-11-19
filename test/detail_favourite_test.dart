import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/data/models.dart';
import 'package:rogue/data/portals.dart';
import 'package:rogue/state/app_model.dart';
import 'package:rogue/state/favourites.dart';
import 'package:rogue/state/recents.dart';
import 'package:rogue/state/watch_progress.dart';
import 'package:rogue/theme.dart';
import 'package:rogue/ui/detail_screens.dart';
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

Future<AppModel> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1400, 1000);
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
      child: MaterialApp(theme: buildAppTheme(), home: home),
    ),
  );
  // The page shows a loading spinner while there is no panel, so settle by
  // pumping fixed frames instead of waiting for animations to stop.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return model;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a film has one favourite control, in the top banner', (tester) async {
    final model = await _pump(
      tester,
      const MovieDetailScreen(
        movie: VodStream(streamId: 42, name: 'Test Film'),
      ),
    );

    // One control, not two: the inline heart next to the title is gone.
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(model.favourites.contains(FavouriteType.vod, 42), isTrue);

    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(model.favourites.contains(FavouriteType.vod, 42), isFalse);
  });

  testWidgets('a series has one favourite control, in the top banner', (tester) async {
    final model = await _pump(
      tester,
      const SeriesDetailScreen(
        series: SeriesItem(seriesId: 7, name: 'Test Show'),
      ),
    );

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(model.favourites.contains(FavouriteType.series, 7), isTrue);
  });
}
