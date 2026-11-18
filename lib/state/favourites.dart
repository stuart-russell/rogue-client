import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum FavouriteType { live, vod, series }

class Favourite {
  const Favourite({
    required this.type,
    required this.id,
    required this.name,
    required this.addedAt,
    this.image,
    this.categoryId,
    this.containerExtension,
  });

  final FavouriteType type;
  final int id;
  final String name;
  final String? image;
  final int? categoryId;
  final String? containerExtension;
  final DateTime addedAt;

  String get key => '${type.name}:$id';

  Map<String, dynamic> toJson() => {
    't': type.name,
    'i': id,
    'n': name,
    if (image != null) 'm': image,
    if (categoryId != null) 'c': categoryId,
    if (containerExtension != null) 'e': containerExtension,
    'a': addedAt.millisecondsSinceEpoch,
  };

  static Favourite? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final type = FavouriteType.values
        .where((t) => t.name == raw['t'])
        .firstOrNull;
    if (type == null) return null;
    final id = (raw['i'] as num?)?.toInt();
    final name = raw['n']?.toString();
    if (id == null || name == null || name.isEmpty) return null;
    return Favourite(
      type: type,
      id: id,
      name: name,
      image: raw['m']?.toString(),
      categoryId: (raw['c'] as num?)?.toInt(),
      containerExtension: raw['e']?.toString(),
      addedAt: DateTime.fromMillisecondsSinceEpoch(
        (raw['a'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// Persisted favourites (channels, films, series).
class FavouritesStore extends ChangeNotifier {
  final Map<String, Favourite> _items = {};
  File? _file;
  bool _loaded = false;

  bool get loaded => _loaded;
  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;

  Future<void> load() async {
    try {
      await _load().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Favourites are best-effort; never block startup.
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _load() async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}favourites.json');
    if (!await _file!.exists()) return;
    final decoded = jsonDecode(await _file!.readAsString());
    if (decoded is! Map) return;
    for (final entry in decoded.entries) {
      final favourite = Favourite.fromJson(entry.value);
      if (favourite != null) _items[favourite.key] = favourite;
    }
  }

  bool contains(FavouriteType type, int id) =>
      _items.containsKey('${type.name}:$id');

  List<Favourite> of(FavouriteType type) {
    final list = _items.values.where((f) => f.type == type).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  Future<void> toggle(Favourite favourite) async {
    if (_items.remove(favourite.key) == null) {
      _items[favourite.key] = favourite;
    }
    notifyListeners();
    await _save();
  }

  Future<void> remove(String key) async {
    if (_items.remove(key) == null) return;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(
        jsonEncode({
          for (final entry in _items.entries) entry.key: entry.value.toJson(),
        }),
        flush: true,
      );
    } catch (_) {
      // Keep the in-memory state.
    }
  }
}
