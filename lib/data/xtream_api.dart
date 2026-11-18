import 'dart:convert';

import 'package:dio/dio.dart';

import 'models.dart';

class XtreamException implements Exception {
  XtreamException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin, typed client for the Xtream Codes `player_api.php` surface.
///
/// The panel dialect is not standardised, so list endpoints return the raw
/// decoded rows and callers map them. Detail endpoints return typed models.
class XtreamApi {
  XtreamApi({
    required String baseUrl,
    required this.username,
    required this.password,
  }) : baseUrl = _normaliseBase(baseUrl);

  final String baseUrl;
  final String username;
  final String password;

  late final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 20),
      headers: const {
        'User-Agent': 'Rogue/1.0 (Flutter)',
        'Accept': 'application/json, text/plain, */*',
      },
    ),
  );

  static String _normaliseBase(String value) {
    var base = value.trim();
    if (base.isEmpty) return base;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(base)) {
      base = 'http://$base';
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  /// Normalised origin used for byte-size comparisons and cache keys.
  String get origin {
    try {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    } catch (_) {
      return baseUrl;
    }
  }

  Uri _endpoint(String path, [Map<String, String> extra = const {}]) {
    final uri = Uri.parse('$baseUrl$path');
    return uri.replace(
      queryParameters: {'username': username, 'password': password, ...extra},
    );
  }

  Future<dynamic> _request(Uri uri, {Duration? timeout}) async {
    final Response<String> response;
    try {
      response = await _dio.getUri<String>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: timeout,
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      throw XtreamException(_describeDio(e));
    }

    final status = response.statusCode ?? 0;
    final body = (response.data ?? '').trim();
    if (status == 401 || status == 403) {
      throw XtreamException(
        'Panel rejected the request (HTTP $status).',
        statusCode: status,
      );
    }
    if (status >= 400) {
      throw XtreamException('Panel returned HTTP $status.', statusCode: status);
    }
    if (body.isEmpty) {
      throw XtreamException(
        'Panel returned an empty response.',
        statusCode: status,
      );
    }
    try {
      return jsonDecode(body);
    } on FormatException {
      throw XtreamException(
        'Panel returned something that is not JSON. Check the server URL and port.',
        statusCode: status,
      );
    }
  }

  String _describeDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The panel took too long to respond.';
      case DioExceptionType.badCertificate:
        return 'The panel certificate is not trusted.';
      case DioExceptionType.connectionError:
        return 'Could not reach the panel. Check the address, port and that it is online.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      default:
        return e.message ?? 'Network error while contacting the panel.';
    }
  }

  // ------------------------------------------------------------------ auth

  Future<AccountInfo> authenticate() async {
    final json = await _request(
      _endpoint('/player_api.php'),
      timeout: const Duration(seconds: 30),
    );
    if (json is! Map) {
      throw XtreamException('Unexpected login response from the panel.');
    }
    final account = AccountInfo.fromJson(json.cast<String, dynamic>());
    if (!account.auth) {
      throw XtreamException(
        account.message ??
            account.status ??
            'Login rejected. Check the username and password.',
      );
    }
    return account;
  }

  // ----------------------------------------------------------------- lists

  Future<List<Map<String, dynamic>>> rows(
    String action, {
    Duration? timeout,
  }) async {
    final json = await _request(
      _endpoint('/player_api.php', {'action': action}),
      timeout: timeout,
    );
    if (json is List) {
      return [
        for (final row in json)
          if (row is Map) row.cast<String, dynamic>(),
      ];
    }
    if (json is Map) {
      final message = asStringOrNull(json['message'] ?? json['error']);
      if (message != null) throw XtreamException(message);
    }
    return const [];
  }

  Future<List<Category>> categories(String action) async {
    final rows = await this.rows(action, timeout: const Duration(seconds: 60));
    return rows
        .map(Category.fromJson)
        .where((c) => c.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<Category>> liveCategories() => categories('get_live_categories');
  Future<List<Category>> vodCategories() => categories('get_vod_categories');
  Future<List<Category>> seriesCategories() =>
      categories('get_series_categories');

  Future<List<LiveStream>> liveStreams() async {
    final rows = await this.rows('get_live_streams');
    return rows
        .map(LiveStream.fromJson)
        .where((s) => s.streamId > 0)
        .toList(growable: false);
  }

  Future<List<VodStream>> vodStreams() async {
    final rows = await this.rows('get_vod_streams');
    return rows
        .map(VodStream.fromJson)
        .where((s) => s.streamId > 0)
        .toList(growable: false);
  }

  Future<List<SeriesItem>> seriesList() async {
    final rows = await this.rows('get_series');
    return rows
        .map(SeriesItem.fromJson)
        .where((s) => s.seriesId > 0)
        .toList(growable: false);
  }

  // ---------------------------------------------------------------- detail

  Future<VodInfo?> vodInfo(int streamId) async {
    final json = await _request(
      _endpoint('/player_api.php', {
        'action': 'get_vod_info',
        'vod_id': '$streamId',
      }),
      timeout: const Duration(seconds: 45),
    );
    if (json is Map) return VodInfo.fromJson(json.cast<String, dynamic>());
    return null;
  }

  Future<SeriesInfo?> seriesInfo(int seriesId) async {
    final json = await _request(
      _endpoint('/player_api.php', {
        'action': 'get_series_info',
        'series_id': '$seriesId',
      }),
      timeout: const Duration(seconds: 60),
    );
    if (json is Map) return SeriesInfo.fromJson(json.cast<String, dynamic>());
    return null;
  }

  Future<List<EpgListing>> shortEpg(int streamId, {int limit = 12}) async {
    final json = await _request(
      _endpoint('/player_api.php', {
        'action': 'get_short_epg',
        'stream_id': '$streamId',
        'limit': '$limit',
      }),
      timeout: const Duration(seconds: 30),
    );
    if (json is Map) {
      final listings = json['epg_listings'];
      if (listings is List) {
        return [
          for (final row in listings)
            if (row is Map) EpgListing.fromJson(row.cast<String, dynamic>()),
        ];
      }
    }
    return const [];
  }

  /// Full XMLTV guide. Large panels can serve tens of megabytes here.
  Future<String> xmltv({Duration timeout = const Duration(minutes: 5)}) async {
    final uri = _endpoint('/xmltv.php');
    try {
      final response = await _dio.getUri<String>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: timeout,
          validateStatus: (_) => true,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 400) {
        throw XtreamException(
          'Guide download failed (HTTP $status).',
          statusCode: status,
        );
      }
      final body = response.data ?? '';
      if (body.trim().isEmpty) {
        throw XtreamException('The panel returned an empty guide.');
      }
      return body;
    } on DioException catch (e) {
      throw XtreamException(_describeDio(e));
    }
  }

  /// Resolves a panel-provided path to an absolute URL.
  ///
  /// Panels are inconsistent here: some return `http://cdn/logo.png`, many
  /// return `/images/logo.png`, and a few return `images/logo.png`.
  String? absolute(String? value) {
    if (value == null) return null;
    final raw = value.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('//')) return '${Uri.parse(baseUrl).scheme}:$raw';
    return raw.startsWith('/') ? '$baseUrl$raw' : '$baseUrl/$raw';
  }

  // ---------------------------------------------------------------- streams

  String liveUrl(int streamId, {String extension = 'ts'}) =>
      '$baseUrl/live/$username/$password/$streamId.$extension';

  String vodUrl(int streamId, String extension) =>
      '$baseUrl/movie/$username/$password/$streamId.$extension';

  String seriesUrl(int episodeId, String extension) =>
      '$baseUrl/series/$username/$password/$episodeId.$extension';

  /// Xtream catch-up ("timeshift") URL.
  ///
  /// Shape confirmed from the original client:
  /// `/timeshift/<user>/<pass>/<minutes>/<yyyy-MM-dd:HH-mm>/<stream_id>.ts`
  ///
  /// [start] must be in the panel's timezone; the guide is stored in local time,
  /// so this is exact when the device and panel share a timezone.
  String timeshiftUrl(int streamId, DateTime start, {required int minutes}) {
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${start.year}-${two(start.month)}-${two(start.day)}'
        ':${two(start.hour)}-${two(start.minute)}';
    return '$baseUrl/timeshift/$username/$password/$minutes/$stamp/$streamId.ts';
  }

  String get xmltvUrl =>
      '$baseUrl/xmltv.php?username=$username&password=$password';
}
