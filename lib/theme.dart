import 'package:flutter/material.dart';

/// A complete colour scheme for the app.
///
/// Palettes are immutable so they can be offered in Settings and previewed
/// without side effects; [AppColors] points at whichever one is active.
@immutable
class Palette {
  const Palette({
    required this.id,
    required this.name,
    required this.tagline,
    required this.background,
    required this.backgroundElevated,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.accent,
    required this.blue,
    required this.text,
    required this.textMuted,
    required this.success,
    required this.warning,
  });

  /// Stable key persisted in preferences.
  final String id;
  final String name;
  final String tagline;

  final Color background;
  final Color backgroundElevated;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color accent;
  final Color blue;
  final Color text;
  final Color textMuted;
  final Color success;
  final Color warning;

  Color get accentGlow => accent.withValues(alpha: 0.2);

  /// Colours shown in the Settings swatch, in order.
  List<Color> get preview => [background, surfaceHigh, accent];
}

const Palette roguePalette = Palette(
  id: 'rogue',
  name: 'Rogue',
  tagline: 'Coral on midnight',
  background: Color(0xFF08090D),
  backgroundElevated: Color(0xFF0F1219),
  surface: Color(0xFF151924),
  surfaceHigh: Color(0xFF1D2230),
  border: Color(0xFF272D3D),
  accent: Color(0xFFFF5A62),
  blue: Color(0xFF7AA2FF),
  text: Color(0xFFF4F6FB),
  textMuted: Color(0xFF98A1B8),
  success: Color(0xFF4ADE80),
  warning: Color(0xFFFBBF24),
);

const Palette midnightPalette = Palette(
  id: 'midnight',
  name: 'Midnight',
  tagline: 'Azure on deep navy',
  background: Color(0xFF05080F),
  backgroundElevated: Color(0xFF0A101C),
  surface: Color(0xFF0F1828),
  surfaceHigh: Color(0xFF16223A),
  border: Color(0xFF223350),
  accent: Color(0xFF5B8CFF),
  blue: Color(0xFF7FD1FF),
  text: Color(0xFFF2F6FF),
  textMuted: Color(0xFF93A3BF),
  success: Color(0xFF34D399),
  warning: Color(0xFFF5B847),
);

const Palette emeraldPalette = Palette(
  id: 'emerald',
  name: 'Emerald',
  tagline: 'Mint on pine',
  background: Color(0xFF05100C),
  backgroundElevated: Color(0xFF0A1714),
  surface: Color(0xFF0E2019),
  surfaceHigh: Color(0xFF152B23),
  border: Color(0xFF204034),
  accent: Color(0xFF2FD8A8),
  blue: Color(0xFF66C4FF),
  text: Color(0xFFEFFBF6),
  textMuted: Color(0xFF8FB3A6),
  success: Color(0xFF7BE495),
  warning: Color(0xFFF9C74F),
);

const Palette violetPalette = Palette(
  id: 'violet',
  name: 'Violet',
  tagline: 'Orchid on ink',
  background: Color(0xFF090711),
  backgroundElevated: Color(0xFF110D1D),
  surface: Color(0xFF181326),
  surfaceHigh: Color(0xFF211A33),
  border: Color(0xFF32264C),
  accent: Color(0xFFB67CFF),
  blue: Color(0xFF7AA2FF),
  text: Color(0xFFF7F2FF),
  textMuted: Color(0xFFA79BC2),
  success: Color(0xFF4ADE80),
  warning: Color(0xFFFBBF24),
);

const Palette goldPalette = Palette(
  id: 'gold',
  name: 'Gold',
  tagline: 'Amber on warm charcoal',
  background: Color(0xFF0B0906),
  backgroundElevated: Color(0xFF13100B),
  surface: Color(0xFF1A1611),
  surfaceHigh: Color(0xFF241F17),
  border: Color(0xFF362E22),
  accent: Color(0xFFF5B44E),
  blue: Color(0xFF8FB6FF),
  text: Color(0xFFFBF7EF),
  textMuted: Color(0xFFB3A791),
  success: Color(0xFF7BD88F),
  warning: Color(0xFFFFC95C),
);

const Palette graphitePalette = Palette(
  id: 'graphite',
  name: 'Graphite',
  tagline: 'Steel on slate',
  background: Color(0xFF0A0B0D),
  backgroundElevated: Color(0xFF121316),
  surface: Color(0xFF181A1F),
  surfaceHigh: Color(0xFF22252C),
  border: Color(0xFF333842),
  accent: Color(0xFF8FA6C4),
  blue: Color(0xFF6FD3E8),
  text: Color(0xFFF3F5F8),
  textMuted: Color(0xFF9AA2AF),
  success: Color(0xFF5DD39E),
  warning: Color(0xFFE8C168),
);

const List<Palette> kPalettes = [
  roguePalette,
  midnightPalette,
  emeraldPalette,
  violetPalette,
  goldPalette,
  graphitePalette,
];

Palette paletteById(String? id) => kPalettes.firstWhere(
  (palette) => palette.id == id,
  orElse: () => roguePalette,
);

/// The active palette, read through [AppColors] by every widget.
class AppColors {
  const AppColors._();

  static Palette current = roguePalette;

  static Palette get palette => current;

  static Color get background => current.background;
  static Color get backgroundElevated => current.backgroundElevated;
  static Color get surface => current.surface;
  static Color get surfaceHigh => current.surfaceHigh;
  static Color get border => current.border;
  static Color get accent => current.accent;
  static Color get accentGlow => current.accentGlow;
  static Color get blue => current.blue;
  static Color get text => current.text;
  static Color get textMuted => current.textMuted;
  static Color get success => current.success;
  static Color get warning => current.warning;
}

const kRadii = 14.0;

ThemeData buildAppTheme([Palette palette = roguePalette]) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: palette.accent,
        onPrimary: Colors.white,
        secondary: palette.blue,
        surface: palette.background,
        onSurface: palette.text,
        surfaceContainerHighest: palette.surfaceHigh,
        outline: palette.border,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    dividerColor: palette.border,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    iconTheme: IconThemeData(color: palette.text, size: 20),
    textTheme: TextTheme(
      displayLarge: const TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
      ),
      headlineMedium: const TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: const TextStyle(fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: palette.text, height: 1.35),
      bodySmall: TextStyle(color: palette.textMuted, height: 1.3),
      labelLarge: const TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(7),
      radius: const Radius.circular(8),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered)
            ? Color.lerp(palette.border, palette.textMuted, 0.55)
            : palette.border,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surfaceHigh,
      contentTextStyle: TextStyle(color: palette.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

BoxDecoration glassPanel({double radius = kRadii, Color? color}) =>
    BoxDecoration(
      color: color ?? AppColors.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
    );

InputDecoration fieldDecoration({
  required String label,
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  prefixIcon: prefixIcon,
  suffixIcon: suffixIcon,
  filled: true,
  fillColor: AppColors.surfaceHigh,
  labelStyle: TextStyle(color: AppColors.textMuted),
  hintStyle: TextStyle(color: AppColors.textMuted),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: AppColors.accent, width: 1.4),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: AppColors.accent),
  ),
);
