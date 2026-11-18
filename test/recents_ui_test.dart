import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/data/portals.dart';
import 'package:rogue/state/app_model.dart';
import 'package:rogue/state/favourites.dart';
import 'package:rogue/state/recents.dart';
import 'package:rogue/state/watch_progress.dart';
import 'package:rogue/theme.dart';
import 'package:rogue/ui/recents_screen.dart';
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

Future<AppModel> _pumpRecents(
  WidgetTester tester,
  List<RecentItem> items,
) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final recents = _NoRecents();
  for (final item in items) {
    await recents.add(item);
  }

  final model = AppModel(
    portalStore: _NoPortals(),
    progress: _NoProgress(),
    favourites: _NoFavourites(),
    recents: recents,
  );
  addTearDown(model.dispose);
  await model.init();

  await tester.pumpWidget(
    AppScope(
      model: model,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: RecentsScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return model;
}

RecentItem _channel(int id, String name) => RecentItem(
  type: RecentType.live,
  id: id,
  name: name,
  openedAt: DateTime.now(),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('long-press on a recent channel offers removal', (tester) async {
    final model = await _pumpRecents(tester, [
      _channel(1, 'Sky Sports Main Event'),
    ]);

    await tester.longPress(find.text('Sky Sports Main Event'));
    await tester.pumpAndSettle();

    expect(find.text('Remove from recents'), findsOneWidget);

    await tester.tap(find.text('Remove from recents'));
    await tester.pumpAndSettle();

    expect(find.text('Sky Sports Main Event'), findsNothing);
    expect(model.recents.of(RecentType.live), isEmpty);
  });

  testWidgets('right-click on a recent poster offers removal', (tester) async {
    final model = await _pumpRecents(tester, [
      RecentItem(
        type: RecentType.vod,
        id: 7,
        name: 'Dune: Part Two',
        openedAt: DateTime.now(),
      ),
    ]);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Dune: Part Two')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Remove from recents'), findsOneWidget);
    await tester.tap(find.text('Remove from recents'));
    await tester.pumpAndSettle();

    expect(model.recents.of(RecentType.vod), isEmpty);
  });
}
