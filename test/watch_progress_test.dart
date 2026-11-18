import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/state/watch_progress.dart';

void main() {
  group('WatchEntry', () {
    test('reports fraction and remaining time', () {
      final entry = WatchEntry(
        position: const Duration(minutes: 30),
        duration: const Duration(hours: 2),
        updatedAt: DateTime(2026, 11, 17),
        completed: false,
      );
      expect(entry.fraction, closeTo(0.25, 0.0001));
      expect(entry.remaining, const Duration(minutes: 90));
    });

    test('clamps to 100% and never returns negative remaining', () {
      final entry = WatchEntry(
        position: const Duration(hours: 3),
        duration: const Duration(hours: 2),
        updatedAt: DateTime(2026, 11, 17),
        completed: true,
      );
      expect(entry.fraction, 1.0);
      expect(entry.remaining, Duration.zero);
    });

    test('survives a JSON round trip', () {
      final entry = WatchEntry(
        position: const Duration(seconds: 1234),
        duration: const Duration(seconds: 7200),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1760000000000),
        completed: false,
      );
      final restored = WatchEntry.fromJson(entry.toJson());
      expect(restored.position, entry.position);
      expect(restored.duration, entry.duration);
      expect(restored.updatedAt, entry.updatedAt);
      expect(restored.completed, isFalse);
    });

    group('completion thresholds', () {
      test('episodes finish with 1 minute left', () {
        final store = WatchProgress();
        const duration = Duration(minutes: 45);
        store.record(
          'ep:1',
          duration - const Duration(seconds: 50),
          duration,
          completionSlack: const Duration(minutes: 1),
        );
        expect(store.entryFor('ep:1')!.completed, isTrue);

        store.record(
          'ep:2',
          duration - const Duration(seconds: 90),
          duration,
          completionSlack: const Duration(minutes: 1),
        );
        expect(store.entryFor('ep:2')!.completed, isFalse);
      });

      test('films finish with 5 minutes left', () {
        final store = WatchProgress();
        const duration = Duration(hours: 2);
        store.record(
          'vod:1',
          duration - const Duration(minutes: 4),
          duration,
          completionSlack: const Duration(minutes: 5),
        );
        expect(store.entryFor('vod:1')!.completed, isTrue);

        store.record(
          'vod:2',
          duration - const Duration(minutes: 6),
          duration,
          completionSlack: const Duration(minutes: 5),
        );
        expect(store.entryFor('vod:2')!.completed, isFalse);
      });

      test('slack never exceeds half a short item', () {
        final store = WatchProgress();
        store.record(
          'ep:3',
          Duration.zero,
          const Duration(seconds: 100),
          completionSlack: const Duration(minutes: 1),
        );
        // 60 s slack is more than half of 100 s, so it is capped at 50 s.
        expect(store.entryFor('ep:3')!.completed, isFalse);
      });
    });

    group('manual marking', () {
      test('markWatched flags an item and clear removes it', () async {
        final store = WatchProgress();
        store.markWatched('vod:9');
        final entry = store.entryFor('vod:9');
        expect(entry, isNotNull);
        expect(entry!.completed, isTrue);
        expect(store.entryFor('vod:9')!.fraction, 0); // duration unknown

        await store.clear('vod:9');
        expect(store.entryFor('vod:9'), isNull);
      });

      test('markWatched keeps a duration already recorded', () {
        final store = WatchProgress();
        store.record(
          'ep:9',
          const Duration(minutes: 5),
          const Duration(minutes: 40),
        );
        store.markWatched('ep:9');
        final entry = store.entryFor('ep:9')!;
        expect(entry.duration, const Duration(minutes: 40));
        expect(entry.position, const Duration(minutes: 40));
        expect(entry.completed, isTrue);
      });
    });

    test('zero duration does not divide by zero', () {
      final entry = WatchEntry(
        position: Duration.zero,
        duration: Duration.zero,
        updatedAt: DateTime(2026),
        completed: false,
      );
      expect(entry.fraction, 0);
    });
  });
}
