import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/app_log.dart';
import '../data/disk_cache.dart';
import '../data/portals.dart';
import 'catalog_controller.dart';
import 'epg_controller.dart';
import 'favourites.dart';
import 'player_service.dart';
import 'preferences_controller.dart';
import 'recents.dart';
import 'session_controller.dart';
import 'watch_progress.dart';
import '../updates/update_controller.dart';

/// Root state container. Aggregates the three controllers and re-broadcasts
/// their notifications so widgets have a single listenable.
class AppModel extends ChangeNotifier {
  AppModel({
    PortalsStore? portalStore,
    WatchProgress? progress,
    FavouritesStore? favourites,
    RecentsStore? recents,
    UpdateController? updates,
  }) : portalStore = portalStore ?? PortalsStore(),
       progress = progress ?? WatchProgress(),
       favourites = favourites ?? FavouritesStore(),
       recents = recents ?? RecentsStore(),
       updates = updates ?? UpdateController() {
    session.addListener(_relay);
    catalog.addListener(_relay);
    epg.addListener(_relay);
    preferences.addListener(_relay);
    this.progress.addListener(_relay);
    this.favourites.addListener(_relay);
    this.recents.addListener(_relay);
    this.updates.addListener(_relay);
  }

  final DiskCache cache = DiskCache();
  final PortalsStore portalStore;
  List<PortalPreset> portals = const [];
  final SessionController session = SessionController();

  late final CatalogController catalog = CatalogController(cache);
  late final EpgController epg = EpgController(cache);
  final PreferencesController preferences = PreferencesController();
  final WatchProgress progress;
  final FavouritesStore favourites;
  final RecentsStore recents;
  final UpdateController updates;
  final PlayerService player = PlayerService();

  bool initialised = false;

  void _relay() => notifyListeners();

  Future<void> init() async {
    await preferences.load();
    portals = await portalStore.load();
    await progress.load();
    await favourites.load();
    await recents.load();
    catalog.setAdultFilter(preferences.adultFilterEnabled);
    await session.restore();
    if (session.api != null) _attach();
    initialised = true;
    notifyListeners();
    unawaited(updates.start());
  }

  Future<bool> login({
    required String serverUrl,
    required String user,
    required String password,
  }) async {
    AppLog.write('login attempt server=$serverUrl user=$user');
    final ok = await session.login(
      serverUrl: serverUrl,
      user: user,
      password: password,
    );
    if (ok) {
      AppLog.write('login ok');
      _attach();
    } else {
      AppLog.write('login failed: ${session.error}');
    }
    return ok;
  }

  Future<void> logout() async {
    catalog.unbind();
    epg.unbind();
    await session.logout();
  }

  void _attach() {
    final api = session.api;
    if (api == null) return;
    catalog.bind(api);
    epg.bind(api);
  }

  @override
  void dispose() {
    session.removeListener(_relay);
    catalog.removeListener(_relay);
    epg.removeListener(_relay);
    preferences.removeListener(_relay);
    progress.removeListener(_relay);
    favourites.removeListener(_relay);
    recents.removeListener(_relay);
    updates.removeListener(_relay);
    session.dispose();
    catalog.dispose();
    epg.dispose();
    preferences.dispose();
    progress.dispose();
    favourites.dispose();
    recents.dispose();
    updates.dispose();
    player.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppModel> {
  const AppScope({super.key, required AppModel model, required super.child})
    : super(notifier: model);

  static AppModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }

  /// Reads without subscribing, for callbacks.
  static AppModel read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }
}
