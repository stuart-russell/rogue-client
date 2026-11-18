import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small JSON cache living in the app support directory.
///
/// Everything is written through a temp file + rename so a crash mid-write
/// cannot leave a half-parsed catalog behind.
class DiskCache {
  Directory? _directory;

  Future<Directory> _dir() async {
    final existing = _directory;
    if (existing != null) return existing;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _directory = dir;
    return dir;
  }

  Future<File> _file(String key) async {
    final dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}$key.json');
  }

  Future<Map<String, dynamic>?> read(String key) async {
    try {
      final file = await _file(key);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Object? payload) async {
    try {
      final file = await _file(key);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({
          'savedAt': DateTime.now().toIso8601String(),
          'payload': payload,
        }),
        flush: true,
      );
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    } catch (_) {
      // A cache failure must never break the app.
    }
  }

  Future<void> remove(String key) async {
    try {
      final file = await _file(key);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> removeAll() async {
    try {
      final dir = await _dir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _directory = null;
    } catch (_) {}
  }

  Future<int> totalBytes() async {
    try {
      final dir = await _dir();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  static DateTime? savedAtOf(Map<String, dynamic>? envelope) {
    final raw = envelope?['savedAt'];
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
