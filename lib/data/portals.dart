import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PortalPreset {
  const PortalPreset({required this.name, required this.url});

  final String name;
  final String url;

  Map<String, String> toJson() => {'name': name, 'url': url};

  @override
  String toString() => '$name ($url)';
}

/// Portal presets shown in the login dropdown.
///
/// Source of truth is `portals.json` in the app support directory, so it can be
/// edited without rebuilding:
///
/// ```json
/// [{"name": "Rogue 1", "url": "http://example:8080"}]
/// ```
///
/// On first run the file is seeded from the `ROGUE_PORTALS` build define:
///
///   --dart-define=ROGUE_PORTALS="Rogue 1=http://a:8880|Rogue 2=https://b"
class PortalsStore {
  static const String _compiledPortals = String.fromEnvironment(
    'ROGUE_PORTALS',
  );
  static const String _compiledDefault = String.fromEnvironment(
    'ROGUE_DEFAULT_SERVER',
  );
  static const String _fileName = 'portals.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  Future<List<PortalPreset>> load() async {
    try {
      return await _load().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Never let portal configuration block login, and never hang on a slow
      // or unavailable support directory.
      return parseCompiled(_compiledPortals);
    }
  }

  Future<List<PortalPreset>> _load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final parsed = parseJson(await file.readAsString());
        if (parsed.isNotEmpty) return parsed;
      }

      final seeded = await _seed();
      if (seeded.isNotEmpty) {
        await file.writeAsString(
          jsonEncode([for (final p in seeded) p.toJson()]),
        );
      }
      return seeded;
    } catch (_) {
      return parseCompiled(_compiledPortals);
    }
  }

  Future<List<PortalPreset>> _seed() async {
    final compiled = parseCompiled(_compiledPortals);
    if (compiled.isNotEmpty) return compiled;
    if (_compiledDefault.isNotEmpty) {
      return [PortalPreset(name: 'Default', url: _compiledDefault)];
    }
    return const [];
  }

  /// `Name=url|Name2=url2` (the shape used by the `ROGUE_PORTALS` define).
  static List<PortalPreset> parseCompiled(String raw) {
    final result = <PortalPreset>[];
    for (final chunk in raw.split('|')) {
      final trimmed = chunk.trim();
      if (trimmed.isEmpty) continue;
      final separator = trimmed.indexOf('=');
      if (separator <= 0) continue;
      final name = trimmed.substring(0, separator).trim();
      final url = trimmed.substring(separator + 1).trim();
      if (name.isEmpty || url.isEmpty) continue;
      result.add(PortalPreset(name: name, url: url));
    }
    return result;
  }

  static List<PortalPreset> parseJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final result = <PortalPreset>[];
      for (final row in decoded) {
        if (row is! Map) continue;
        final name = (row['name'] ?? '').toString().trim();
        final url = (row['url'] ?? '').toString().trim();
        if (name.isEmpty || url.isEmpty) continue;
        result.add(PortalPreset(name: name, url: url));
      }
      return result;
    } catch (_) {
      return const [];
    }
  }
}

/// Loose comparison so `http://host:80/` and `http://host` count as the same.
bool samePortal(String a, String b) {
  String normalise(String value) {
    var result = value.trim().toLowerCase();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  return normalise(a) == normalise(b);
}
