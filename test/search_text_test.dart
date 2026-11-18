import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/core/search_text.dart';

void main() {
  group('searchKey', () {
    test('ignores apostrophes', () {
      expect(searchKey("Grey's Anatomy"), searchKey('greys anatomy'));
      expect(searchKey('Grey’s Anatomy'), 'greysanatomy');
    });

    test('treats & as and', () {
      expect(searchKey('Tom & Jerry'), searchKey('Tom and Jerry'));
      expect(searchKey('Tom&Jerry'), 'tomandjerry');
    });

    test('drops dots and spacing', () {
      expect(searchKey('S.W.A.T'), 'swat');
      expect(searchKey('S.W.A.T.'), searchKey('swat'));
      expect(searchKey('  Mr. Robot  '), searchKey('mr robot'));
    });

    test('drops hyphens and other punctuation', () {
      expect(searchKey('Spider-Man'), 'spiderman');
      expect(searchKey('Law & Order: SVU'), 'lawandordersvu');
    });
  });

  group('matchesSearch', () {
    test('matches punctuation variants', () {
      expect(matchesSearch("Grey's Anatomy", 'greys anatomy'), isTrue);
      expect(matchesSearch('Greys Anatomy', "grey's anatomy"), isTrue);
      expect(matchesSearch('Tom & Jerry', 'tom and jerry'), isTrue);
      expect(matchesSearch('Tom and Jerry', 'tom & jerry'), isTrue);
      expect(matchesSearch('S.W.A.T.', 'swat'), isTrue);
      expect(matchesSearch('SWAT', 's.w.a.t'), isTrue);
    });

    test('still filters genuinely different titles', () {
      expect(matchesSearch("Grey's Anatomy", 'greyhound'), isFalse);
      expect(matchesSearch('Tom and Jerry', 'tom hardy'), isFalse);
    });

    test('empty and punctuation-only queries match nothing', () {
      expect(matchesSearch('Anything', ''), isFalse);
      expect(matchesSearch('Anything', ".'&"), isFalse);
    });
  });
}
