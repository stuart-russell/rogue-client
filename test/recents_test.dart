import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/state/recents.dart';

RecentItem item(RecentType type, int id, int second) => RecentItem(
  type: type,
  id: id,
  name: '${type.name} $id',
  openedAt: DateTime(2026, 1, 1, 0, 0, second),
);

void main() {
  test('keeps the five most recent per type', () async {
    final store = RecentsStore();
    for (var i = 0; i < 7; i++) {
      await store.add(item(RecentType.live, i, i));
    }
    final list = store.of(RecentType.live);
    expect(list, hasLength(RecentsStore.perTypeLimit));
    expect(list.first.id, 6);
    expect(list.last.id, 2);
  });

  test('re-adding moves an item back to the top without duplicating', () async {
    final store = RecentsStore();
    await store.add(item(RecentType.vod, 1, 1));
    await store.add(item(RecentType.vod, 2, 2));
    await store.add(item(RecentType.vod, 1, 3));

    final list = store.of(RecentType.vod);
    expect(list, hasLength(2));
    expect(list.first.id, 1);
    expect(list.last.id, 2);
  });

  test('types are capped independently', () async {
    final store = RecentsStore();
    for (var i = 0; i < 7; i++) {
      await store.add(item(RecentType.live, i, i));
      await store.add(item(RecentType.series, 100 + i, i));
    }
    expect(store.of(RecentType.live), hasLength(5));
    expect(store.of(RecentType.series), hasLength(5));
    expect(store.of(RecentType.vod), isEmpty);
  });

  test('clears everything', () async {
    final store = RecentsStore();
    await store.add(item(RecentType.live, 1, 1));
    await store.clear();
    expect(store.isEmpty, isTrue);
    expect(store.of(RecentType.live), isEmpty);
  });

  test('removes a single entry and leaves the rest intact', () async {
    final store = RecentsStore();
    await store.add(item(RecentType.vod, 1, 1));
    await store.add(item(RecentType.vod, 2, 2));
    await store.remove('vod:1');

    expect(store.of(RecentType.vod), hasLength(1));
    expect(store.of(RecentType.vod).single.id, 2);

    // Removing an unknown key is a no-op.
    await store.remove('vod:99');
    expect(store.of(RecentType.vod), hasLength(1));
  });

  test('JSON round trip', () {
    final entry = RecentItem(
      type: RecentType.series,
      id: 42,
      name: 'A Show',
      image: 'https://cdn/x.jpg',
      categoryId: 7,
      openedAt: DateTime.fromMillisecondsSinceEpoch(1760000000000),
    );
    final restored = RecentItem.fromJson(entry.toJson());
    expect(restored, isNotNull);
    expect(restored!.key, 'series:42');
    expect(restored.image, 'https://cdn/x.jpg');
    expect(restored.categoryId, 7);
    expect(restored.openedAt, entry.openedAt);
  });
}
