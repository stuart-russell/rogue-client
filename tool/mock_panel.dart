// ignore_for_file: unnecessary_string_interpolations, unnecessary_brace_in_string_interps

// Local fake Xtream panel for UI work. Nothing here talks to the internet.
//
//   dart run tool/mock_panel.dart            # http://127.0.0.1:8099
//   dart run tool/mock_panel.dart --port 9000
//
// Log in with any username/password, e.g. demo / demo.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';


const _categoryNames = ['News', 'Sport', 'Entertainment', 'Documentary'];

const _channelBases = {
  'News': ['Global News 24', 'Capitol Report', 'World Tonight', 'Business Live', 'Weather Now'],
  'Sport': ['Arena Sports', 'Matchday HD', 'Motor Line', 'Court Central', 'Extreme Channel'],
  'Entertainment': ['Rogue One', 'Cinema Classics', 'Comedy Loft', 'Drama Plus', 'Reality Room'],
  'Documentary': ['Deep Blue', 'Ancient Worlds', 'Engineering Marvels', 'Wild Frontiers', 'Cosmos Today'],
};

const _movieTitles = [
  'The Long Horizon', 'Neon Harbour', 'Paper Cities', 'Last Train North', 'Glass Harbour',
  'A Quiet Signal', 'Midnight Courier', 'The Salt Road', 'Hollow Point', 'Velvet Static',
  'Northern Lights', 'Terminal Velocity', 'The Understudy', 'Blue Hour', 'Iron Garden',
  'Summer Rains', 'The Cartographer', 'Signal Lost', 'Fault Lines', 'Distant Thunder',
  'Second Sun', 'The Quiet Room', 'Gold Coast', 'Winter Palace', 'Open Water',
  'The Archivist', 'Static Bloom', 'Final Approach', 'Crimson Field', 'Low Orbit',
  'The Photograph', 'Night Shift', 'Wildfire', 'Harbour Lights', 'The Last Ferry',
  'Echo Chamber',
];

const _seriesTitles = [
  'Harbour District', 'The Bureau', 'Night Watch', 'Cold Case 9', 'Deep State',
  'The Collective', 'Border Town', 'Signal House', 'The Long Game', 'Fair Weather',
  'Red Line', 'The Attic',
];

const _episodeTitles = [
  'Pilot', 'Low Tide', 'The Call', 'Paper Trail', 'Crossing', 'Blackout',
  'The Return', 'Reckoning', 'Undertow', 'Hard Rain',
];

String _movieName(int index) => _movieTitles[index % _movieTitles.length];

class Channel {
  Channel(this.index, this.categoryId, this.name);

  final int index;
  final int categoryId;
  final String name;

  int get id => 100 + index;
  String get epgId => 'ch$id';
  String get logo => '/logo/$id.png';
}

List<Channel> _channels() {
  final result = <Channel>[];
  var index = 0;
  for (var category = 0; category < _categoryNames.length; category++) {
    final bases = _channelBases[_categoryNames[category]]!;
    for (final base in bases) {
      for (var variant = 1; variant <= 2; variant++) {
        index++;
        result.add(Channel(index, category + 1, '$base ${variant == 1 ? 'HD' : 'SD'}'));
      }
    }
  }
  return result;
}

