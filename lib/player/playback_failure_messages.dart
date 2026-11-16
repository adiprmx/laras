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
import 'package:laras/resilience/cause_messages.dart';

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
    // P6: bila penyebab resolve diketahui, pesannya spesifik per
    // penyebab (mis. "YouTube mengubah pemutarnya."); bila tidak,
    // pesan generik lama.
    PlaybackFailureKind.unplayable => failure.cause == null
        ? strings.songCannotPlay
        : causeMessage(strings, failure.cause!),
  };
  if (failure.skippedCount <= 0) return message;
  return '$message ${strings.skippedUnplayable(failure.skippedCount)}';
}

/// Pesan satu baris untuk mini-player (ruang hanya satu baris teks).
///
/// Seperti pesan lengkap: bila penyebab resolve diketahui, jenis gagal
/// spesifik tampil (varian singkat per penyebab), bukan pesan generik.
/// Ini yang membuat jenis gagal TERLIHAT di mini-player, bukan hanya di
/// layar pemutar penuh (tambahan P6 — verdict owner 18:56 WIB).
String playbackFailureShortMessage(
  AppLocalizations strings,
  PlaybackFailure failure,
) {
  return switch (failure.kind) {
    PlaybackFailureKind.network => strings.playFailedNetworkShort,
    PlaybackFailureKind.timeout => strings.playFailedTimeoutShort,
    PlaybackFailureKind.unplayable => failure.cause == null
        ? strings.playFailedCannotPlayShort
        : causeShortMessage(strings, failure.cause!),
  };
}
