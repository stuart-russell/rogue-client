# Rogue

An independent, ad-free IPTV client for **Xtream Codes** panels — a cleaner
replacement for the white-label Android app that ships with a subscription.

Flutter 3.47 · Windows desktop + Android (phone/TV) · MediaKit (libmpv) playback.

## What it talks to

Panels expose a stock Xtream API, so this app uses the public endpoints — no
scraping and no private protocol:

```
/player_api.php?username=&password=                -> account + server info
   &action=get_live_categories | get_live_streams
   &action=get_vod_categories  | get_vod_streams | get_vod_info&vod_id=
   &action=get_series          | get_series_categories | get_series_info&series_id=
   &action=get_short_epg&stream_id=
/live/USER/PASS/{id}.ts|.m3u8
/movie/USER/PASS/{id}.{container_extension}
/series/USER/PASS/{episode_id}.{container_extension}
/xmltv.php?username=&password=                     -> full EPG
```

You need a panel URL, username and password from your own subscription. Nothing
is baked into the repository: credentials are entered at login and stored only
on the device.

## Run it

```powershell
flutter pub get
flutter run -d windows                 # debug
.\tool\build_windows.ps1               # release bundle under build\windows\x64\runner\Release
.\tool\build_windows.ps1 -Zip          # ... plus dist\Rogue-<version>-win-x64.zip
```

`tool\build_windows.ps1` reads the version from `pubspec.yaml`, injects it into
the build (`ROGUE_VERSION`) and finds Flutter via `PATH`, `FLUTTER_ROOT` or a
couple of common install locations.

### Try it without a panel

A local fake panel serves 40 channels, 36 movies, 12 series, a 3-day XMLTV guide
and generated artwork — no internet, no subscription:

```powershell
dart run tool\mock_panel.dart      # http://127.0.0.1:8099
```

Sign in with server `http://127.0.0.1:8099` and any username/password
(`demo` / `demo`).

Debug builds also accept a starting tab, which is handy for QA:

```powershell
$env:ROGUE_TAB = "2"   # 0 TV Guide, 1 Movies, 2 Series, 3 Search, 4 Recents, 5 Favourites, 6 Settings
```

### Portal presets

Bake a list of portals into a build without putting them in the repo:

```powershell
$env:ROGUE_PORTALS = "Portal A=http://panel-a:8880|Portal B=https://panel-b"
$env:ROGUE_DEFAULT_SERVER = "http://panel-a:8880"
.\tool\build_windows.ps1
```

The login screen then shows a **Portal** dropdown instead of a URL field, with a
read-only URL underneath and a `Custom server…` entry that reveals the text
field. Presets land in `portals.json` in the app support directory on first run:

- Windows: `%APPDATA%\app.rogue\Rogue\portals.json`
- Android: the app's private support directory

```json
[
  {"name": "Portal A", "url": "http://panel-a:8880"},
  {"name": "Portal B", "url": "https://panel-b"}
]
```

Deleting that file re-seeds it from the build define. Clearing the cache does not
touch it.

## Features

- Panel login with validation, credentials kept locally
- **TV Guide** — vertical category rail, banner with now/next info, progress and a
  muted mini-player, then channel rows on a 12-hour timeline starting at the
  current half-hour. Select to preview, select again for full screen. Programme
  blocks know about live, catch-up and future; a "now" line and per-programme
  progress bars stay in sync.
- **Movies / Series** — responsive poster grids, category chips, local search, and
  detail pages with full-bleed artwork, an artwork-tinted ambient glow and a
  strong scrim for readability. Series have a season selector and play a whole
  season; episodes carry their own progress.
- **Search** — instant on-device filtering across live, movies and series, with
  punctuation-insensitive matching (`S.W.A.T` = `swat`, `Tom & Jerry` = `tom and
  jerry`, `Grey's Anatomy` = `greys anatomy`).
- **Player** — MediaKit/libmpv (TS, HLS, HEVC, AC3), auto-hiding controls,
  Netflix-style seeking: ±10 s buttons, tap the left/right third, `←/→` or `J/L`,
  a pop-up ±10 indicator, elapsed + remaining time, drag-to-scrub, and
  auto-advance to the next episode. A **CC menu** lists embedded subtitle tracks
  and follows mpv's auto-selection; `C` toggles captions.