// ---------------------------------------------------------------- PNG

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final byte in bytes) {
    c = _crcTable[(c ^ byte) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

void _chunk(BytesBuilder out, String type, List<int> data) {
  out.add(_be32(data.length));
  final typed = <int>[...type.codeUnits, ...data];
  out.add(typed);
  out.add(_be32(_crc(typed)));
}

List<int> _be32(int value) => [(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];

int _hsv(int h, double s, double v) {
  final c = v * s;
  final hp = (h % 360) / 60.0;
  final x = c * (1 - ((hp % 2) - 1).abs());
  double r = 0, g = 0, b = 0;
  if (hp < 1) {
    r = c; g = x;
  } else if (hp < 2) {
    r = x; g = c;
  } else if (hp < 3) {
    g = c; b = x;
  } else if (hp < 4) {
    g = x; b = c;
  } else if (hp < 5) {
    r = x; b = c;
  } else {
    r = c; b = x;
  }
  final m = v - c;
  int to8(double value) => ((value + m) * 255).round().clamp(0, 255);
  return (to8(r) << 24) | (to8(g) << 16) | (to8(b) << 8) | 0xFF;
}

Uint8List _gradientPng(int width, int height, int seed) {
  final hue = (seed * 47) % 360;
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0);
    final t = y / height;
    for (var x = 0; x < width; x++) {
      final band = ((x / width) + t) * 0.18;
      final color = _hsv(hue, 0.45, (0.42 - t * 0.3 + band).clamp(0.06, 1.0));
      raw
        ..addByte((color >> 24) & 0xFF)
        ..addByte((color >> 16) & 0xFF)
        ..addByte((color >> 8) & 0xFF)
        ..addByte(color & 0xFF);
    }
  }

  final compressed = ZLibCodec(level: 6).encode(raw.takeBytes());
  final out = BytesBuilder()
    ..add([137, 80, 78, 71, 13, 10, 26, 10]);
  _chunk(out, 'IHDR', [
    ..._be32(width),
    ..._be32(height),
    8, 6, 0, 0, 0,
  ]);
  _chunk(out, 'IDAT', compressed);
  _chunk(out, 'IEND', const []);
  return out.takeBytes();
}

final Map<String, Uint8List> _imageCache = {};

// ---------------------------------------------------------------- payloads

List<Map<String, String>> _categories(String prefix, int offset) => [
      for (var i = 0; i < _categoryNames.length; i++)
        {'category_id': '${offset + i + 1}', 'category_name': '${_categoryNames[i]} $prefix'.trim(), 'parent_id': '0'},
    ];

Map<String, String> _liveRow(Channel channel) => {
      'num': '${channel.index}',
      'name': channel.name,
      'stream_id': '${channel.id}',
      'stream_type': 'live',
      'stream_icon': channel.logo,
      'epg_channel_id': channel.epgId,
      'added': '1700000000',
      'category_id': '${channel.categoryId}',
      'custom_sid': '',
      'tv_archive': channel.index % 3 == 0 ? '1' : '0',
      'direct_source': '',
      'tv_archive_duration': channel.index % 3 == 0 ? '7' : '0',
    };

List<Map<String, String>> _vodRows() => [
      for (var i = 0; i < _movieTitles.length; i++)
        {
          'num': '${i + 1}',
          'name': _movieTitles[i],
          'stream_type': 'movie',
          'stream_id': '${500 + i}',
          'stream_icon': '/poster/${500 + i}.png',
          'rating': '${(6 + (i % 4)).toDouble().toStringAsFixed(1)}',
          'rating_5based': '${(3 + (i % 2)).toDouble().toStringAsFixed(1)}',
          'added': '${1700000000 + i * 86400}',
          'category_id': '${11 + (i % 4)}',
          'container_extension': i % 5 == 0 ? 'mkv' : 'mp4',
        },
    ];

List<Map<String, String>> _seriesRows() => [
      for (var i = 0; i < _seriesTitles.length; i++)
        {
          'num': '${i + 1}',
          'name': _seriesTitles[i],
          'series_id': '${900 + i}',
          'cover': '/poster/${900 + i}.png',
          'plot': 'A ${i.isEven ? 'slow-burn drama' : 'tense thriller'} set in a coastal town.',
          'cast': 'A. Actor, B. Actor',
          'director': 'C. Director',
          'genre': i.isEven ? 'Drama' : 'Thriller',
          'releaseDate': '202${i % 6}-0${(i % 9) + 1}-12',
          'last_modified': '1700000000',
          'rating': '${(7 + (i % 3)).toDouble().toStringAsFixed(1)}',
          'rating_5based': '${(3 + (i % 2)).toDouble().toStringAsFixed(1)}',
          'backdrop_path': '/poster/${900 + i}.png',
          'youtube_trailer': '',
          'episode_run_time': '48',
          'category_id': '${21 + (i % 2)}',
        },
    ];

Map<String, dynamic> _vodInfo(int id) {
  final index = id - 500;
  final extension = index % 5 == 0 ? 'mkv' : 'mp4';
  return {
    'info': {
      'plot': '${_movieName(index)} is a demo entry served by the local mock panel. It exists so the '
          'grids, detail pages and player can be exercised without touching a real subscription.',
      'cast': 'Demo Actor, Sample Actor',
      'director': 'Local Director',
      'genre': ['Drama', 'Thriller', 'Documentary', 'Comedy'][index % 4],
      'releaseDate': '202${index % 6}-0${(index % 9) + 1}-01',
      'duration': '01:${(30 + index).toString().padLeft(2, '0')}:00',
      'rating': '7.${index % 9}',
      'movie_image': '/poster/$id.png',
      'backdrop_path': '/backdrop/$id.png',
    },
    'movie_data': {
      'stream_id': id,
      'name': _movieName(index),
      'added': '1700000000',
      'category_id': '${11 + (index % 4)}',
      'container_extension': extension,
      'custom_sid': '',
      'direct_source': '',
    },
  };
}

Map<String, dynamic> _seriesInfo(int id) {
  final index = id - 900;
  return {
    'info': {
      'plot': '${_seriesTitles[index]}: a demo series served by the local mock panel.',
      'cast': 'Demo Actor, Sample Actor',
      'director': 'Local Director',
      'genre': 'Drama',
      'releaseDate': '2022-03-04',
      'rating': '8.1',
      'cover': '/poster/$id.png',
      'backdrop_path': '/backdrop/$id.png',
    },
    'episodes': {
      for (var season = 1; season <= 2; season++)
        '$season': [
          for (var episode = 1; episode <= 6; episode++)
            {
              'id': id * 100 + season * 10 + episode,
              'episode_num': episode,
              'title': _episodeTitles[(season * 3 + episode) % _episodeTitles.length],
              'container_extension': 'mp4',
              'season': season,
              'info': {
                'plot': 'Season $season, episode $episode of ${_seriesTitles[index]}.',
                'duration': '00:${(40 + episode).toString().padLeft(2, '0')}:00',
                'rating': '7.${episode}',
              },
            },
        ],
    },
  };
}

String _xmltv() {
  final channels = _channels();
  final now = DateTime.now();
  final rounded = DateTime(now.year, now.month, now.day, now.hour, now.minute - now.minute % 30);
  final start = rounded.subtract(const Duration(hours: 4));

  String stamp(DateTime value) {
    final utc = value.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}${two(utc.hour)}${two(utc.minute)}${two(utc.second)} +0000';
  }

  final buffer = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n<tv>\n');
  for (final channel in channels) {
    buffer.writeln('  <channel id="${channel.epgId}"><display-name>${_escape(channel.name)}</display-name></channel>');
  }

  var titleSeed = 0;
  for (final channel in channels) {
    var cursor = start;
    for (var block = 0; block < 48; block++) {
      final length = block % 4 == 0 ? 60 : 30;
      final stop = cursor.add(Duration(minutes: length));
      final category = _categoryNames[(channel.categoryId - 1).clamp(0, 3)];
      final title = '${_programmeTitle(category, titleSeed++)}';
      buffer
        ..writeln('  <programme start="${stamp(cursor)}" stop="${stamp(stop)}" channel="${channel.epgId}">')
        ..writeln('    <title>${_escape(title)}</title>')
        ..writeln('    <desc>${_escape('Demo listing for ${channel.name} on ${category.toLowerCase()} programming.')}</desc>')
        ..writeln('  </programme>');
      cursor = stop;
    }
  }
  buffer.writeln('</tv>');
  return buffer.toString();
}

