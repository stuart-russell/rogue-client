import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/data/xtream_api.dart';

void main() {
  group('url builders', () {
    final api = XtreamApi(
      baseUrl: 'http://panel.example:8880/',
      username: 'user',
      password: 'pass',
    );

    test('normalises the base url', () {
      expect(api.baseUrl, 'http://panel.example:8880');
      expect(api.origin, 'http://panel.example:8880');
    });

    test('live / vod / series shapes', () {
      expect(Uri.parse(api.liveUrl(101)).path, '/live/user/pass/101.ts');
      expect(
        Uri.parse(api.liveUrl(101, extension: 'm3u8')).path,
        '/live/user/pass/101.m3u8',
      );
      expect(
        Uri.parse(api.vodUrl(500, 'mkv')).path,
        '/movie/user/pass/500.mkv',
      );
      expect(
        Uri.parse(api.seriesUrl(9001, 'mp4')).path,
        '/series/user/pass/9001.mp4',
      );
    });

    test('catch-up shape matches the original client', () {
      final url = api.timeshiftUrl(
        101,
        DateTime(2026, 11, 17, 20, 30),
        minutes: 60,
      );
      expect(
        Uri.parse(url).path,
        '/timeshift/user/pass/60/2026-11-17:20-30/101.ts',
      );
    });

    test('resolves panel-relative artwork', () {
      expect(
        api.absolute('/images/logo.png'),
        'http://panel.example:8880/images/logo.png',
      );
      expect(
        api.absolute('images/logo.png'),
        'http://panel.example:8880/images/logo.png',
      );
      expect(
        api.absolute('https://cdn.example/logo.png'),
        'https://cdn.example/logo.png',
      );
      expect(
        api.absolute('//cdn.example/logo.png'),
        'http://cdn.example/logo.png',
      );
      expect(api.absolute('  '), isNull);
      expect(api.absolute(null), isNull);
    });
  });
}
