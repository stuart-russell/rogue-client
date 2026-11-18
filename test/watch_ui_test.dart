import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/state/app_model.dart';
import 'package:rogue/state/favourites.dart';
import 'package:rogue/state/watch_progress.dart';
import 'package:rogue/ui/favourites_actions.dart';
import 'package:rogue/theme.dart';
import 'package:rogue/ui/resume_dialog.dart';
import 'package:rogue/ui/widgets.dart';

void main() {
  testWidgets('poster draws a progress bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 320,
              child: PosterCard(
                title: 'Test film',
                onTap: () {},
                progress: 0.4,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('watched poster shows a completion badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 320,
              child: PosterCard(
                title: 'Test film',
                onTap: () {},
                watched: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(WatchedBadge), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('poster menu offers favourites and mark watched', (tester) async {
    final model = AppModel();
    addTearDown(model.dispose);

    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 320,
                child: PosterCard(
                  title: 'Test film',
                  onTap: () {},
                  onContextMenu: (position) => showItemMenu(
                    tester.element(find.byType(PosterCard)),
                    position,
                    favourite: Favourite(
                      type: FavouriteType.vod,
                      id: 1,
                      name: 'Test film',
                      addedAt: DateTime(2026),
                    ),
                    watchId: 'vod:1',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(PosterCard));
    await tester.pumpAndSettle();

    expect(find.text('Add to favourites'), findsOneWidget);
    expect(find.text('Mark as watched'), findsOneWidget);
  });

  testWidgets('poster long-press opens the context menu', (tester) async {
    Offset? position;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 320,
              child: PosterCard(
                title: 'Test film',
                onTap: () {},
                onContextMenu: (value) => position = value,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(PosterCard));
    expect(position, isNotNull);
  });

  testWidgets('resume dialog returns the resumption point', (tester) async {
    final entry = WatchEntry(
      position: const Duration(minutes: 30),
      duration: const Duration(hours: 2),
      updatedAt: DateTime(2026, 11, 17),
      completed: false,
    );
    Duration? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showResumeDialog(context, entry, 'Test film');
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('From start'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(result, const Duration(minutes: 30));
  });

  testWidgets('resume dialog can start from the beginning', (tester) async {
    final entry = WatchEntry(
      position: const Duration(minutes: 10),
      duration: const Duration(minutes: 90),
      updatedAt: DateTime(2026, 11, 17),
      completed: false,
    );
    Duration? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showResumeDialog(context, entry, 'Test film');
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From start'));
    await tester.pumpAndSettle();

    expect(result, Duration.zero);
  });
}
