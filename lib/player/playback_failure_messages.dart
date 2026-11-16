/// Pemetaan [PlaybackFailure] ke pesan bahasa sehari-hari (ARB).
///
/// Satu sumber kebenaran untuk semua permukaan yang menampilkan kegagalan
/// putar: banner Player penuh, banner Beranda, mini-player, dan pesan error
/// MediaSession. Pesan dibedakan per penyebab supaya pengguna tahu langkah
/// yang benar: tanpa internet -> periksa koneksi; internet lambat -> coba
/// lagi; lagu tidak bisa diputar -> coba lagu lain atau nanti.
///
/// Semua string tinggal di `lib/l10n/app_id.arb`; tidak ada string yang
/// di-hardcode di sini.
library;

import 'package:laras/l10n/generated/app_localizations.dart';

import 'player_state.dart';

/// Pesan lengkap untuk banner (Player penuh, Beranda, MediaSession).
///
/// Bila ada lagu yang dilewati otomatis, jumlahnya ditambahkan di akhir
/// (mis. "1 lagu dilewati karena tidak bisa diputar.").
String playbackFailureMessage(
  AppLocalizations strings,
  PlaybackFailure failure,
) {
  final String message = switch (failure.kind) {
    PlaybackFailureKind.network => strings.noInternet,
    PlaybackFailureKind.timeout => strings.playFailedTimeout,
    PlaybackFailureKind.unplayable => strings.songCannotPlay,
  };
  if (failure.skippedCount <= 0) return message;
  return '$message ${strings.skippedUnplayable(failure.skippedCount)}';
}

/// Pesan satu baris untuk mini-player (ruang hanya satu baris teks).
String playbackFailureShortMessage(
  AppLocalizations strings,
  PlaybackFailure failure,
) {
  return switch (failure.kind) {
    PlaybackFailureKind.network => strings.playFailedNetworkShort,
    PlaybackFailureKind.timeout => strings.playFailedTimeoutShort,
    PlaybackFailureKind.unplayable => strings.playFailedCannotPlayShort,
  };
}