- **Recents** — last five channels, films and series played, with relative
  timestamps. Right-click / long-press an entry to remove just that one; **Clear**
  wipes the list.
- **Favourites** — save channels, films and series from the context menu (the
  guide uses right-click/long-press only); movie and series detail pages also
  have a heart. The Favourites tab groups all three and stores them in
  `favourites.json`.
- **Parental controls** — a PIN-protected **Hide adult content** switch. Adult
  categories disappear from the guide, movies, series, search and favourites;
  turning it back off (or changing the PIN) requires the PIN, stored as a salted
  SHA-256 hash.
- **Appearance** — six palettes (Rogue, Midnight, Emerald, Violet, Gold,
  Graphite) applied live, remembered per device. Each palette is a full set of
  surfaces, borders, accents and text colours in `theme.dart` (`kPalettes`).
- **Watch progress** — stored per movie/episode, shown as bars and ticks, with
  `Resume` / `From start` prompts. Items finish with under 1 min left for episodes
  and under 5 min for films; right-click an episode or poster to mark it watched.
- **Updates** — in-app checks, verified downloads and one-click install on both
  platforms. See [Updates](#updates).
- Stale-while-revalidate catalogue cache: lists render instantly from disk, then
  refresh in the background.

Keyboard: `Space`/`K` play-pause · `←`/`J` back 10 s · `→`/`L` forward 10 s ·
`C` subtitles · `F` fullscreen · `Esc` leave fullscreen (second press closes) ·
`↑`/`↓` channel · `Ctrl+F` search · `Ctrl+1..4` tabs.

## Updates

Release artifacts live on GitHub Releases. Each release also publishes a
`manifest.json`, and installed apps poll:

```
https://github.com/<owner>/<repo>/releases/latest/download/manifest.json
```

That URL always resolves to the newest release without using the GitHub API (no
rate limits, no token). Builds embed it at compile time via
`--dart-define=ROGUE_UPDATE_MANIFEST=...`; CI derives it from the repository, so
no URL is hardcoded in the source. Local builds leave it unset and the Settings
panel explains that updates are disabled.

```json
{
  "version": "1.2.0",
  "build": 12,
  "notes": "What changed…",
  "page": "https://github.com/<owner>/<repo>/releases/tag/v1.2.0",
  "windows": {
    "url": "https://github.com/<owner>/<repo>/releases/download/v1.2.0/Rogue-1.2.0-win-x64.zip",
    "sha256": "…",
    "size": 34281196
  },
  "android": {
    "url": "https://github.com/<owner>/<repo>/releases/download/v1.2.0/Rogue-1.2.0.apk",
    "sha256": "…",
    "size": 23114567
  }
}
```

The app checks on launch (at most every 6 hours), on demand from
**Settings → Updates**, and can skip a version. Downloads are hashed before
anything is installed.

### Windows

The updater expects the per-user install layout created by
`tool\install_windows.ps1`:

```
%LOCALAPPDATA%\Programs\Rogue\
  app-1.0.0+1\
  app-1.2.0\
  current  ->  app-1.2.0     (junction)
```

```powershell
.\tool\install_windows.ps1            # install the current release build
.\tool\install_windows.ps1 -Build     # build, then install
```

It needs no admin rights and creates a Start-menu shortcut. Updating extracts a
new `app-<version>` folder, repoints the junction, prunes old versions and
relaunches — the running copy is never modified, so a failed update cannot brick
the install, and rollback is a matter of repointing `current`. User data lives in
`%APPDATA%\app.rogue\Rogue` and is untouched.

### Android

The APK is downloaded, hashed, and handed to the system package installer through
a `FileProvider` URI, so the normal Android confirmation sheet appears. The first
time, Android asks for permission to install unknown apps; the app opens that
settings screen automatically when it is missing.

`versionCode` comes from the `+N` build number in `pubspec.yaml`, so bump it for
every release. **Signing matters here:** Android only installs an update signed
with the same key as the installed app. Without `android/key.properties` the
build is debug-signed (fine for a first install); CI runners generate a fresh
debug key each time, so add `ANDROID_KEYSTORE_BASE64` and
`ANDROID_KEY_PROPERTIES` repository secrets to sign with a stable key.

### Publishing

Bump `version:` in `pubspec.yaml`, then tag the commit:

```powershell
git tag -a v1.2.0 -m "What's new in 1.2.0"
git push origin v1.2.0
```

`.github/workflows/release.yml` runs the analyzer and tests, builds the Windows
bundle and the universal APK, hashes both, writes `manifest.json`, and publishes
a GitHub release with the tag message as release notes. The manifest can also be
produced locally:

```powershell
node tool/make_manifest.mjs --version 1.2.0 --build 12 --tag v1.2.0 `
  --repo owner/repo --windows dist/Rogue-1.2.0-win-x64.zip --android dist/Rogue-1.2.0.apk
```

## Checks

```powershell
.\tool\build_windows.ps1   # release build (keeps the icon font intact)
flutter analyze            # clean
flutter test               # 86 tests: parsing, XMLTV, portals, favourites, recents,
                           # themes, updates, progress, resume UI, shell
dart run tool\smoke_api.dart   # client against a throwaway local HTTP panel
```

`--no-tree-shake-icons` is required for release builds: the icon shaker drops
glyphs that are only referenced through dynamic `IconData`, which made the
player's ±10 s buttons invisible (layout space, no glyph).

## Layout

```
lib/
  main.dart, app.dart, theme.dart
  data/       models, xtream_api, disk_cache
  state/      app_model (+ AppScope), session, catalog, epg, preferences,
              favourites, recents, watch progress, player service
  updates/    app_version, update_manifest, update_service, update_controller,
              update_installer (Windows junction swap, Android FileProvider)
  ui/         login, home shell, guide, movies, series, search, recents,
              favourites, detail screens, player, settings, updates panel
  core/       app log, PIN hashing, fullscreen (Win32), search normalisation
tool/         build/install scripts, manifest generator, mock panel, smoke API
android/      MainActivity + method channel for the APK installer
windows/      runner (Impeller disabled), version resource
```

## Platform notes

- **Windows runs with Impeller disabled** (`windows/runner/main.cpp`,
  `project.set_impeller_switch(ImpellerSwitch::Disabled)`). media_kit draws libmpv
  into an external GL texture, and the Windows embedder resolves that texture via
  Skia's `GrDirectContext`. Under Impeller that context is null, which crashes the
  raster thread a few seconds after leaving the player.
- The player and its texture are app-lifetime singletons (`PlayerService`), so
  navigation never destroys the texture mid-frame.
- **Fullscreen is raw Win32** (`lib/core/fullscreen.dart`); `window_manager`'s
  legacy `setFullScreen` deadlocked the UI thread on exit, so the plugin was
  removed.
- The player's `PopScope` must never block a pop and then call `maybePop()` from
  `onPopInvokedWithResult`: `canPop` is fixed until the next build, so the second
  pop re-enters the callback and spins forever. The route pops freely and
  `dispose()` restores the window synchronously.
- `Win32Window::Show()` explicitly shows `child_content_` — this engine version
  creates the `FLUTTERVIEW` child without `WS_VISIBLE`, and showing the parent
  does not reveal it.
- Panels return artwork as plain URLs or bracketed list strings
  (`[https://cdn/x.jpg]`); `asImageUrl` unwraps both before making them absolute.

## Data and privacy

No telemetry and no third-party services. The panel credentials and the settings
listed above live in the app's own support/preferences store; watch progress and
favourites are plain JSON on disk. Signing out removes the saved credentials.

## Not done yet

- Genre/decade filters beyond the panel's own categories
- Recording and multi-screen
- A hosted update channel for builds made outside CI (set
  `ROGUE_UPDATE_MANIFEST` when building locally)

Catch-up URLs use the shape `/timeshift/<user>/<pass>/<minutes>/<yyyy-MM-dd:HH-mm>/<id>.ts`,
with the timestamp built from the programme start in **local** time — replay is
exact when the device timezone matches the panel's.

## Legal

This is a client for a subscription you own. Nothing here bypasses DRM, licensing
or authentication. Redistributing the provider's streams, or publishing this as a
branded clone of another app, is not authorised.
