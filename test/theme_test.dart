import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/state/preferences_controller.dart';
import 'package:rogue/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.current = roguePalette;
  });

  tearDown(() {
    AppColors.current = roguePalette;
  });

  test('every palette is distinct and fully specified', () {
    expect(kPalettes.length, greaterThanOrEqualTo(4));
    expect(kPalettes.map((p) => p.id).toSet(), hasLength(kPalettes.length));
    expect(kPalettes.map((p) => p.name).toSet(), hasLength(kPalettes.length));
    for (final palette in kPalettes) {
      expect(palette.accent, isNot(palette.background));
      expect(palette.text, isNot(palette.textMuted));
      expect(palette.preview, hasLength(3));
    }
  });

  test('paletteById falls back to the default', () {
    expect(paletteById('midnight').id, 'midnight');
    expect(paletteById('nope').id, roguePalette.id);
    expect(paletteById(null).id, roguePalette.id);
  });

  test('buildAppTheme follows the palette', () {
    for (final palette in kPalettes) {
      final theme = buildAppTheme(palette);
      expect(theme.colorScheme.primary, palette.accent);
      expect(theme.scaffoldBackgroundColor, palette.background);
      expect(theme.iconTheme.color, palette.text);
    }
  });

  test('selecting a palette updates AppColors and persists', () async {
    final prefs = PreferencesController();
    await prefs.load();
    expect(prefs.palette.id, roguePalette.id);

    await prefs.setPalette('violet');
    expect(prefs.paletteId, 'violet');
    expect(AppColors.accent, violetPalette.accent);
    expect(AppColors.background, violetPalette.background);

    final reloaded = PreferencesController();
    await reloaded.load();
    expect(reloaded.paletteId, 'violet');

    // Unknown ids collapse back to the default instead of breaking startup.
    await reloaded.setPalette('nonsense');
    expect(reloaded.paletteId, roguePalette.id);
  });
}
