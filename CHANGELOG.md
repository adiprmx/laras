# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Work toward 0.9.0, the first test build. P3 (database + library), P4
(online search + home sections), and P5 (downloads + offline cache) are
in. P6 (resilience) is in: service-health monitoring with a daily
canary check, a real Settings screen, unplayable-song handling, and
delete-all-data. P7 (Should features) is in: lyrics, sleep timer,
equalizer, player persistence, restart-proof queue restore, and deep
links. Blue 2 (Red 2 security fixes) is in: stream-URL allowlist on
the download path, byte caps and stall watchdogs, and QuickJS-ng
0.18.0 via a pinned fork.

### Added

- Service-health monitoring (P6): the canary checker now runs once a
  day in the background at cold start and on resume, without disturbing
  playback; status is persisted and shown as a three-level home banner
  (ok = no banner, degraded = thin banner, broken = clear banner with a
  "Periksa pembaruan" button). Network failures never trigger broken
  status.
- "Periksa pembaruan" action (P6, in the banner, Settings, and browse
  failure): forces a remote config refresh outside the 6-hour TTL and
  re-runs the canary check, then reports the honest result.
- Plain-language messages for all six resolve failure causes (P6). A
  single client failing is invisible when the next client succeeds;
  when all clients fail, the message matches the cause. The
  mini-player shows the one-line variant of the same cause message,
  so the failure type is visible there too, not only on the full
  player screen.
- Short diagnostic code (P6, added 16 Nov after the owner's report
  that "Coba lagi" kept failing with an unknown error type): the
  "Laporkan kerusakan" dialog shows a one-line code
  (`LRS1-...`) summarizing the last failure (type + cause + time +
  clients tried + app/config versions + canary status), built
  entirely from local data (works offline). The owner can copy it
  into chat or send it via the report email, which includes it too.
  The code never contains song titles, URLs, IPs, or any personal
  data.
- Browse failure handling (P6, B6.5): unparseable browse results say
  YouTube may have changed its service, with a "Periksa pembaruan"
  button; HTTP errors say to try again later, with a "Coba lagi"
  button. Local sections are unaffected.
- Unplayable-song handling (P6, B4.7): songs reported unplayable by
  YouTube (deleted, private, region-restricted) show dimmed with a
  "Tidak bisa diputar" label, are auto-skipped in sequential play with
  a count message, and can be bulk-deleted with confirmation. Network
  failure and mass breakage never mark songs; downloaded songs are
  never marked and stay playable. Schema v3 adds `songs.unplayable`
  plus an index, with a tested v2→v3 migration.
- Real Settings screen (P6, replacing the stub): playback (data saver),
  downloads & storage (default download quality, user-changeable space
  for played songs: 250 MB / 500 MB / 1 GB / 2 GB, WiFi-only downloads
  with auto pause/resume), services (status + check for updates), app
  (About, 12-question FAQ, report a problem by email, delete all data).
- Delete all data (P6, B7.3): two-tier confirmation; wipes the
  database, cache, downloads, and all preferences.
- One-time honesty sheet (P6, B11.5): exposed as a callable component
  (`showHonestySheet`, flag `honesty_sheet_shown_v1`); first-run
  orchestration (onboarding → sheet → home) belongs to the onboarding
  flow. No permanent line on home.
- Internal log capped at 1 MB with rotation (P6): local file only,
  never shown to the user, stream URLs redacted.
- Lyrics (P7, LRCLIB — free, no key): synced lyrics with auto-scroll
  and a 5-second pause after the user scrolls, plain lyrics, and
  honest states for missing, instrumental, offline, and failed
  (with retry). Results are cached in the database; missing or
  instrumental results are not stored, so newly published lyrics can
  still be found next session. Attribution is always shown in the
  sheet footer. Live verification from the owner's phone is still
  pending (VM egress was dead during development).
- Sleep timer (P7): presets 5/10/15/30/45/60 minutes, custom 1–180
  minutes, and an end-of-song mode; a live countdown chip sits on the
  player screen. When the timer ends the player pauses (queue and
  position stay intact) instead of stopping the service.
- Equalizer (P7, Android only, no new dependency): the real device
  equalizer (`android.media.audiofx.Equalizer`) driven through the
  just_audio audio session ID; presets plus a working per-band custom
  mode with the device's own band frequencies. An honest message is
  shown when the phone provides no equalizer, or before any song is
  loaded.
- Player persistence (P7): speed, pitch, and skip-silence settings
  survive app restarts.
