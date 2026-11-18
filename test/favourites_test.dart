import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/state/favourites.dart';

void main() {
  test('favourite JSON round trip', () {
    final favourite = Favourite(
      type: FavouriteType.vod,
      id: 42,
      name: 'A Film',
      image: 'https://cdn/x.jpg',
      categoryId: 3,
      containerExtension: 'mkv',
      addedAt: DateTime.fromMillisecondsSinceEpoch(1760000000000),
    );
    final restored = Favourite.fromJson(favourite.toJson());
    expect(restored, isNotNull);
    expect(restored!.key, 'vod:42');
    expect(restored.name, 'A Film');
    expect(restored.image, 'https://cdn/x.jpg');
    expect(restored.categoryId, 3);
    expect(restored.containerExtension, 'mkv');
    expect(restored.addedAt, favourite.addedAt);
  });

  test('rejects malformed favourites', () {
    expect(Favourite.fromJson(null), isNull);
    expect(Favourite.fromJson({'t': 'nope', 'i': 1, 'n': 'x'}), isNull);
    expect(Favourite.fromJson({'t': 'vod', 'n': 'x'}), isNull);
  });

  test('toggle adds, lists and removes', () async {
    final store = FavouritesStore();
    final favourite = Favourite(
      type: FavouriteType.series,
      id: 7,
      name: 'A Show',
      addedAt: DateTime(2026, 11, 17),
    );

    expect(store.contains(FavouriteType.series, 7), isFalse);
    await store.toggle(favourite);
    expect(store.contains(FavouriteType.series, 7), isTrue);
    expect(store.length, 1);
    expect(store.of(FavouriteType.series).single.name, 'A Show');
    expect(store.of(FavouriteType.vod), isEmpty);

    await store.toggle(favourite);
    expect(store.contains(FavouriteType.series, 7), isFalse);
    expect(store.isEmpty, isTrue);
  });
}
