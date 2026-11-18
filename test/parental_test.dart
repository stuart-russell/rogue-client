import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/core/adult_filter.dart';
import 'package:rogue/core/pin.dart';
import 'package:rogue/state/preferences_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('adult category detection', () {
    test('matches common panel names', () {
      expect(isAdultCategoryName('For Adults'), isTrue);
      expect(isAdultCategoryName('VIP | Adult'), isTrue);
      expect(isAdultCategoryName('XXX'), isTrue);
      expect(isAdultCategoryName('Erotic'), isTrue);
    });

    test('does not hide mainstream categories', () {
      expect(isAdultCategoryName('Adult Swim'), isFalse);
      expect(isAdultCategoryName('UK | Entertainment'), isFalse);
      expect(isAdultCategoryName('Sport'), isFalse);
    });
  });

  group('PIN hashing', () {
    test('is stable for the same salt', () {
      final salt = newPinSalt();
      expect(hashPin('1234', salt), hashPin('1234', salt));
      expect(hashPin('1234', salt), isNot(hashPin('4321', salt)));
    });

    test('changes with the salt', () {
      expect(
        hashPin('1234', newPinSalt()),
        isNot(hashPin('1234', newPinSalt())),
      );
    });
  });

  group('PreferencesController parental settings', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('stores and verifies a PIN', () async {
      final prefs = PreferencesController();
      await prefs.load();
      expect(prefs.hasAdultPin, isFalse);

      await prefs.setAdultPin('4821');
      expect(prefs.hasAdultPin, isTrue);
      expect(prefs.verifyAdultPin('4821'), isTrue);
      expect(prefs.verifyAdultPin('0000'), isFalse);

      await prefs.setAdultFilterEnabled(true);
      expect(prefs.adultFilterEnabled, isTrue);

      await prefs.clearAdultPin();
      expect(prefs.hasAdultPin, isFalse);
      expect(prefs.verifyAdultPin('4821'), isFalse);
    });

    test('persists the filter flag', () async {
      final first = PreferencesController();
      await first.load();
      await first.setAdultFilterEnabled(true);

      final second = PreferencesController();
      await second.load();
      expect(second.adultFilterEnabled, isTrue);
    });
  });
}
