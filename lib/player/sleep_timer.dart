/// Timer tidur (P7): hentikan pemutaran setelah waktu yang dipilih.
///
/// Dua mode: berbasis waktu (preset 5/10/15/30/45/60 menit atau kustom
/// 1-180 menit) dan "sesudah lagu ini habis". Saat timer habis, pemutar
/// DIJEDA (bukan dihentikan total) supaya antrean dan posisi tetap utuh
/// saat pengguna kembali — penyimpangan dari PRD ("menghentikan service")
/// yang dicatat di p7-notes.
///
/// Mode akhir-lagu: bila lagu berganti OTOMATIS (posisi terakhir dekat
/// akhir lagu, kurang dari 5 detik dari durasi), timer dianggap selesai:
/// jeda + event [SleepTimerEvent.done]. Bila pengguna ganti lagu MANUAL
/// (posisi di tengah lagu), timer dibatalkan + event
/// [SleepTimerEvent.cancelledByTrackChange] (pesan ARB
/// `sleepTimerCancelled`). Heuristik ini punya edge case yang
/// didokumentasikan: skip manual di 5 detik terakhir lagu terbaca
/// sebagai pergantian otomatis, dan bila durasi tidak diketahui,
/// pergantian lagu dianggap otomatis.
///
/// Batas lain: dengan mode ulangi-satu-lagu, lagu tidak pernah berganti,
/// jadi timer akhir-lagu menunggu sampai pengguna ganti lagu sendiri.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'audio_player_port.dart';
import 'player_state.dart';

/// Mode timer tidur yang sedang aktif.
enum SleepTimerMode {
  /// Berhenti sesudah durasi habis.
  timed,

  /// Berhenti sesudah lagu yang sedang diputar habis.
  afterSong,
}

/// Kejadian timer tidur (untuk SnackBar di layar pemutar).
enum SleepTimerEvent {
  /// Timer habis dan pemutaran dijeda.
  done,

  /// Timer batal karena pengguna ganti lagu manual.
  cancelledByTrackChange,
}

/// Preset timer tidur dalam menit (dipakai lembar pemilih).
const List<int> kSleepTimerPresets = <int>[5, 10, 15, 30, 45, 60];

/// Batas kustom timer tidur dalam menit.
const int kSleepTimerMinMinutes = 1;

/// Batas kustom timer tidur dalam menit.
const int kSleepTimerMaxMinutes = 180;

/// Jarak dari akhir lagu yang masih dianggap "lagu hampir habis" untuk
/// membedakan pergantian otomatis dari ganti lagu manual.
const Duration kSleepTimerEndThreshold = Duration(seconds: 5);

/// Timer tidur: menghitung mundur lalu menjeda pemutar.
class SleepTimerService {
  SleepTimerService({required AudioPlayerPort port})
    : _port = port; // ignore: prefer_initializing_formals

  final AudioPlayerPort _port;

  final StreamController<SleepTimerEvent> _events =
      StreamController<SleepTimerEvent>.broadcast();

  /// Kejadian timer (done / dibatalkan karena ganti lagu).
  Stream<SleepTimerEvent> get events => _events.stream;

  /// Sisa waktu; null bila timer mati atau mode akhir-lagu.
  final ValueNotifier<Duration?> remaining = ValueNotifier<Duration?>(null);

  /// Mode yang aktif; null bila timer mati.
  final ValueNotifier<SleepTimerMode?> mode =
      ValueNotifier<SleepTimerMode?>(null);

  /// True bila ada timer yang sedang berjalan.
  bool get isActive => mode.value != null;

  Timer? _timer;
  StreamSubscription<PlayerSnapshot>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  String? _trackIdAtStart;
  Duration _lastPosition = Duration.zero;
  Duration? _lastDuration;
  bool _disposed = false;

