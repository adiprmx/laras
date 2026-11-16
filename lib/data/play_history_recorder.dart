/// Pencatat riwayat putar otomatis.
///
/// Mendengarkan [AudioPlayerPort] (bukan sebaliknya): hook ini aditif,
/// `lib/player/` tidak diubah sama sekali. Satu sesi putar dibuka saat
/// lagu baru mulai, ditutup saat lagu berganti, selesai, atau recorder
/// dibuang. Sesi dicatat ke database bila memenuhi ambang PRD B2.7:
/// terdengar lebih dari 10 detik, atau lagu selesai diputar.
///
/// Durasi yang dicatat adalah waktu yang benar-benar terdengar, dihitung
/// dari selisih posisi putar antar tick: lompat maju/mundur (seek)
/// tidak dihitung, dan selisih per tick dijepit ke 5 detik supaya jeda
/// lama antar tick (mis. app kembali dari latar) tidak menggelembungkan
/// angka.
///
/// Kegagalan database tidak pernah mengganggu pemutaran: semua tulis
/// dibungkus try/catch dan hanya ditulis ke log debug.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../player/audio_player_port.dart';
import '../player/player_state.dart';
import '../player/track.dart';
import 'library_service.dart';
import 'track_songs.dart';

/// Selisih posisi maksimum yang dihitung dalam satu tick posisi.
/// Tick normal datang beberapa kali per detik; selisih di atas ini
/// berarti seek atau lompatan, bukan waktu mendengarkan.
const int _maxDeltaMs = 5000;

class PlayHistoryRecorder {
  PlayHistoryRecorder({required this.port, required this.library});

  final AudioPlayerPort port;
  final LibraryService library;

  StreamSubscription<PlayerSnapshot>? _stateSub;
  StreamSubscription<Duration>? _positionSub;

  Track? _currentTrack;
  int _accumulatedMs = 0;
  Duration? _lastPosition;
  bool _completed = false;
  bool _started = false;

  /// Mulai mendengarkan pemutar. Aman dipanggil dua kali.
  void start() {
    if (_started) return;
    _started = true;
    _stateSub = port.stateStream.listen(_onState);
    _positionSub = port.positionStream.listen(_onPosition);
    // Bila pemutar sudah memutar saat recorder dibuat (mis. recorder
    // dibuat ulang), buka sesi dari snapshot yang ada.
    _onState(port.snapshot);
  }

  /// Tutup sesi yang sedang berjalan (dicatat bila memenuhi ambang),
  /// lalu berhenti mendengarkan.
  Future<void> dispose() async {
    _started = false;
    await _stateSub?.cancel();
    await _positionSub?.cancel();
    _stateSub = null;
    _positionSub = null;
    await _closeSession();
  }

  void _onState(PlayerSnapshot snapshot) {
    final Track? track = snapshot.currentTrack;
    final String? newId = track?.videoId;
    final String? oldId = _currentTrack?.videoId;
    if (newId != oldId) {
      // Lagu berganti (atau antrean dikosongkan): tutup sesi lama,
      // buka sesi baru bila ada lagu.
      unawaited(_closeSession());
      if (track != null) {
        _openSession(track);
      }
      return;
    }
    if (snapshot.status == PlayerStatus.completed && _currentTrack != null) {
      // Lagu selesai: sesi dicatat walau durasi terdengarnya di bawah
      // ambang 10 detik (lagu yang sangat pendek).
      _completed = true;
      unawaited(_closeSession());
    }
  }

  void _onPosition(Duration position) {
    // Pulih sendiri bila event state tertinggal dari tick posisi (kedua
    // stream terpisah, urutannya tidak dijamin): buka sesi dari snapshot
    // yang ada daripada membuang tick.
    if (_currentTrack == null) {
      final Track? track = port.snapshot.currentTrack;
      if (track == null) return;
      _openSession(track);
    }
    final Duration? last = _lastPosition;
    _lastPosition = position;
    if (last == null) return;
    final int deltaMs = position.inMilliseconds - last.inMilliseconds;
    if (deltaMs < 0 || deltaMs > _maxDeltaMs) return;
    _accumulatedMs += deltaMs;
  }

  void _openSession(Track track) {
    _currentTrack = track;
    _accumulatedMs = 0;
    _lastPosition = null;
    _completed = false;
    // Simpan metadata lagu supaya baris lagu (dan FTS-nya) ada saat
    // sesi dicatat. Lagu TIDAK masuk Library dari sini: sekadar
    // diputar tidak menambah Library.
    unawaited(
      library
          .upsertSong(
            track.toSongsCompanion(),
            artistNames: track.artistNames,
            artistChannelIds: track.artistChannelIds,
            album: track.albumCompanion,
          )
          .catchError((Object error) {
            debugPrint('PlayHistoryRecorder: gagal menyimpan lagu: $error');
          }),
    );
  }

  Future<void> _closeSession() async {
    final Track? track = _currentTrack;
    final int playedMs = _accumulatedMs;
    final bool completed = _completed;
    // Kosongkan state dulu (sinkron) supaya pemanggilan ganda atau
    // event yang datang saat tulis database berjalan tidak mencatat
    // sesi yang sama dua kali.
    _currentTrack = null;
    _accumulatedMs = 0;
    _lastPosition = null;
    _completed = false;
    if (track == null) return;
    if (playedMs < kMinPlayEventMs && !completed) return;
    try {
      await library.recordPlay(
        songId: track.videoId,
        timestamp: DateTime.now(),
        playTimeMs: playedMs,
      );
    } catch (error) {
      debugPrint('PlayHistoryRecorder: gagal mencatat riwayat: $error');
    }
  }
}
