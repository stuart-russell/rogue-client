# AGENTS.md

You are working on **Rogue**, a Flutter IPTV client for Xtream Codes panels
(Windows desktop + Android phone/TV). This file is the entry point for coding
agents. Read it before changing code; follow the links for depth.

- `CONTEXT.md` — domain vocabulary and the flows that matter.
- `docs/architecture.md` — layers, state ownership, platform constraints.
- `docs/testing.md` — test patterns and the traps that waste time.
- `docs/releasing.md` — versioning, CI releases, signing, install layouts.
- `docs/playbooks.md` — step-by-step recipes for the usual changes.
- `README.md` — user-facing description and feature list.

## Ground rules

1. **Never commit secrets or personal data.** Panel URLs/credentials come from
   `--dart-define` (`ROGUE_PORTALS`, `ROGUE_DEFAULT_SERVER`) or CI secrets, never
   source. `android/release.jks` and `android/key.properties` are git-ignored —
   keep it that way. Do not add personal names, emails, or machine paths to the
   repo.
2. **Do not push to `main` or create tags unless the user asks.** The release
   workflow publishes automatically on a version change (see
   `docs/releasing.md`).
3. **Edit source files with the editor tools, not shell text rewriting.**
   PowerShell `Set-Content`/`Get-Content -Raw` round-trips corrupt UTF-8 on this
   codebase (mojibake, `U+FFFD`). If a script is unavoidable, write UTF-8
   explicitly:
   `[IO.File]::WriteAllText($p, $text, (New-Object Text.UTF8Encoding($false)))`.
4. **Verify before handing back:** `tool/check.ps1` (format, analyze, tests) must
   be green.

## Quick start

```powershell
flutter pub get
tool/check.ps1                 # format check + analyze + test (93 tests)
flutter run -d windows         # debug on the desktop
dart run tool/mock_panel.dart  # local fake panel at http://127.0.0.1:8099
```

The panel in real life allows **one connection**. For any UI work, use the mock
panel (`demo` / `demo`) rather than the user's subscription, and do not start a
stream while another device is watching.

## Definition of done

- `tool/check.ps1` passes.
- UI changes: run against the mock panel and look at the result (screenshots on
  Windows via `PrintWindow`, or `adb` screenshots on a device).
- Release build still works: `tool/build_windows.ps1` (it injects the version and
  required defines).
- User-facing behaviour documented in `README.md`; architectural decisions worth
  remembering go in `CONTEXT.md` or the relevant doc.
- No debug prints, no commented-out code, no personal identifiers.

## How the app is put together

`main.dart` → `RogueApp` (`app.dart`) creates one `AppModel` and wraps
`MaterialApp` in `AppScope` (an `InheritedNotifier`). `AppModel`
(`lib/state/app_model.dart`) owns every controller and re-broadcasts their
notifications, so `AppScope.of(context)` rebuilds widgets for any state change.

State lives in `lib/state/`, files/network in `lib/data/`, screens in `lib/ui/`,
update logic in `lib/updates/`. Import direction is one-way:
`data → state → ui`. Nothing in `data/` may import `ui/`.

Conventions you must follow:

- **Theme:** read colours from `AppColors.*`. They are *mutable getters* backed
  by the active `Palette`, so never use them inside `const` expressions.
- **Responsive:** `isCompact(context)` (width < 700) selects phone layouts;
  `HomeShell` switches to the sidebar at width ≥ 900. Use `pagePadding()` /
  `pageTopPadding()` instead of hardcoded insets.
- **Anything tappable is `FocusableTap`** (`lib/ui/focusable_tap.dart`), not a
  bare `GestureDetector` — Android TV D-pad focus depends on it. Pass a builder
  that draws a focus ring (`focused` flag). A short Select activates on release;
  holding it fires `onLongPressStart` for the context menus. The only deliberate
  exception is the guide's timeline programme cells (mouse-first).
- **Context menus:** long-press + right-click. Use
  `showItemMenu(context, position, favourite:, watchId:)`
  (`lib/ui/favourites_actions.dart`) for the standard favourite/watched actions;
  custom menus follow the same `showMenu` recipe (see the season menu in
  `detail_screens.dart`).
- **Persistence:** stores extend `ChangeNotifier`, load best-effort with a short
  timeout, tolerate malformed JSON, and save to the app support directory
  (`RecentsStore`, `FavouritesStore`, `WatchProgress`). Wire new stores into
  `AppModel` (listener + dispose) so the UI rebuilds.
- **Async UI:** check `context.mounted`/`mounted` after every await; never call
  `setState` after dispose.
- **Snackbars:** `hideCurrentSnackBar()` then show a floating snackbar with a
  width between 300 and 460.

## Platform gotchas (these have bitten before)

- **Windows:** Impeller is intentionally disabled in `windows/runner/main.cpp`
  (media_kit renders into an external GL texture; Impeller crashes the raster
  thread). Do not re-enable it.
- **Player route:** `PopScope` must never block a pop and then call `maybePop()`
  — that loops forever. The route pops freely and `dispose()` restores state.
- **Player texture:** the player and its texture are app-lifetime singletons
  (`PlayerService`, `PreviewPlayer`). Never create a video texture per visit.
- **Release builds need `--no-tree-shake-icons`** (dynamic `IconData` in the
  player). `tool/build_windows.ps1` already passes it.
- **`Win32Window::Show()`** must show `child_content_`; hiding it yields a black
  window (see `windows/runner/win32_window.cpp`).
- **Android:** release manifests need `INTERNET` and cleartext traffic for
  `http://` panels; both are already set. Updating APKs requires a stable
  signing key — see `docs/releasing.md`.
- **TV focus:** the shell must not wrap content in a full-size focusable node
  (it traps directional traversal), and hidden `IndexedStack` tabs use
  `ExcludeFocus`. Use `isTv(context)` (Android + width >= 900) when a page needs
  less vertical chrome than desktop (series detail shortens its banner). On TV
  the sidebar collapses to a 64 px icon rail while focus is in the page and
  reopens when focus returns; `HomeShell` tracks the rail/content keys for this.
  The whole TV UI is wrapped in `TvScale` (0.9) so more rows and posters fit.
  Settings rows/controls use `FocusRing` (`lib/ui/focus_ring.dart`) so the
  remote's position is a 2 px accent ring, not Material's faint overlay.
  `FocusRevealer` scrolls the focused control into view,
  `main()` forces `FocusHighlightStrategy.alwaysTraditional` for Material focus
  states, and `FocusableTap` draws its ring from `onFocusChange` (Android TV can
  report touch mode). `SearchField` is traversable; Up/Down leave the field and
  the keyboard's submit action moves to the results. `test/tv_focus_test.dart`
  guards this.

## Releases (summary)

Bump `version:` in `pubspec.yaml` and push to `main`. CI builds Windows +
Android, writes `manifest.json`, creates the tag and publishes the release when
that tag does not exist yet. Ordinary pushes only run the checks. Details and
signing setup: `docs/releasing.md`.
