# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Work toward 0.9.0, the first test build. Skeleton only: no playback,
no search, no downloads yet. Those arrive in later 0.9.x builds.

### Added

- Repository foundation: README, GPL-3.0-only license, contributing guide,
  code of conduct, security policy, issue and pull request templates.
- Flutter app skeleton: dark monochrome theme from design tokens, bottom
  navigation with four tabs (Beranda, Cari, Library, Unduhan), honest empty
  states, and a mini-player slot that stays hidden until a song plays.
- Indonesian UI strings in `lib/l10n/app_id.arb`, ready for localization.
- CI workflow: analyze, test, debug + release APK builds split per ABI,
  25 MB size check on the release APK.
- Release workflow: signed release APKs and AAB from tags, SHA-256 checksums.

### Fixed

- CI size check no longer gates on debug APKs. Run 43728749979 failed only
  on that step (debug APKs measured 90.3 MB arm64-v8a, 68.7 MB armeabi-v7a,
  76.4 MB x86_64) — debug APKs are larger by design. The 25 MB limit now
  applies to the release APK, the artifact users install (K4); debug APK
  sizes are reported only.

[Unreleased]: https://github.com/adiprmx/laras/compare/v0.9.0...HEAD
