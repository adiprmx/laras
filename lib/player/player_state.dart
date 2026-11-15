/// State pemutar yang dibaca UI: satu snapshot tak-berubah per perubahan.
///
/// Posisi putar sengaja TIDAK ada di snapshot: posisi berubah beberapa kali
/// per detik, dan setiap perubahan snapshot disiarkan ke MediaSession.
/// Posisi punya stream sendiri di [AudioPlayerPort.positionStream].
library;

import 'package:flutter/foundation.dart';

import 'track.dart';

/// Mode pengulangan antrean.
enum RepeatMode {
  /// Berhenti di akhir antrean.
  off,

  /// Kembali ke awal antrean setelah lagu terakhir.
  all,

  /// Ulangi lagu yang sedang diputar.
  one,
}

/// Status pemrosesan lagu yang sedang dimuat/diputar.
enum PlayerStatus {
  /// Belum ada lagu yang dimuat.
  idle,

  /// Lagu sedang dicari URL-nya atau dimuat engine.
  loading,

  /// Lagu dimuat tapi audio belum cukup untuk diputar.
  buffering,

  /// Lagu siap atau sedang diputar.
  ready,

  /// Lagu terakhir antrean selesai (mode pengulangan mati).
  completed,

  /// Lagu gagal diputar setelah semua percobaan. Lihat [PlayerSnapshot.lastError].
  error,
}

/// Penyebab kegagalan putar, dalam bahasa yang bisa dipetakan ke pesan ARB.
/// Klasifikasi lengkap 6 penyebab menyusul di P6; dua penyebab ini cukup
/// untuk membedakan "internet putus" dari "lagu tidak bisa diputar".
enum PlaybackFailureKind {
  /// Jaringan perangkat bermasalah (tidak ada internet, koneksi putus).
  network,

  /// Lagu tidak bisa diputar walau jaringan ada.
  unplayable,
}

/// Satu kegagalan putar yang dilaporkan jujur ke pengguna.
class PlaybackFailure {
  const PlaybackFailure({
    required this.kind,
    required this.trackTitle,
    this.skippedCount = 0,
  });

  final PlaybackFailureKind kind;

  /// Judul lagu yang gagal, untuk ditampilkan apa adanya.
  final String trackTitle;

  /// Jumlah lagu yang dilewati otomatis karena tidak bisa diputar
  /// sebelum lagu yang berhasil. Nol bila tidak ada yang dilewati.
  final int skippedCount;

  @override
  bool operator ==(Object other) =>
      other is PlaybackFailure &&
      other.kind == kind &&
      other.trackTitle == trackTitle &&
      other.skippedCount == skippedCount;

  @override
  int get hashCode => Object.hash(kind, trackTitle, skippedCount);

  @override
  String toString() =>
      'PlaybackFailure(kind: $kind, track: $trackTitle, '
      'skipped: $skippedCount)';
}

/// Info resolve terakhir yang berhasil, untuk diagnosis (layar demo).
/// Tidak membawa URL.
class ResolveInfo {
  const ResolveInfo({
    required this.videoId,
    required this.clientName,
    required this.resolveDuration,
  });

  final String videoId;
  final String clientName;
  final Duration resolveDuration;

  @override
  bool operator ==(Object other) =>
      other is ResolveInfo &&
      other.videoId == videoId &&
      other.clientName == clientName &&
      other.resolveDuration == resolveDuration;

  @override
  int get hashCode => Object.hash(videoId, clientName, resolveDuration);
}

/// Snapshot state pemutar: dibaca UI lewat [AudioPlayerPort.snapshot] dan
/// disiarkan lewat [AudioPlayerPort.stateStream] setiap kali berubah.
class PlayerSnapshot {
  const PlayerSnapshot({
    this.currentTrack,
    this.queue = const <Track>[],
    this.currentIndex = -1,
    this.playing = false,
    this.status = PlayerStatus.idle,
    this.duration,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.speed = 1.0,
    this.pitch = 1.0,
    this.skipSilence = false,
    this.lastError,
    this.lastResolve,
    this.reResolving = false,
  });

  /// Snapshot awal: tidak ada lagu.
  static const PlayerSnapshot idle = PlayerSnapshot();

  final Track? currentTrack;

  /// Antrean dalam urutan putar (urut acak bila shuffle aktif).
  final List<Track> queue;

  /// Indeks lagu yang sedang diputar di [queue], -1 bila tidak ada lagu.
  final int currentIndex;

  /// Benar bila pemutar sedang memutar (atau akan memutar begitu siap).
  final bool playing;

  final PlayerStatus status;

  /// Durasi lagu yang sedang diputar, bila sudah diketahui engine.
  final Duration? duration;

  final bool shuffleEnabled;
  final RepeatMode repeatMode;

  /// Kecepatan putar (1.0 = normal).
  final double speed;

  /// Nada suara (1.0 = normal). Android saja.
  final double pitch;

  /// Lewati bagian hening. Android saja.
  final bool skipSilence;

  /// Kegagalan terakhir, bila ada. Dihapus saat lagu berhasil diputar.
  final PlaybackFailure? lastError;

  /// Info resolve terakhir yang berhasil, bila ada.
  final ResolveInfo? lastResolve;

  /// Benar bila pemutar sedang mencoba memutar lagi lagu yang sama
  /// setelah koneksi terputus di tengah lagu (re-resolve).
  final bool reResolving;

  PlayerSnapshot copyWith({
    Track? currentTrack,
    List<Track>? queue,
    int? currentIndex,
    bool? playing,
    PlayerStatus? status,
    Duration? duration,
    bool? shuffleEnabled,
    RepeatMode? repeatMode,
    double? speed,
    double? pitch,
    bool? skipSilence,
    PlaybackFailure? lastError,
    ResolveInfo? lastResolve,
    bool? reResolving,
    bool clearTrack = false,
    bool clearError = false,
    bool clearDuration = false,
  }) {
    return PlayerSnapshot(
      currentTrack: clearTrack ? null : (currentTrack ?? this.currentTrack),
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      playing: playing ?? this.playing,
      status: status ?? this.status,
      duration: clearDuration ? null : (duration ?? this.duration),
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      skipSilence: skipSilence ?? this.skipSilence,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastResolve: lastResolve ?? this.lastResolve,
      reResolving: reResolving ?? this.reResolving,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerSnapshot &&
      identical(other.currentTrack, currentTrack) &&
      listEquals(other.queue, queue) &&
      other.currentIndex == currentIndex &&
      other.playing == playing &&
      other.status == status &&
      other.duration == duration &&
      other.shuffleEnabled == shuffleEnabled &&
      other.repeatMode == repeatMode &&
      other.speed == speed &&
      other.pitch == pitch &&
      other.skipSilence == skipSilence &&
      other.lastError == lastError &&
      other.lastResolve == lastResolve &&
      other.reResolving == reResolving;

  @override
  int get hashCode => Object.hash(
    currentTrack,
    Object.hashAll(queue),
    currentIndex,
    playing,
    status,
    duration,
    shuffleEnabled,
    repeatMode,
    speed,
    pitch,
    skipSilence,
    lastError,
    lastResolve,
    reResolving,
  );

  @override
  String toString() =>
      'PlayerSnapshot(track: ${currentTrack?.title}, index: $currentIndex, '
      'playing: $playing, status: $status, shuffle: $shuffleEnabled, '
      'repeat: $repeatMode, speed: $speed)';
}
