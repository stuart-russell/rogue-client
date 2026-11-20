import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/state/preferences_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('performance mode defaults off and persists', () async {
    final preferences = PreferencesController();
    addTearDown(preferences.dispose);
    await preferences.load();

    expect(preferences.performanceMode, isFalse);

    await preferences.setPerformanceMode(true);

    final reloaded = PreferencesController();
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(reloaded.performanceMode, isTrue);
  });
}
