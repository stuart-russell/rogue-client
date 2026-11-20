# Rogue — domain context

Short reference for the vocabulary used in code, so a new reader can map a
feature request onto the existing model.

## The players

- **Panel** — an Xtream Codes server the user subscribes to (URL + username +
  password). One panel allows a limited number of simultaneous streams,
  usually **one**, which is why the app is careful about connections.
- **Portal / preset** — a named panel URL baked into the build
  (`ROGUE_PORTALS`) and seeded into `portals.json`. The login screen shows them
  as a dropdown.
- **Session** — credentials plus the `AccountInfo` from `player_api.php`
  (expiry, active/max connections, allowed formats, timezone).

## Catalogue

- **Live stream / channel** — `LiveStream` from `get_live_streams`, keyed by
  `streamId`, grouped by `categoryId`, may have `epgChannelId` and
  `archiveDays` (catch-up window).
- **Movie** — `VodStream` from `get_vod_streams`; details come from
  `get_vod_info` (`VodInfo`, including `containerExtension`, which decides the
  `/movie/.../{id}.{ext}` URL).
- **Series / show** — `SeriesItem` from `get_series`; `get_series_info` returns
  `SeriesInfo` with `seasons: Map<int, List<Episode>>`.
- **Category** — panel-provided grouping (`Category`), filtered by the adult
  filter. `CatalogController` caches per-segment lists, counts and categories and
  exposes filtered accessors (`channelsIn`, `moviesIn`, `seriesIn`, …).

## Guide

- **EPG** — XMLTV from `/xmltv.php`, downloaded once, parsed off the main
  isolate and cached (`EpgController`). Lookups: `now`, `next`, programme
  lists per `epgChannelId`.
- **Timeline** — the guide's 12-hour grid (desktop/TV). Phones use a compact
  now/next list instead.
- **Catch-up / replay** — `/timeshift/<user>/<pass>/<minutes>/<yyyy-MM-dd:HH-mm>/<id>.ts`,
  built from the programme start in local time.
- **Preview player** — a muted, second `media_kit` player used by the guide
  banner. It is halted when the full player opens or the tab changes, because of
  the one-connection limit.

## User state (all local, JSON on disk)

- **Favourites** — channels/films/series saved via context menus or detail-page
  hearts (`favourites.json`).
- **Recents** — last five per type, recorded on playback (`recents.json`).
- **Watch progress** — `vod:<id>` / `ep:<id>` entries with position, duration and
  a `completed` flag (`watch_progress.json`). Films finish with 5 min left,
  episodes with 1 min.
- **Preferences** — live format, auto-guide, parental PIN/filter, palette
  (SharedPreferences).
- **Palette** — one of six colour schemes; `AppColors` proxies the active one.

## Updates

- **Manifest** — `manifest.json` attached to each GitHub release: version,
  build, notes, per-platform artifact URL + SHA-256.
- **Managed install (Windows)** — `%LOCALAPPDATA%\Programs\Rogue\app-<version>`
  plus a `current` junction; updates extract a new folder and repoint the
  junction.
- **APK hand-off (Android)** — the APK is verified, then handed to the system
  installer through a `FileProvider` URI.

## Behavioural rules

- Taps on a phone player show/hide controls; playback only changes via buttons.
- Phone player opens in landscape and immersive; the rotate button overrides
  auto-rotate.
- Long-press/right-click opens menus everywhere; hearts are only on detail
  pages and favourites rows.
- The adult filter hides categories (and recents/favourites entries) by
  `categoryId`; toggling it off requires the PIN.
