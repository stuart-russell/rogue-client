import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../core/app_log.dart';
import '../data/disk_cache.dart';
import '../data/models.dart';
import '../data/xtream_api.dart';

/// Parses an XMLTV document into channel -> ordered programmes.
///
/// Runs on a background isolate: real guides are 10-80 MB.
Map<String, List<Programme>> parseXmltv(String xmlText) {
  final document = XmlDocument.parse(xmlText);
  final result = <String, List<Programme>>{};

  for (final element in document.findAllElements('programme')) {
    final channelId = element.getAttribute('channel');
    if (channelId == null || channelId.isEmpty) continue;

    final start = parseXmltvDate(element.getAttribute('start'));
    if (start == null) continue;
    final stop =
        parseXmltvDate(element.getAttribute('stop')) ??
        start.add(const Duration(minutes: 30));

    var title = '';
    for (final node in element.findElements('title')) {
      final text = node.innerText.trim();
      if (text.isNotEmpty) {
        title = text;
        break;
      }
    }
    if (title.isEmpty) continue;

    String? description;
    for (final node in element.findElements('desc')) {
      final text = node.innerText.trim();
      if (text.isNotEmpty) {
        description = text;
        break;
      }
    }

    result
        .putIfAbsent(channelId, () => [])
        .add(
          Programme(
            channelId: channelId,
            title: title,
            start: start,
            stop: stop,
            description: description,
          ),
        );
  }

  for (final programmes in result.values) {
    programmes.sort((a, b) => a.start.compareTo(b.start));
  }
  return result;
}

final _xmltvStamp = RegExp(
  r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-]\d{4})?\s*$',
);

DateTime? parseXmltvDate(String? raw) {
  if (raw == null) return null;
  final match = _xmltvStamp.firstMatch(raw.trim());
  if (match == null) return null;

  int part(int index, [int fallback = 0]) =>
      int.tryParse(match.group(index) ?? '') ?? fallback;

  final year = part(1);
  final month = part(2, 1);
  final day = part(3, 1);
  final hour = part(4);
  final minute = part(5);
  final second = part(6);
  final offset = match.group(7);

  if (offset == null) {
    return DateTime(year, month, day, hour, minute, second);
  }

  final sign = offset.startsWith('-') ? -1 : 1;
  final offsetHours = int.tryParse(offset.substring(1, 3)) ?? 0;
  final offsetMinutes = int.tryParse(offset.substring(3, 5)) ?? 0;
  final utc = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
  ).subtract(Duration(minutes: sign * (offsetHours * 60 + offsetMinutes)));
  return utc.toLocal();
}

class EpgController extends ChangeNotifier {
  EpgController(this._cache);

  final DiskCache _cache;
  XtreamApi? _api;
  String? _scope;

  Map<String, List<Programme>> _byChannel = const {};
  DateTime? updatedAt;
  bool loading = false;
  String? error;
  int programmeCount = 0;

  bool get hasData => _byChannel.isNotEmpty;

  /// XMLTV is refreshed by the guide when it is older than this.
  static const Duration staleAfter = Duration(hours: 3);

  bool get isStale {
    final when = updatedAt;
    return when == null || DateTime.now().difference(when) > staleAfter;
  }

  void bind(XtreamApi api) {
    final scope = '${api.origin}|${api.username}';
    if (_scope == scope) return;
    _scope = scope;
    _api = api;
    _byChannel = const {};
    updatedAt = null;
    error = null;
    programmeCount = 0;
    _hydrate();
  }

  void unbind() {
    _api = null;
    _scope = null;
    _byChannel = const {};
    updatedAt = null;
    error = null;
    programmeCount = 0;
    notifyListeners();
  }

  String get _key => 'epg_${(_scope ?? 'none').hashCode.toRadixString(16)}';

  Future<void> _hydrate() async {
    final envelope = await _cache.read(_key);
    if (envelope == null) return;
    final payload = envelope['payload'];
    if (payload is! Map) return;

    final channels = payload['channels'];
    if (channels is! Map) return;

    final parsed = <String, List<Programme>>{};
    var total = 0;
    channels.forEach((key, value) {
      if (key is! String || value is! List) return;
      final list = <Programme>[];
      for (final row in value) {
        if (row is Map<String, dynamic>) {
          list.add(Programme.fromCompact(key, row));
        } else if (row is Map) {
          list.add(Programme.fromCompact(key, row.cast<String, dynamic>()));
        }
      }
      if (list.isNotEmpty) {
        list.sort((a, b) => a.start.compareTo(b.start));
        parsed[key] = list;
        total += list.length;
      }
    });

    _byChannel = parsed;
    programmeCount = total;
    updatedAt = DiskCache.savedAtOf(envelope);
    notifyListeners();
  }

  Future<void> load({bool force = false}) async {
    final api = _api;
    if (api == null || loading) return;
    if (!force && hasData) return;

    loading = true;
    error = null;
    notifyListeners();

    try {
      final xml = await api.xmltv();
      final parsed = await compute(parseXmltv, xml);
      _byChannel = parsed;
      programmeCount = parsed.values.fold(0, (sum, list) => sum + list.length);
      updatedAt = DateTime.now();
      AppLog.write(
        'epg loaded: $programmeCount programmes across ${parsed.length} channels',
      );

      await _cache.write(_key, {
        'channels': {
          for (final entry in parsed.entries)
            entry.key: [
              for (final programme in entry.value) programme.toCompact(),
            ],
        },
      });
    } on Exception catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Programme? now(String? channelId) {
    if (channelId == null) return null;
    final list = _byChannel[channelId];
    if (list == null) return null;
    final current = DateTime.now();
    for (final programme in list) {
      if (!current.isBefore(programme.start) &&
          current.isBefore(programme.stop)) {
        return programme;
      }
    }
    return null;
  }

  Programme? next(String? channelId) {
    if (channelId == null) return null;
    final list = _byChannel[channelId];
    if (list == null) return null;
    final current = DateTime.now();
    for (final programme in list) {
      if (programme.start.isAfter(current)) return programme;
    }
    return null;
  }

  List<Programme> forChannel(String? channelId) {
    if (channelId == null) return const [];
    return _byChannel[channelId] ?? const [];
  }

  Future<void> clear() async {
    await _cache.remove(_key);
    _byChannel = const {};
    programmeCount = 0;
    updatedAt = null;
    notifyListeners();
  }
}