const _programmePool = [
  'Morning Briefing', 'The Exchange', 'Match of the Day', 'Studio Session', 'Ocean Giants',
  'Breaking Story', 'Courtside', 'Late Edition', 'Archive Hour', 'Wild Weather',
  'Grand Designs', 'Comedy Hour', 'The Interview', 'Night Vault', 'Ancient Roads',
];

String _programmeTitle(String category, int seed) => '${_programmePool[(seed * 7 + category.length) % _programmePool.length]} · $category';

String _escape(String value) =>
    value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

Future<void> main(List<String> args) async {
  final portIndex = args.indexOf('--port');
  final requestedPort = portIndex >= 0 && portIndex + 1 < args.length ? int.tryParse(args[portIndex + 1]) : null;

  final channels = _channels();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, requestedPort ?? 8099);
  final origin = 'http://127.0.0.1:${server.port}';
  stdout.writeln('Mock Xtream panel on $origin');
  stdout.writeln('Log in with any username and password (e.g. demo / demo).');
  stdout.writeln('${channels.length} channels, ${_movieTitles.length} movies, ${_seriesTitles.length} series.');
  stdout.writeln('Ctrl+C to stop.');

  await for (final request in server) {
    final path = request.uri.path;
    final response = request.response;

    if (path == '/xmltv.php') {
      response.headers.contentType = ContentType('application', 'xml', charset: 'utf-8');
      response.write(_xmltv());
      await response.close();
      continue;
    }

    if (path.startsWith('/logo/') || path.startsWith('/poster/') || path.startsWith('/backdrop/')) {
      final seed = int.tryParse(path.split('/').last.replaceAll('.png', '')) ?? 1;
      final image = _imageCache.putIfAbsent(
        path,
        () => _gradientPng(
          path.startsWith('/logo/') ? 160 : 300,
          path.startsWith('/logo/') ? 160 : 450,
          seed,
        ),
      );
      response.headers.contentType = ContentType('image', 'png');
      response.add(image);
      await response.close();
      continue;
    }

    final query = request.uri.queryParameters;
    final action = query['action'] ?? '';
    Object payload;
    switch (action) {
      case '':
        payload = {
          'user_info': {
            'username': query['username'] ?? 'demo',
            'password': query['password'] ?? 'demo',
            'message': 'Demo panel',
            'auth': 1,
            'status': 'Active',
            'exp_date': '1893456000',
            'is_trial': '0',
            'active_cons': '1',
            'created_at': '1600000000',
            'max_connections': '2',
            'allowed_output_formats': ['m3u8', 'ts'],
          },
          'server_info': {
            'url': '127.0.0.1',
            'port': '${server.port}',
            'https_port': '',
            'server_protocol': 'http',
            'rtmp_port': '',
            'timezone': 'Europe/London',
            'timestamp_now': (DateTime.now().millisecondsSinceEpoch ~/ 1000),
            'time_now': DateTime.now().toString().split('.').first,
            'process': true,
          },
        };
      case 'get_live_categories':
        payload = _categories('', 0);
      case 'get_live_streams':
        payload = [for (final channel in channels) _liveRow(channel)];
      case 'get_vod_categories':
        payload = [
          for (var i = 0; i < 4; i++) {'category_id': '${11 + i}', 'category_name': ['Drama', 'Comedy', 'Action', 'Documentary'][i], 'parent_id': '0'},
        ];
      case 'get_vod_streams':
        payload = _vodRows();
      case 'get_series_categories':
        payload = [
          {'category_id': '21', 'category_name': 'Drama', 'parent_id': '0'},
          {'category_id': '22', 'category_name': 'Thriller', 'parent_id': '0'},
        ];
      case 'get_series':
        payload = _seriesRows();
      case 'get_vod_info':
        payload = _vodInfo(int.tryParse(query['vod_id'] ?? '') ?? 500);
      case 'get_series_info':
        payload = _seriesInfo(int.tryParse(query['series_id'] ?? '') ?? 900);
      case 'get_short_epg':
        payload = {
          'epg_listings': [
            {
              'title': 'Demo: on now',
              'description': 'Served by the local mock panel.',
              'start': DateTime.now().toString().split('.').first,
              'end': DateTime.now().add(const Duration(minutes: 30)).toString().split('.').first,
              'channel_id': 'ch100',
              'now_playing': 1,
            },
          ],
        };
      default:
        payload = {'message': 'unknown action $action'};
    }

    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(payload));
    await response.close();
  }
}