- Restart-proof queue restore (P7, Must #3): the queue and position
  are restored after the app is closed and reopened (schema v4 adds
  a `PlaybackState` table; v3→v4 migration only creates the table).
  Downloaded songs restore offline; streaming songs need one network
  resolve. With shuffle on, the restored order is reshuffled (same
  set of songs, same song playing first).
- Deep links (P7, Must #13): youtu.be / youtube.com / music.youtube.com
  watch and Shorts links opened from outside the app play that song
  in Laras (replaces the queue). Not a verified App Link (no
  assetlinks file).

### Changed

- Settings screen replaces the "Segera hadir" stub (P6).
- DownloadService and StreamCacheService honor the WiFi-only switch
  (P6, minimal additive gates; no download-logic change).

- APKs are now built for arm64-v8a and armeabi-v7a only. The x86_64 ABI
  was dropped: it runs on emulators only, and after P3 its release APK
  reached 26,161,237 bytes — 53,163 bytes under the 25 MB limit, a
  breach waiting for the next package.
- Release builds are now obfuscated (`--obfuscate` with split debug
  info) to shrink the app code; the debug symbols are published with
  each release so crash stack traces stay symbolizable.
- `gg_quickjs` now comes from a pinned fork (`adiprmx/gg_quickjs`,
  commit c84a5011, package 0.1.1) bundling QuickJS-ng 0.18.0 (Blue 2,
  R2-M3): upstream pub.dev still ships 0.17.0, which has two
  use-after-free fixes in 0.18.0 (#1781, #1844) plus uncatchable
  OOM/InternalError fixes. Return to upstream when it releases
  >= 0.18.0; see `docs/dependencies.md` §2.1.
- Database schema is now v4 (P7): new `PlaybackState` table for
  queue restore; no existing data is touched by the migration.

### Fixed

- Release workflow no longer runs live-tagged tests (same exclusion
  as CI: `flutter test --exclude-tags live`).
- Stream URLs on the direct (script-free client) download path are
  now allowlist-checked, and downloads re-validate before requesting
  (Blue 2, R2-M1 — the R1-M1 gap had recurred in the P5 mirror code).
- Downloads and the streaming cache now enforce byte caps inside the
  chunk loop (1 GB per download file; cache fetch budget) with a
  30-second connect timeout and a 60-second stall watchdog (Blue 2,
  R2-M2/R2-L4). Previously a server declaring a small size could
  stream far past the cap, and a stalled cache fetch could hang the
  cache pump forever.
- The download URL resolver now uses the P0-2 degraded-fallback
  pattern instead of breaking the loop on an unknown player hash,
  and forwards remote-config hashes to the script loader (Blue 2,
  R2-L5).
- MediaItem artwork URIs are validated before use (Blue 2, R2-L2);
  file paths read from the database are shape-validated before use
  (Blue 2, R2-L3); search submit paths are wrapped in try/catch and
  browse/search screens handle errors (Blue 2, R2-L1).
- Gradle wrapper files are no longer git-ignored (Blue 2, R2-L6 —
  closes the R1-L8 remainder from Red 2).
- K7 (P6 remote-config TTL test) no longer flakes under CPU load:
  the test now waits for the background refresh to finish writing
  the new config to cache instead of only waiting for the fetch to
  start.
- Player hash rotation (17 Nov 2026): YouTube rotated base.js to
  hashes `ad8d59ae` (sts 20768, non-tcl) and `b559f50c` (sts 20770,
  non-tcl), served concurrently on different pages — the built-in
  hash map and the remote config (tag `config-v1`) now carry all
  three hashes (`fad7e4e9` 20767, `ad8d59ae` 20768, `b559f50c`
  20770). Extraction of both new ciphers was verified on the real
  scripts plus unit tests; `b559f50c` was verified live end-to-end
  (live extractor suite 6/6, including the WEB_REMIX cipher test).
  Live solve verification for `ad8d59ae` is still pending (VM egress
  outage during verification; being retried). The rotation also
  changed the player script format, fixed in the same change: the
  string table is now double-quoted with a per-release delimiter
  (`;` in `ad8d59ae`, `{` in `b559f50c`), and the `ad8d59ae` cipher
  uses the `String` builtin as its helper instead of a custom
  object (the prelude now omits the helper literal for known JS
  builtins).

### Added

- Local database (drift + SQLite, schema v1): 15 tables (songs, albums,
  artists, playlists, play history, search history, queue, downloads,
  cache, and more) plus an FTS5 virtual table for local search; tested
  migration artifacts (`drift_schemas/drift_schema_v1.json`,
  `test/generated_migrations.dart`).
- Library tab with six sections: songs (sortable: newest, name,
  most-played), playlists, favorites, history, albums, artists — all
  paginated 50 per page with honest empty states.
- Playlists: create, rename, describe, delete, add/remove songs,
  drag to reorder.
- Favorites: heart buttons on the Player screen, the mini-player, and
  every library song row; favoriting also adds the song to the library.
- Play history recorded automatically while songs play (10-second
  minimum), with a clear-history action.
- Local search engine (FTS5 over song titles and artist names, with
  search history). The search UI itself arrives with online search in P4;
  the Cari tab shows an honest "coming soon" screen until then.
- Repository foundation: README, GPL-3.0-only license, contributing guide,
  code of conduct, security policy, issue and pull request templates.
- Flutter app skeleton: dark monochrome theme from design tokens, bottom
  navigation with four tabs (Beranda, Cari, Library, Unduhan), honest empty
  states, and a mini-player slot that stays hidden until a song plays.
- Indonesian UI strings in `lib/l10n/app_id.arb`, ready for localization.
- CI workflow: analyze, test, debug + release APK builds split per ABI,
  25 MB size check on the release APK.
- Release workflow: signed release APKs and AAB from tags, SHA-256 checksums.

### Changed

- Home screen is now a real song list: the five canary songs show with
  album covers, titles, durations, and clear play buttons — no
  intermediate "demo" button, no debug log panel, no jargon in visible
  strings (K-F2-07/K-F2-08). The raw spike demo screen was removed.
- Player screen and mini-player show cached album covers; the
  mini-player has a favorite button and a visible progress strip, and
  opening the full player slides up from the bottom (K-F2-09).
- Cari and Unduhan tabs show designed "Segera hadir" screens instead of
  dead controls (K-F2-07).

### Fixed

- CI size check no longer gates on debug APKs. Run 43728749979 failed only
  on that step (debug APKs measured 90.3 MB arm64-v8a, 68.7 MB armeabi-v7a,
  76.4 MB x86_64) — debug APKs are larger by design. The 25 MB limit now
  applies to the release APK, the artifact users install (K4); debug APK
  sizes are reported only.

[Unreleased]: https://github.com/adiprmx/laras/compare/v0.9.0...HEAD
