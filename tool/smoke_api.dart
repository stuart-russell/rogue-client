// End-to-end check of XtreamApi against a local mock panel.
//   dart run tool/smoke_api.dart
import 'dart:convert';
import 'dart:io';

import 'package:rogue/data/xtream_api.dart';

const _xmltv = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="bbc1"><display-name>BBC One</display-name></channel>
  <programme start="20261117120000 +0000" stop="20261117130000 +0000" channel="bbc1">
    <title>Midday News</title><desc>Headlines.</desc>
  </programme>
</tv>''';

Object _route(String action) => switch (action) {
      '' => {
          'user_info': {
            'username': 'tester',
            'password': 'secret',
            'auth': 1,
            'status': 'Active',
            'exp_date': '1893456000',
            'is_trial': '0',
            'active_cons': '1',
            'max_connections': '2',
            'allowed_output_formats': ['m3u8', 'ts'],
          },
          'server_info': {'url': '127.0.0.1', 'port': '8080', 'server_protocol': 'http', 'timezone': 'Europe/London'},
        },
      'get_live_categories' => [
          {'category_id': '1', 'category_name': 'News', 'parent_id': 0},
          {'category_id': '2', 'category_name': 'Sport', 'parent_id': 0},
        ],
      'get_live_streams' => [
          {'num': 1, 'name': 'BBC One', 'stream_id': 101, 'stream_icon': 'http://127.0.0.1/logo1.png', 'epg_channel_id': 'bbc1', 'category_id': '1', 'tv_archive': 1, 'tv_archive_duration': 7},
          {'num': 2, 'name': 'Sky Sports', 'stream_id': 102, 'category_id': '2', 'tv_archive': 0},
        ],
      'get_vod_categories' => [
          {'category_id': '10', 'category_name': 'Action'},
        ],
      'get_vod_streams' => [
          {'num': 1, 'name': 'Test Film', 'stream_id': 500, 'stream_icon': 'http://127.0.0.1/p.jpg', 'category_id': '10', 'container_extension': 'mkv', 'rating_5based': '4.5'},
        ],
      'get_series_categories' => [
          {'category_id': '20', 'category_name': 'Drama'},
        ],
      'get_series' => [
          {'num': 1, 'name': 'Test Show', 'series_id': 900, 'cover': 'http://127.0.0.1/c.jpg', 'category_id': '20', 'genre': 'Drama'},
        ],
      'get_vod_info' => {
          'info': {'plot': 'A film about tests.', 'duration': '01:40:00', 'rating': '7.5', 'movie_image': 'http://127.0.0.1/p.jpg'},
          'movie_data': {'stream_id': 500, 'name': 'Test Film', 'container_extension': 'mkv'},
        },
      'get_series_info' => {
          'info': {'plot': 'A show about tests.', 'cover': 'http://127.0.0.1/c.jpg'},
          'episodes': {
            '1': [
              {'id': 9001, 'episode_num': 1, 'title': 'Pilot', 'container_extension': 'mp4', 'info': {'duration': '00:45:00'}},
            ],
          },
        },
      'get_short_epg' => {
          'epg_listings': [
            {'title': 'Midday News', 'description': 'Headlines', 'start': '2026-11-17 12:00:00', 'end': '2026-11-17 13:00:00', 'channel_id': 'bbc1'},
          ],
        },
      _ => {'message': 'unknown action $action'},
    };

void check(bool condition, String label) {
  if (!condition) {
    stderr.writeln('FAIL  $label');
    exitCode = 1;
  } else {
    stdout.writeln('ok    $label');
  }
}

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final path = request.uri.path;
    final response = request.response;
    if (path == '/xmltv.php') {
      response.headers.contentType = ContentType('application', 'xml', charset: 'utf-8');
      response.write(_xmltv);
    } else {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(_route(request.uri.queryParameters['action'] ?? '')));
    }
    await response.close();
  });

  final api = XtreamApi(
    baseUrl: 'http://127.0.0.1:${server.port}/',
    username: 'tester',
    password: 'secret',
  );

  try {
    final account = await api.authenticate();
    check(account.auth, 'authenticate()');
    check(account.maxConnections == 2, 'max_connections parsed');
    check(account.allowedFormats.contains('m3u8'), 'allowed formats parsed');
    check(account.expiresAt != null, 'expiry parsed');

    final categories = await api.liveCategories();
    check(categories.length == 2, 'live categories');
    check(categories.first.name == 'News', 'category name');

    final channels = await api.liveStreams();
    check(channels.length == 2, 'live streams');
    check(channels.first.epgChannelId == 'bbc1', 'epg channel id');
    check(channels.first.hasArchive && channels.first.archiveDays == 7, 'catch-up metadata');

    final movies = await api.vodStreams();
    check(movies.single.containerExtension == 'mkv', 'vod container extension');

    final shows = await api.seriesList();
    check(shows.single.seriesId == 900, 'series list');

    final vodInfo = await api.vodInfo(500);
    check(vodInfo?.plot == 'A film about tests.', 'vod info');

    final seriesInfo = await api.seriesInfo(900);
    check(seriesInfo?.seasons[1]?.single.title == 'Pilot', 'series info + episodes');

    final epg = await api.shortEpg(101);
    check(epg.single.title == 'Midday News', 'short epg');

    final guide = await api.xmltv();
    check(guide.contains('Midday News'), 'xmltv download');

    final liveUrl = Uri.parse(api.liveUrl(101, extension: 'ts'));
    check(liveUrl.path == '/live/tester/secret/101.ts', 'live url shape');

    final vodUrl = Uri.parse(api.vodUrl(500, 'mkv'));
    check(vodUrl.path == '/movie/tester/secret/500.mkv', 'vod url shape');

    final seriesUrl = Uri.parse(api.seriesUrl(9001, 'mp4'));
    check(seriesUrl.path == '/series/tester/secret/9001.mp4', 'series url shape');

    var rejected = false;
    try {
      await XtreamApi(baseUrl: 'http://127.0.0.1:1', username: 'x', password: 'y').authenticate();
    } on XtreamException {
      rejected = true;
    }
    check(rejected, 'unreachable panel raises XtreamException');
  } finally {
    await server.close(force: true);
  }

  stdout.writeln(exitCode == 0 ? '\nAll API checks passed.' : '\nSome API checks failed.');
}
