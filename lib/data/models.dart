/// Tolerant parsing helpers for the Xtream Codes API.
///
/// Panels are wildly inconsistent: numbers arrive as strings, booleans as
/// "0"/"1", timestamps as epoch seconds, and some fields are simply absent.
/// Everything here is defensive so a single odd row cannot break a list.
library;

import 'dart:convert';

int asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

int? asIntOrNull(dynamic v) {
  if (v == null) return null;
  final parsed = asInt(v, -1);
  return parsed < 0 ? null : parsed;
}

double asDouble(dynamic v, [double fallback = 0]) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? fallback;
  return fallback;
}

double? asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is String && v.trim().isEmpty) return null;
  final parsed = asDouble(v, double.nan);
  return parsed.isNaN ? null : parsed;
}

String asString(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

String? asStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

bool asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
  return false;
}

DateTime? epochToDate(dynamic v) {
  final seconds = asIntOrNull(v);
  if (seconds == null || seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
}

List<String> asStringList(dynamic v) {
  if (v is List) {
    return v.map((e) => asString(e)).where((e) => e.isNotEmpty).toList();
  }
  if (v is String && v.trim().isNotEmpty) return [v.trim()];
  return const [];
}

/// Some panels base64-encode `title`/`description` in EPG payloads.
String maybeBase64(dynamic v) {
  final raw = asString(v);
  if (raw.isEmpty) return raw;
  if (raw.length < 8 || raw.length % 4 != 0) return raw;
  if (!RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(raw)) return raw;
  try {
    final decoded = String.fromCharCodes(base64Decode(raw));
    final printable = decoded.runes
        .where((r) => r >= 32 || r == 9 || r == 10 || r == 13)
        .length;
    if (decoded.isNotEmpty && printable / decoded.runes.length > 0.95) {
      return decoded;
    }
  } catch (_) {
    // not base64 after all
  }
  return raw;
}

/// Normalises artwork fields.
///
/// Panels are wildly inconsistent here: `stream_icon` may be a string, a list,
/// or a list-shaped string such as `[https://cdn/x.jpg]`. The latter used to be
/// treated as a relative path, producing a 404 against the panel host.
String? asImageUrl(dynamic value) {
  if (value == null) return null;
  if (value is List) {
    for (final item in value) {
      final url = asImageUrl(item);
      if (url != null) return url;
    }
    return null;
  }
  var raw = value.toString().trim();
  if (raw.isEmpty) return null;
  if (raw.startsWith('[')) {
    raw = raw.substring(1);
    if (raw.endsWith(']')) raw = raw.substring(0, raw.length - 1);
    raw = raw.split(',').first.trim();
  }
  raw = raw.replaceAll('"', '').replaceAll("'", '').trim();
  return raw.isEmpty ? null : raw;
}

// ---------------------------------------------------------------------------

class Category {
  const Category({required this.id, required this.name, this.parentId});

  final int id;
  final String name;
  final int? parentId;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: asInt(json['category_id']),
    name: asString(json['category_name'], 'Uncategorised'),
    parentId: asIntOrNull(json['parent_id']),
  );

  @override
  String toString() => name;
}

class AccountInfo {
  const AccountInfo({
    required this.auth,
    this.status,
    this.message,
    this.username,
    this.expiresAt,
    this.createdAt,
    this.isTrial = false,
    this.activeConnections = 0,
    this.maxConnections = 0,
    this.allowedFormats = const [],
    this.serverUrl,
    this.serverProtocol,
    this.port,
    this.httpsPort,
    this.timezone,
    this.serverTime,
    this.process,
  });

  final bool auth;
  final String? status;
  final String? message;
  final String? username;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final bool isTrial;
  final int activeConnections;
  final int maxConnections;
  final List<String> allowedFormats;

  // server_info
  final String? serverUrl;
  final String? serverProtocol;
  final int? port;
  final int? httpsPort;
  final String? timezone;
  final String? serverTime;
  final bool? process;

