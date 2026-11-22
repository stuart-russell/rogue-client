# Testing

`tool/check.ps1` runs `dart format --set-exit-if-changed`, `flutter analyze` and
`flutter test`. Currently 107 tests; all must pass.

## What to test where

- **Pure logic / parsing** → plain `test(...)`: `models_test`, `xmltv_test`,
  `search_text_test`, `portals_test`, `watch_progress_test`, `recents_test`,
  `favourites_test`, `theme_test`, `updates_test`.
- **State machines** → construct the controller with fakes:
  `UpdateController(service: fake, installer: fake, currentVersion: …)`.
- **Widgets/screens** → `testWidgets`, pumping `AppScope(model: …)` inside a
  `MaterialApp(theme: buildAppTheme())`.
- **Real filesystem/network plumbing** → a local `HttpServer` or temp dirs:
  `update_service_test` serves a manifest over loopback and verifies hashing;
  `windows_installer_test` creates a real zip and junction (skipped off Windows).

## Fakes and traps

- **`path_provider` is unavailable inside widget tests.** Stores that call it in
  `load()` must be replaced with a subclass that overrides `load()` (see
  `_NoProgress`, `_NoFavourites`, `_NoRecents` in `shell_test.dart`).
- **Don't hit the network.** Use `tool/mock_panel.dart` for manual runs; tests
  use fakes or loopback servers.
- **`pumpAndSettle` can time out** when a screen shows a never-ending spinner
  (detail pages without a panel). Pump fixed frames instead:
  `await tester.pump(); await tester.pump(const Duration(milliseconds: 400));`.
- **Focus tests** need
  `FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional`,
  otherwise `onShowFocusHighlight` never fires. Restore it afterwards.
- **Windows-only tools**: `Platform.isWindows` guards; Linux CI registers a
  skipped test (`windows_installer_test`).
- **`AppColors` are mutable getters** — a widget that reads them cannot be
  `const`; if the analyzer complains about a constant expression, remove the
  `const` rather than hardcoding a colour.
- **Text metrics in tests use Ahem**, so popup menus with long labels can
  overflow. Give `showMenu` explicit `constraints` (see the season menu).

## Useful patterns

Fake update service/installer (`updates_test.dart`):

```dart
class _FakeService extends UpdateService {
  _FakeService(this.manifest) : super(manifestUrl: 'https://example.test/manifest.json');
  @override
  Future<UpdateManifest> fetch() async => manifest;
  // override download()/sha256Of() as needed
}
```

Widget test skeleton:

```dart
final model = AppModel(portalStore: _NoPortals(), progress: _NoProgress(),
    favourites: _NoFavourites(), recents: _NoRecents());
addTearDown(model.dispose);
await model.init();
await tester.pumpWidget(AppScope(model: model,
    child: MaterialApp(theme: buildAppTheme(), home: const HomeShell())));
await tester.pumpAndSettle();
```

## Manual verification

- Windows: `flutter run -d windows` with `tool/mock_panel.dart` running; log in
  with `http://127.0.0.1:8099`, `demo` / `demo`.
- Debug builds accept `ROGUE_TAB=0..6` to open a tab on launch (release builds
  ignore it).
- Android: `tool/build_android.ps1`, install the APK; for the player, a mock
  panel cannot serve video, so a real stream is required. Remember the
  one-connection limit when another device is watching.
- Screenshots on Windows: `PrintWindow` via PowerShell; on Android: `adb shell
  screencap` + `adb pull`. Wireless adb (`adb pair`/`adb connect`) is more
  reliable than the flaky USB link on this machine.
