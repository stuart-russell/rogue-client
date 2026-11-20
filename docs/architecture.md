# Architecture

## Layers

```
lib/
  main.dart        boot: logging, media_kit, runApp
  app.dart         RogueApp: AppModel, AppScope, MaterialApp, palette swaps
  theme.dart       Palette, kPalettes, AppColors (mutable), buildAppTheme()
  core/            app log, PIN hashing, search normalisation, Win32 fullscreen
  data/            models, XtreamApi (dio), DiskCache, portals
  state/           AppModel + controllers + stores + players
  updates/         manifest, service, controller, installers
  ui/              shell, screens, shared widgets
```

Import direction is `data → state → ui`. `data/` must stay UI-free.

## State ownership

`AppModel` is the single root. It owns:

| Controller | Responsibility |
|---|---|
| `SessionController` | credentials, account info, saved session |
| `CatalogController` | per-segment streams/categories/counts, adult filter, disk cache |
| `EpgController` | XMLTV download/parse/cache, now/next lookups |
| `PreferencesController` | SharedPreferences-backed settings + palette id |
| `FavouritesStore`, `RecentsStore`, `WatchProgress` | JSON user state |
| `PlayerService`, `PreviewPlayer` | media_kit players (app-lifetime) |
| `UpdateController` | check/download/install |

Every controller is a `ChangeNotifier`; `AppModel` listens to all of them and
re-broadcasts, so `AppScope.of(context)` is enough for any widget. New stateful
services must be added to `AppModel` (listener, dispose) **and** injected via
constructor parameters so tests can replace them with fakes.

## UI structure

- `HomeShell` — width ≥ 900: sidebar with 7 destinations. Otherwise: 5-tab
  bottom bar (Guide, Movies, Series, Search, More) with Recents/Favourites/
  Settings in a sheet.
- Pages are kept alive in an `IndexedStack`, built lazily via `_visited`.
- `CatalogScaffold` provides the header, page padding and actions; phones move
  the search field into the body.
- Screens: guide (`live_guide_screen`), movies, series, search, recents,
  favourites, settings; detail pages and the player are pushed routes.

Responsive helpers live in `lib/ui/responsive.dart` (`isCompact`, `pagePadding`,
`pageTopPadding`). The shell's own breakpoint is 900.

## Focus / TV

`FocusableTap` wraps tappable items with `FocusableActionDetector`: directional
focus, Enter/Select/Space activation, a focus ring via its builder, and
`ensureVisible` so lists follow focus. Header search fields deliberately skip
traversal. Do not put a full-size `Focus` around page content — it captures
directional traversal and blocks entry into lists.

## Player

`PlayerService` owns one `media_kit` player and `VideoController` for the app's
lifetime; the player route binds to it. `PreviewPlayer` is a second, muted
player used by the guide banner and halted whenever the full player opens or the
tab changes (one-connection panels). The Windows embedder needs Impeller
disabled for external textures.

## Updates

`UpdateService` fetches the release manifest and downloads artifacts;
`UpdateController` orchestrates check/skip/verify/stage; installers are
platform-specific (`WindowsUpdateInstaller` junction layout,
`AndroidUpdateInstaller` system package installer). Versions come from
`AppVersion` (`--dart-define=ROGUE_VERSION`, injected by the build scripts).

## Data on disk

App support directory (Windows `%APPDATA%\app.rogue\Rogue`, Android private
storage):

- `portals.json`, `favourites.json`, `recents.json`, `watch_progress.json`
- `cache/` — catalogue + XMLTV cached JSON
- `logs/app.log`

Preferences (live format, guide auto-download, PIN hash, palette) live in
SharedPreferences.

## Windows specifics

- `windows/runner/main.cpp` disables Impeller on purpose.
- `core/fullscreen.dart` uses raw Win32; `window_manager` was removed because it
  deadlocked on exit.
- `install_windows.ps1` and the installer create the versioned-folder +
  `current` junction layout the updater relies on.