  int? get daysRemaining {
    final exp = expiresAt;
    if (exp == null) return null;
    final d = exp.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    final user =
        (json['user_info'] as Map?)?.cast<String, dynamic>() ?? const {};
    final server =
        (json['server_info'] as Map?)?.cast<String, dynamic>() ?? const {};
    final authFlag = asBool(user['auth']) || asString(user['auth']) == '1';
    return AccountInfo(
      auth: authFlag,
      status: asStringOrNull(user['status'] ?? user['message']),
      message: asStringOrNull(user['message']),
      username: asStringOrNull(user['username']),
      expiresAt: epochToDate(user['exp_date']),
      createdAt: epochToDate(user['created_at']),
      isTrial: asBool(user['is_trial']),
      activeConnections: asInt(user['active_cons']),
      maxConnections: asInt(user['max_connections']),
      allowedFormats: asStringList(user['allowed_output_formats']),
      serverUrl: asStringOrNull(server['url']),
      serverProtocol: asStringOrNull(server['server_protocol']),
      port: asIntOrNull(server['port']),
      httpsPort: asIntOrNull(server['https_port']),
      timezone: asStringOrNull(server['timezone']),
      serverTime: asStringOrNull(server['time_now']),
      process: server.containsKey('process') ? asBool(server['process']) : null,
    );
  }
}

class LiveStream {
  const LiveStream({
    required this.streamId,
    required this.name,
    this.num = 0,
    this.icon,
    this.categoryId,
    this.epgChannelId,
    this.hasArchive = false,
    this.archiveDays = 0,
    this.tvArchive = 0,
  });

  final int streamId;
  final String name;
  final int num;
  final String? icon;
  final int? categoryId;
  final String? epgChannelId;
  final bool hasArchive;
  final int archiveDays;
  final int tvArchive;

  factory LiveStream.fromJson(Map<String, dynamic> json) => LiveStream(
    streamId: asInt(json['stream_id']),
    name: asString(json['name'], 'Unknown channel'),
    num: asInt(json['num']),
    icon: asImageUrl(json['stream_icon']),
    categoryId: asIntOrNull(json['category_id']),
    epgChannelId: asStringOrNull(json['epg_channel_id']),
    tvArchive: asInt(json['tv_archive']),
    hasArchive: asInt(json['tv_archive']) == 1,
    archiveDays: asInt(json['tv_archive_duration']),
  );
}

class VodStream {
  const VodStream({
    required this.streamId,
    required this.name,
    this.num = 0,
    this.icon,
    this.categoryId,
    this.containerExtension = 'mp4',
    this.rating,
    this.added,
  });

  final int streamId;
  final String name;
  final int num;
  final String? icon;
  final int? categoryId;
  final String containerExtension;
  final double? rating;
  final DateTime? added;

  factory VodStream.fromJson(Map<String, dynamic> json) => VodStream(
    streamId: asInt(json['stream_id']),
    name: asString(json['name'], 'Untitled'),
    num: asInt(json['num']),
    icon: asImageUrl(json['stream_icon']),
    categoryId: asIntOrNull(json['category_id']),
    containerExtension: asString(json['container_extension'], 'mp4'),
    rating:
        asDoubleOrNull(json['rating_5based']) ?? asDoubleOrNull(json['rating']),
    added: epochToDate(json['added']),
  );
}

class SeriesItem {
  const SeriesItem({
    required this.seriesId,
    required this.name,
    this.num = 0,
    this.cover,
    this.categoryId,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    this.backdropPath,
    this.youtubeTrailer,
    this.episodeRunTime,
  });

  final int seriesId;
  final String name;
  final int num;
  final String? cover;
  final int? categoryId;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final double? rating;
  final String? backdropPath;
  final String? youtubeTrailer;
  final String? episodeRunTime;

