# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Work toward 0.9.0, the first test build. P3 (database + library) is in:
the app now stores a real library, playlists, favorites, and play
history in SQLite (drift), and the home screen shows songs that play
directly. Online search (P4) and downloads (P5) are still to come.

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