  /// Mulai timer berbasis waktu. [duration] dijepit ke 1-180 menit.
  void startTimed(Duration duration) {
    if (_disposed) return;
    // Durasi di bawah satu menit (mis. dari tes) tetap dihormati apa
    // adanya; di atas itu, dijepit ke 1-180 menit (per detik, supaya
    // 90 detik tidak terpotong jadi 60).
    final Duration effective = duration < const Duration(minutes: 1)
        ? duration
        : Duration(
            seconds: duration.inSeconds.clamp(
              kSleepTimerMinMinutes * 60,
              kSleepTimerMaxMinutes * 60,
            ),
          );
    _reset();
    mode.value = SleepTimerMode.timed;
    remaining.value = effective;
    // Hitung mundur per detak (bukan deadline DateTime.now()): jam
    // sistem tidak bisa dipalsukan fake_async (withClock hanya
    // memengaruhi clock.now()), sementara detak periodik 1 detik
    // deterministik di tes maupun produksi. Penyimpangan akumulasi
    // Timer.periodic tidak berarti untuk timer skala menit.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Mulai timer "sesudah lagu ini habis". Bila tidak ada lagu yang
  /// diputar, tidak terjadi apa-apa.
  void startAfterSong() {
    if (_disposed) return;
    final PlayerSnapshot snap = _port.snapshot;
    final String? videoId = snap.currentTrack?.videoId;
    if (videoId == null) return;
    _reset();
    mode.value = SleepTimerMode.afterSong;
    remaining.value = null;
    _trackIdAtStart = videoId;
    _lastPosition = _port.position;
    _lastDuration = snap.duration ?? snap.currentTrack?.duration;
    _positionSub = _port.positionStream.listen((Duration p) {
      _lastPosition = p;
    });
    _stateSub = _port.stateStream.listen(_onSnapshot);
  }

  /// Matikan timer (tanpa event, tanpa menjeda).
  void cancel() {
    _reset();
    mode.value = null;
    remaining.value = null;
  }

  void _tick() {
    final Duration left =
        (remaining.value ?? Duration.zero) - const Duration(seconds: 1);
    if (left <= Duration.zero) {
      remaining.value = Duration.zero;
      unawaited(_finish());
      return;
    }
    remaining.value = left;
  }

  void _onSnapshot(PlayerSnapshot snap) {
    if (mode.value != SleepTimerMode.afterSong) return;
    final Duration? duration = snap.duration ?? snap.currentTrack?.duration;
    if (duration != null) _lastDuration = duration;
    final String? videoId = snap.currentTrack?.videoId;
    final String? started = _trackIdAtStart;
    if (started == null) return;
    if (videoId == null) {
      // Antrean dikosongkan: timer tidak bermakna lagi, mati diam-diam.
      cancel();
      return;
    }
    if (videoId == started) {
      // Lagu terakhir antrean selesai tanpa ganti lagu (mode ulangi
      // mati): status completed adalah "lagu ini habis".
      if (snap.status == PlayerStatus.completed) {
        unawaited(_finish());
      }
      return;
    }
    // Lagu berganti: otomatis (di ujung lagu) atau manual (di tengah)?
    final Duration? total = _lastDuration;
    final bool nearEnd =
        total == null ||
        _lastPosition >= total - kSleepTimerEndThreshold;
    if (nearEnd) {
      unawaited(_finish());
    } else {
      cancel();
      _events.add(SleepTimerEvent.cancelledByTrackChange);
    }
  }

  Future<void> _finish() async {
    if (mode.value == null) return;
    _reset();
    mode.value = null;
    remaining.value = null;
    try {
      await _port.pause();
    } on Object {
      // Port gagal dijeda (mis. sudah dispose): event tetap dikirim,
      // pemutaran berhenti atau tidak adalah urusan port.
    }
    if (!_disposed) _events.add(SleepTimerEvent.done);
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _stateSub?.cancel();
    _stateSub = null;
    _positionSub?.cancel();
    _positionSub = null;
    _trackIdAtStart = null;
    _lastPosition = Duration.zero;
    _lastDuration = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    _reset();
    remaining.dispose();
    mode.dispose();
    await _events.close();
  }
}