  factory SeriesItem.fromJson(Map<String, dynamic> json) => SeriesItem(
    seriesId: asInt(json['series_id']),
    name: asString(json['name'], 'Untitled'),
    num: asInt(json['num']),
    cover: asImageUrl(json['cover']),
    categoryId: asIntOrNull(json['category_id']),
    plot: asStringOrNull(json['plot']),
    cast: asStringOrNull(json['cast']),
    director: asStringOrNull(json['director']),
    genre: asStringOrNull(json['genre']),
    releaseDate: asStringOrNull(json['releaseDate'] ?? json['release_date']),
    rating:
        asDoubleOrNull(json['rating_5based']) ?? asDoubleOrNull(json['rating']),
    backdropPath: asImageUrl(json['backdrop_path']),
    youtubeTrailer: asStringOrNull(json['youtube_trailer']),
    episodeRunTime: asStringOrNull(json['episode_run_time']),
  );
}

class VodInfo {
  const VodInfo({
    required this.streamId,
    required this.name,
    required this.containerExtension,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    this.duration,
    this.poster,
    this.backdrop,
    this.youtubeTrailer,
    this.tmdbId,
  });

  final int streamId;
  final String name;
  final String containerExtension;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final double? rating;
  final String? duration;
  final String? poster;
  final String? backdrop;
  final String? youtubeTrailer;
  final String? tmdbId;

  factory VodInfo.fromJson(Map<String, dynamic> json) {
    final info = (json['info'] as Map?)?.cast<String, dynamic>() ?? const {};
    final movie =
        (json['movie_data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return VodInfo(
      streamId: asInt(movie['stream_id']),
      name: asString(movie['name'] ?? info['name'], 'Untitled'),
      containerExtension: asString(movie['container_extension'], 'mp4'),
      plot: asStringOrNull(info['plot'] ?? info['description']),
      cast: asStringOrNull(info['cast'] ?? info['actors']),
      director: asStringOrNull(info['director']),
      genre: asStringOrNull(info['genre']),
      releaseDate: asStringOrNull(info['releasedate'] ?? info['release_date']),
      rating: asDoubleOrNull(info['rating']),
      duration: asStringOrNull(info['duration']),
      poster: asImageUrl(info['movie_image'] ?? info['cover_big']),
      backdrop: asImageUrl(info['backdrop_path']),
      youtubeTrailer: asStringOrNull(info['youtube_trailer']),
      tmdbId: asStringOrNull(info['tmdb_id']),
    );
  }
}

class Episode {
  const Episode({
    required this.id,
    required this.title,
    required this.season,
    required this.episodeNum,
    this.containerExtension = 'mp4',
    this.plot,
    this.duration,
    this.image,
    this.rating,
  });

  final int id;
  final String title;
  final int season;
  final int episodeNum;
  final String containerExtension;
  final String? plot;
  final String? duration;
  final String? image;
  final double? rating;

