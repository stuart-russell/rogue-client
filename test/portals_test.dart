import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/data/portals.dart';

void main() {
  group('ROGUE_PORTALS parsing', () {
    test('reads name=url pairs', () {
      final portals = PortalsStore.parseCompiled(
        'Rogue 1=http://a.example:8880|Rogue 2=https://b.example|Empire=http://c.example:2086',
      );
      expect(portals, hasLength(3));
      expect(portals.first.name, 'Rogue 1');
      expect(portals.first.url, 'http://a.example:8880');
      expect(portals.last.name, 'Empire');
    });

    test('skips malformed chunks', () {
      final portals = PortalsStore.parseCompiled(
        'good=http://x|nourl=|=http://y|junk|  ',
      );
      expect(portals, hasLength(1));
      expect(portals.single.name, 'good');
    });

    test('empty input yields no presets', () {
      expect(PortalsStore.parseCompiled(''), isEmpty);
    });
  });

  group('portals.json parsing', () {
    test('reads objects and ignores bad rows', () {
      final portals = PortalsStore.parseJson('''
[
  {"name": "Rogue 1", "url": "http://a:8880"},
  {"name": "", "url": "http://ignored"},
  {"url": "http://also-ignored"},
  "nonsense"
]
''');
      expect(portals, hasLength(1));
      expect(portals.single.name, 'Rogue 1');
    });

    test('invalid json yields empty list', () {
      expect(PortalsStore.parseJson('{not json'), isEmpty);
      expect(PortalsStore.parseJson('{"name":"x"}'), isEmpty);
    });
  });

  group('samePortal', () {
    test('ignores case, whitespace and trailing slashes', () {
      expect(
        samePortal('http://A.example:80/', ' http://a.example:80 '),
        isTrue,
      );
      expect(samePortal('https://b.example', 'http://b.example'), isFalse);
    });
  });
}
