# Playbooks

Recipes for the changes this codebase sees most often. Follow the existing
pattern named in each step instead of inventing a new one.

## Add a screen / tab

1. Create `lib/ui/<name>_screen.dart` using `CatalogScaffold` (catalogue pages)
   or the `Padding` + `SectionHeader` pattern (settings-like pages).
2. Register it in `lib/ui/home_shell.dart`:
   - `_destinations` (sidebar),
   - `_buildPages()` (order must match),
   - the mobile 5-tab bar and the **More** sheet if it is not one of the four
     primary tabs.
3. Extend `shell_test.dart` (it renders every tab) and, if the page shows data,
   add a focused widget test with fake stores.
4. Respect `isCompact(context)`; move any header search field into the body on
   phones (`traversal: false` in the header).

## Add persisted user state

1. Copy the shape of `lib/state/recents.dart`: `ChangeNotifier`, tolerant
   `load()` with a 3 s timeout, `notifyListeners()`, best-effort `_save()` to the
   app support directory.
2. Add it to `AppModel` (constructor parameter with a default, `addListener`,
   `dispose`).
3. Build the UI on `model.<store>`; use `FocusableTap` for rows/cards.
4. Unit-test capping/ordering/JSON in `test/<name>_test.dart`; widget tests must
   inject a subclass whose `load()` is a no-op (`path_provider` is unavailable).

## Add a context-menu action

1. For the standard favourite/watched actions, extend `showItemMenu` in
   `lib/ui/favourites_actions.dart` (new optional parameter + menu item +
   handler + snackbar).
2. For one-off actions (e.g. a whole season), copy the custom `showMenu` recipe
   in `detail_screens.dart` (`_showSeasonMenu`): overlay position, `constraints`,
   single `PopupMenuItem`, snackbar confirmation.
3. Wire both long-press and right-click. With `FocusableTap` use
   `onLongPressStart` / `onSecondaryTapUp`; with a bare gesture detector pass
   `details.globalPosition`.
4. Batch store writes (`markWatchedAll` / `clearAll`) so one action = one
   notification and one save.

## Add a colour scheme

1. Add a `const Palette` to `lib/theme.dart` and include it in `kPalettes`.
2. `theme_test.dart` covers uniqueness/fallbacks automatically; update it only
   if the count assertion changes.
3. Settings renders swatches from `kPalettes`; no UI change needed.

## Touch the player

- Controls live in `_topBar` / `_bottomBar` of `lib/ui/player_screen.dart`.
  Mobile hides the volume slider and swaps fullscreen for a rotate button.
- Phone taps only toggle controls; desktop keeps the ±10 s tap zones.
- Keyboard/TV handling is in `_onKey` (arrows seek, Enter/Select toggles
  controls, media keys play/pause).
- Never create a new `VideoController` per route; use `PlayerService`.
- Record progress through `WatchProgress` (`vod:`/`ep:` keys) — do not invent a
  parallel store.

## Change the update manifest

1. Parse in `lib/updates/update_manifest.dart` (tolerant, per-platform
   artifacts, optional `minSupported`).
2. Publish by extending `tool/make_manifest.mjs` and the publish step in
   `.github/workflows/release.yml`.
3. Tests: `updates_test.dart` for parsing/precedence, `update_service_test.dart`
   for HTTP behaviour.

## Add a platform capability (channel)

1. Android side: `android/app/src/main/kotlin/app/rogue/client/MainActivity.kt`,
   method channel `app.rogue.client/<area>`.
2. Dart side: wrap it behind a class with an injectable seam so tests do not need
   the channel (see `AndroidUpdateInstaller`).
3. Add any permissions/providers to `AndroidManifest.xml` and explain the change
   in `README.md`.

## Fix a UI bug efficiently

1. Reproduce with `tool/mock_panel.dart`, not the real panel.
2. Check the responsive branch: phone (<700), tablet (700–899, mobile chrome but
   wide content) and desktop/TV (≥900, sidebar).
3. For focus/D-pad issues, use `test/tv_focus_test.dart` as a harness — it
   mirrors sidebar + header + grid.
4. Verify with a screenshot (Windows `PrintWindow`, Android `adb`), then run
   `tool/check.ps1`.
