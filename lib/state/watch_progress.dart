import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// How far through one movie or episode the user got.
class WatchEntry {
  const WatchEntry({
    required this.position,
    required this.duration,
    required this.updatedAt,
    required this.completed,
  });

  final Duration position;
  final Duration duration;
  final DateTime updatedAt;
  final bool completed;

  double get fraction {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  Duration get remaining {
    final left = duration - position;
    return left.isNegative ? Duration.zero : left;
  }

  Map<String, dynamic> toJson() => {
    'p': position.inSeconds,
    'd': duration.inSeconds,
    'u': updatedAt.millisecondsSinceEpoch,
    'c': completed,
  };

  factory WatchEntry.fromJson(Map<String, dynamic> json) => WatchEntry(
    position: Duration(seconds: (json['p'] as num?)?.toInt() ?? 0),
    duration: Duration(seconds: (json['d'] as num?)?.toInt() ?? 0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['u'] as num?)?.toInt() ?? 0,
    ),
    completed: json['c'] == true,
  );
}

/// Persisted watch positions, keyed by `vod:<id>` / `ep:<id>`.
class WatchProgress extends ChangeNotifier {
  final Map<String, WatchEntry> _entries = {};
  File? _file;
  Timer? _saveTimer;
  bool _dirty = false;
  bool _loaded = false;

  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      await _load().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Progress is best-effort; never block startup on it.
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _load() async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}watch_progress.json');
    if (!await _file!.exists()) return;
    final decoded = jsonDecode(await _file!.readAsString());
    if (decoded is! Map) return;
    for (final entry in decoded.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && value is Map) {
        _entries[key] = WatchEntry.fromJson(value.cast<String, dynamic>());
      }
    }
  }

  WatchEntry? entryFor(String? id) => id == null ? null : _entries[id];

  /// How many of [ids] are finished — used for season progress badges.
  int completedCount(Iterable<String> ids) =>
      ids.where((id) => _entries[id]?.completed ?? false).length;

  void record(
    String id,
    Duration position,
    Duration duration, {
    Duration completionSlack = const Duration(seconds: 20),
  }) {
    if (duration.inSeconds <= 0) return;
    final clamped = position > duration ? duration : position;
    // Never let the slack swallow a short item (e.g. a 40 s clip with 30 s slack).
    final slack = completionSlack > duration ~/ 2
        ? duration ~/ 2
        : completionSlack;
    final completed = clamped >= duration - slack;
    _entries[id] = WatchEntry(
      position: completed ? duration : clamped,
      duration: duration,
      updatedAt: DateTime.now(),
      completed: completed,
    );
    _dirty = true;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _save);
  }

  Future<void> clear(String id) async {
    if (_entries.remove(id) == null) return;
    _dirty = true;
    notifyListeners();
    await _save();
  }

  /// Flags an item as finished without playing it. Used by the "Mark as
  /// watched" context-menu action; [duration] is reused when known so the
  /// remaining-time UI stays sensible.
  void markWatched(String id, {Duration? duration}) {
    final total = duration ?? _entries[id]?.duration ?? Duration.zero;
    _entries[id] = WatchEntry(
      position: total,
      duration: total,
      updatedAt: DateTime.now(),
      completed: true,
    );
    _dirty = true;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _save);
  }

  /// Flags a whole season (or any batch) watched in one notification.
  void markWatchedAll(Iterable<String> ids) {
    var changed = false;
    for (final id in ids) {
      final total = _entries[id]?.duration ?? Duration.zero;
      _entries[id] = WatchEntry(
        position: total,
        duration: total,
        updatedAt: DateTime.now(),
        completed: true,
      );
      changed = true;
    }
    if (!changed) return;
    _dirty = true;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _save);
  }

  /// Removes a batch of entries (e.g. "mark season as unwatched").
  Future<void> clearAll(Iterable<String> ids) async {
    var changed = false;
    for (final id in ids) {
      if (_entries.remove(id) != null) changed = true;
    }
    if (!changed) return;
    _dirty = true;
    notifyListeners();
    await _save();
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    await _save();
  }

  Future<void> _save() async {
    final file = _file;
    if (!_dirty || file == null) return;
    try {
      await file.writeAsString(
        jsonEncode({
          for (final entry in _entries.entries) entry.key: entry.value.toJson(),
        }),
        flush: true,
      );
      _dirty = false;
    } catch (_) {
      // Keep the in-memory state; retry on the next record.
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
