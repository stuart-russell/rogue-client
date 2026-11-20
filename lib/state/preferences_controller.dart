import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/pin.dart';
import '../theme.dart';

/// Small persisted user settings that do not belong to the panel.
class PreferencesController extends ChangeNotifier {
  static const _kLiveExtension = 'playback.liveExtension';
  static const _kAutoGuide = 'guide.autoDownload';
  static const _kAdultFilter = 'parental.adultFilter';
  static const _kAdultPinHash = 'parental.pinHash';
  static const _kAdultPinSalt = 'parental.pinSalt';
  static const _kPalette = 'appearance.palette';
  static const _kPerformance = 'playback.performanceMode';

  String liveExtension = 'ts';
  bool autoDownloadGuide = true;
  bool adultFilterEnabled = false;
  bool performanceMode = false;
  String paletteId = roguePalette.id;
  bool loaded = false;

  Palette get palette => paletteById(paletteId);

  String? _pinHash;
  String? _pinSalt;

  bool get hasAdultPin => _pinHash != null && _pinSalt != null;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      liveExtension = prefs.getString(_kLiveExtension) ?? 'ts';
      autoDownloadGuide = prefs.getBool(_kAutoGuide) ?? true;
      adultFilterEnabled = prefs.getBool(_kAdultFilter) ?? false;
      performanceMode = prefs.getBool(_kPerformance) ?? false;
      paletteId = paletteById(prefs.getString(_kPalette)).id;
      _pinHash = prefs.getString(_kAdultPinHash);
      _pinSalt = prefs.getString(_kAdultPinSalt);
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  Future<void> setLiveExtension(String value) async {
    if (value == liveExtension) return;
    liveExtension = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLiveExtension, value);
  }

  Future<void> setAutoDownloadGuide(bool value) async {
    if (value == autoDownloadGuide) return;
    autoDownloadGuide = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoGuide, value);
  }

  Future<void> setAdultFilterEnabled(bool value) async {
    if (value == adultFilterEnabled) return;
    adultFilterEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAdultFilter, value);
  }

  Future<void> setPerformanceMode(bool value) async {
    if (value == performanceMode) return;
    performanceMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPerformance, value);
  }

  Future<void> setPalette(String id) async {
    final palette = paletteById(id);
    if (palette.id == paletteId) return;
    paletteId = palette.id;
    AppColors.current = palette;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPalette, palette.id);
  }

  Future<void> setAdultPin(String pin) async {
    final salt = newPinSalt();
    _pinSalt = salt;
    _pinHash = hashPin(pin, salt);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAdultPinSalt, salt);
    await prefs.setString(_kAdultPinHash, _pinHash!);
  }

  Future<void> clearAdultPin() async {
    _pinHash = null;
    _pinSalt = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAdultPinHash);
    await prefs.remove(_kAdultPinSalt);
  }

  bool verifyAdultPin(String pin) {
    final hash = _pinHash;
    final salt = _pinSalt;
    if (hash == null || salt == null) return false;
    return hashPin(pin, salt) == hash;
  }
}