  factory Episode.fromJson(Map<String, dynamic> json, int season) {
    final info = (json['info'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Episode(
      id: asInt(json['id']),
      title: asString(json['title'], 'Episode ${asInt(json['episode_num'])}'),
      season: asInt(json['season'], season),
      episodeNum: asInt(json['episode_num']),
      containerExtension: asString(json['container_extension'], 'mp4'),
      plot: asStringOrNull(info['plot'] ?? json['plot']),
      duration: asStringOrNull(info['duration']),
      image: asImageUrl(info['movie_image'] ?? json['movie_image']),
      rating: asDoubleOrNull(info['rating']),
    );
  }
}

class SeriesInfo {
  const SeriesInfo({
    required this.seasons,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    this.cover,
    this.backdrop,
    this.youtubeTrailer,
  });

  /// season number -> episodes, ordered.
  final Map<int, List<Episode>> seasons;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final double? rating;
  final String? cover;
  final String? backdrop;
  final String? youtubeTrailer;

  factory SeriesInfo.fromJson(Map<String, dynamic> json) {
    final info = (json['info'] as Map?)?.cast<String, dynamic>() ?? const {};
    final episodes =
        (json['episodes'] as Map?)?.cast<String, dynamic>() ?? const {};
    final seasons = <int, List<Episode>>{};
    for (final entry in episodes.entries) {
      final season = int.tryParse(entry.key) ?? 0;
      final rows = (entry.value as List?) ?? const [];
      seasons[season] = [
        for (final row in rows)
          if (row is Map) Episode.fromJson(row.cast<String, dynamic>(), season),
      ];
    }
    final ordered = seasons.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return SeriesInfo(
      seasons: {for (final e in ordered) e.key: e.value},
      plot: asStringOrNull(info['plot']),
      cast: asStringOrNull(info['cast']),
      director: asStringOrNull(info['director']),
      genre: asStringOrNull(info['genre']),
      releaseDate: asStringOrNull(info['releaseDate'] ?? info['release_date']),
      rating:
          asDoubleOrNull(info['rating']) ??
          asDoubleOrNull(info['rating_5based']),
      cover: asImageUrl(info['cover'] ?? info['movie_image']),
      backdrop: asImageUrl(info['backdrop_path']),
      youtubeTrailer: asStringOrNull(info['youtube_trailer']),
    );
  }
}

class EpgListing {
  const EpgListing({
    required this.title,
    this.description,
    this.start,
    this.end,
    this.channelId,
    this.nowPlaying,
  });

  final String title;
  final String? description;
  final DateTime? start;
  final DateTime? end;
  final String? channelId;
  final bool? nowPlaying;

  factory EpgListing.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(asString(json['start']));
    final end = DateTime.tryParse(asString(json['end']));
    return EpgListing(
      title: maybeBase64(json['title']),
      description: asStringOrNull(maybeBase64(json['description'])),
      start: start ?? epochToDate(json['start_timestamp']),
      end: end ?? epochToDate(json['stop_timestamp']),
      channelId: asStringOrNull(json['channel_id']),
      nowPlaying: json.containsKey('now_playing')
          ? asBool(json['now_playing'])
          : null,
    );
  }
}

class Programme {
  const Programme({
    required this.channelId,
    required this.title,
    required this.start,
    required this.stop,
    this.description,
  });

  final String channelId;
  final String title;
  final DateTime start;
  final DateTime stop;
  final String? description;

  bool get isLive {
    final now = DateTime.now();
    return !now.isBefore(start) && now.isBefore(stop);
  }

  Map<String, dynamic> toCompact() => {
    't': title,
    's': start.millisecondsSinceEpoch,
    'e': stop.millisecondsSinceEpoch,
    if (description != null) 'd': description,
  };

  factory Programme.fromCompact(String channelId, Map<String, dynamic> json) =>
      Programme(
        channelId: channelId,
        title: asString(json['t']),
        start: DateTime.fromMillisecondsSinceEpoch(asInt(json['s'])),
        stop: DateTime.fromMillisecondsSinceEpoch(asInt(json['e'])),
        description: asStringOrNull(json['d']),
      );
}

class PlayableMedia {
  const PlayableMedia({
    required this.url,
    required this.title,
    this.subtitle,
    this.poster,
    this.isLive = false,
    this.progressId,
    this.startAt,
  });

  final String url;
  final String title;
  final String? subtitle;
  final String? poster;
  final bool isLive;

  /// Stable key for watch progress, e.g. `vod:1234` or `ep:5678`.
  final String? progressId;

  /// Where playback should begin (resume); null starts at zero.
  final Duration? startAt;

  PlayableMedia copyWith({Duration? startAt}) => PlayableMedia(
    url: url,
    title: title,
    subtitle: subtitle,
    poster: poster,
    isLive: isLive,
    progressId: progressId,
    startAt: startAt ?? this.startAt,
  );
}
