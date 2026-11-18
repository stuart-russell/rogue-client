import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/state/epg_controller.dart';

const _xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="bbc1"><display-name>BBC One</display-name></channel>
  <channel id="itv1"><display-name>ITV</display-name></channel>
  <programme start="20261117120000 +0000" stop="20261117130000 +0000" channel="bbc1">
    <title>Midday News</title>
    <desc>The headlines.</desc>
  </programme>
  <programme start="20261117130000 +0000" stop="20261117133000 +0000" channel="bbc1">
    <title>Weather</title>
  </programme>
  <programme start="20261117120000 +0100" stop="20261117123000 +0100" channel="itv1">
    <title>Local</title>
  </programme>
</tv>
''';

void main() {
  group('parseXmltv', () {
    test('groups programmes by channel in start order', () {
      final guide = parseXmltv(_xml);

      expect(guide.keys, containsAll(['bbc1', 'itv1']));
      expect(guide['bbc1'], hasLength(2));
      expect(guide['bbc1']!.first.title, 'Midday News');
      expect(guide['bbc1']!.first.description, 'The headlines.');
      expect(guide['bbc1']!.last.title, 'Weather');
    });

    test('honours the UTC offset', () {
      final guide = parseXmltv(_xml);

      // 12:00 +0000 is 11:00 in the +0100 channel's frame.
      final bbc = guide['bbc1']!.first.start.toUtc();
      final itv = guide['itv1']!.first.start.toUtc();
      expect(bbc, DateTime.utc(2026, 11, 17, 12));
      expect(itv, DateTime.utc(2026, 11, 17, 11));
    });

    test('ignores entries without a channel or start', () {
      const broken = '''
<tv>
  <programme channel="x"><title>No start</title></programme>
  <programme start="20261117120000 +0000"><title>No channel</title></programme>
  <programme start="20261117120000 +0000" channel="y"><title>Good</title></programme>
</tv>''';
      final guide = parseXmltv(broken);
      expect(guide.keys, ['y']);
    });
  });

  group('parseXmltvDate', () {
    test('parses a bare stamp as local time', () {
      final value = parseXmltvDate('20261117093000');
      expect(value, DateTime(2026, 11, 17, 9, 30));
    });

    test('returns null for garbage', () {
      expect(parseXmltvDate('later'), isNull);
      expect(parseXmltvDate(null), isNull);
    });
  });
}
