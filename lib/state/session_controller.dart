import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/xtream_api.dart';

class SessionController extends ChangeNotifier {
  static const _kServer = 'panel.server';
  static const _kUser = 'panel.username';
  static const _kPass = 'panel.password';

  bool restoring = true;
  bool busy = false;
  String? error;

  XtreamApi? api;
  AccountInfo? account;

  String server = '';
  String username = '';

  bool get signedIn => api != null && account != null;

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      server = prefs.getString(_kServer) ?? '';
      username = prefs.getString(_kUser) ?? '';
      final password = prefs.getString(_kPass) ?? '';
      if (server.isEmpty || username.isEmpty || password.isEmpty) return;

      final candidate = XtreamApi(
        baseUrl: server,
        username: username,
        password: password,
      );
      api = candidate;
      account = await candidate.authenticate();
      server = candidate.baseUrl;
    } on Exception catch (e) {
      api = null;
      account = null;
      error = e.toString();
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String serverUrl,
    required String user,
    required String password,
  }) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();

    final candidate = XtreamApi(
      baseUrl: serverUrl,
      username: user,
      password: password,
    );
    try {
      final info = await candidate.authenticate();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kServer, candidate.baseUrl);
      await prefs.setString(_kUser, user);
      await prefs.setString(_kPass, password);

      api = candidate;
      account = info;
      server = candidate.baseUrl;
      username = user;
      return true;
    } on Exception catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kServer);
    await prefs.remove(_kUser);
    await prefs.remove(_kPass);
    api = null;
    account = null;
    error = null;
    server = '';
    username = '';
    notifyListeners();
  }

  Future<void> clearError() async {
    if (error == null) return;
    error = null;
    notifyListeners();
  }
}
