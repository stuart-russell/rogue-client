import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/data/models.dart';

void main() {
  group('AccountInfo', () {
    test('accepts the string and numeric auth dialects', () {
      final numeric = AccountInfo.fromJson({
        'user_info': {
          'auth': 1,
          'username': 'bob',
          'exp_date': '1893456000',
          'max_connections': '2',
          'active_cons': '1',
        },
        'server_info': {'url': 'panel.example.com', 'port': '8080'},
      });
      expect(numeric.auth, isTrue);
      expect(numeric.maxConnections, 2);
      expect(
        numeric.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1893456000 * 1000),
      );

      final stringy = AccountInfo.fromJson({
        'user_info': {'auth': '0', 'message': 'Invalid username'},
      });
      expect(stringy.auth, isFalse);
      expect(stringy.message, 'Invalid username');
    });
  });

  group('catalogue rows', () {
    test('LiveStream tolerates missing and stringly fields', () {
      final channel = LiveStream.fromJson({
        'stream_id': '42',
        'name': 'Test TV',
        'num': '7',
        'category_id': '3',
        'tv_archive': '1',
        'tv_archive_duration': '5',
      });
      expect(channel.streamId, 42);
      expect(channel.num, 7);
      expect(channel.categoryId, 3);
      expect(channel.hasArchive, isTrue);
      expect(channel.archiveDays, 5);
    });

    test('VodStream reads the container extension', () {
      final movie = VodStream.fromJson({
        'stream_id': 9,
        'name': 'Film',
        'container_extension': 'mkv',
        'rating_5based': '4.5',
      });
      expect(movie.containerExtension, 'mkv');
      expect(movie.rating, 4.5);
    });
  });

  group('SeriesInfo', () {
    test('orders seasons and parses episodes', () {
      final info = SeriesInfo.fromJson({
        'info': {'plot': 'A show', 'genre': 'Drama'},
        'episodes': {
          '2': [
            {
              'id': 200,
              'episode_num': 1,
              'title': 'S2E1',
              'container_extension': 'mkv',
            },
          ],
          '1': [
            {'id': 100, 'episode_num': 1, 'title': 'S1E1'},
          ],
        },
      });
      expect(info.seasons.keys.toList(), [1, 2]);
      expect(info.seasons[2]!.first.id, 200);
      expect(info.seasons[1]!.first.containerExtension, 'mp4');
      expect(info.plot, 'A show');
    });
  });

  group('maybeBase64', () {
    test('decodes a base64 EPG title and leaves plain text alone', () {
      // "News at Six"
      expect(maybeBase64('TmV3cyBhdCBTaXg='), 'News at Six');
      expect(maybeBase64('News at Six'), 'News at Six');
      expect(maybeBase64(''), '');
    });
  });

  group('asImageUrl', () {
    test('unwraps list-shaped strings from panels', () {
      expect(
        asImageUrl('[https://cdn.example/a.jpg]'),
        'https://cdn.example/a.jpg',
      );
      expect(
        asImageUrl('["https://cdn.example/a.jpg","https://cdn.example/b.jpg"]'),
        'https://cdn.example/a.jpg',
      );
      expect(
        asImageUrl(' [ https://cdn.example/a.jpg ] '),
        'https://cdn.example/a.jpg',
      );
    });

    test('accepts lists and plain paths', () {
      expect(
        asImageUrl(['https://cdn.example/a.jpg']),
        'https://cdn.example/a.jpg',
      );
      expect(asImageUrl('/images/logo.png'), '/images/logo.png');
      expect(asImageUrl(''), isNull);
      expect(asImageUrl(null), isNull);
    });
  });

  test('epochToDate rejects zero and nonsense', () {
    expect(epochToDate(0), isNull);
    expect(epochToDate('abc'), isNull);
  });
}
