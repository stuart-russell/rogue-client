import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum RecentType { live, vod, series }

class RecentItem {
  const RecentItem({
    required this.type,
    required this.id,
    required this.name,
    required this.openedAt,
    this.image,
    this.categoryId,
  });

  final RecentType type;
  final int id;
  final String name;
  final String? image;
  final int? categoryId;
  final DateTime openedAt;

  String get key => '${type.name}:$id';

  Map<String, dynamic> toJson() => {
    't': type.name,
    'i': id,
    'n': name,
    if (image != null) 'm': image,
    if (categoryId != null) 'c': categoryId,
    'o': openedAt.millisecondsSinceEpoch,
  };

  static RecentItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final type = RecentType.values.where((t) => t.name == raw['t']).firstOrNull;
    final id = (raw['i'] as num?)?.toInt();
    final name = raw['n']?.toString();
    if (type == null || id == null || name == null || name.isEmpty) return null;
    return RecentItem(
      type: type,
      id: id,
      name: name,
      image: raw['m']?.toString(),
      categoryId: (raw['c'] as num?)?.toInt(),
      openedAt: DateTime.fromMillisecondsSinceEpoch(
        (raw['o'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// Recently played channels, films and series, capped at [perTypeLimit] each.
class RecentsStore extends ChangeNotifier {
  static const int perTypeLimit = 5;

  final Map<String, RecentItem> _items = {};
  File? _file;
  bool _loaded = false;

  bool get loaded => _loaded;
  bool get isEmpty => _items.isEmpty;

  Future<void> load() async {
    try {
      await _load().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Recents are best-effort.
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _load() async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}recents.json');
    if (!await _file!.exists()) return;
    final decoded = jsonDecode(await _file!.readAsString());
    if (decoded is! Map) return;
    for (final entry in decoded.entries) {
      final item = RecentItem.fromJson(entry.value);
      if (item != null) _items[item.key] = item;
    }
  }

  List<RecentItem> of(RecentType type) {
    final list = _items.values.where((item) => item.type == type).toList()
      ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return list;
  }

  Future<void> add(RecentItem item) async {
    // Re-adding moves the item to the top rather than duplicating it.
    _items.remove(item.key);
    _items[item.key] = item;

    final sameType = _items.values.where((i) => i.type == item.type).toList()
      ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    for (final old in sameType.skip(perTypeLimit)) {
      _items.remove(old.key);
    }

    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    if (_items.isEmpty) return;
    _items.clear();
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
