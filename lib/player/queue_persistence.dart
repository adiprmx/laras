/// Persistensi + restore antrean (P7, MUST #3).
///
/// Menyimpan antrean (urutan putar), indeks lagu, posisi, dan mode putar
/// ke database, dan memulihkannya saat app dibuka lagi.
///
/// - Simpan antrean: debounce 500 mdtk sesudah snapshot berubah (supaya
///   geser antrean beruntun tidak menulis puluhan kali).
/// - Simpan posisi: paling sering tiap 5 detik saat memutar, plus segera
///   saat dijeda (posisi terakhir yang akurat).
/// - Restore: dipanggil dari `main()` sesudah database dibuka, di latar
///   (tidak memblokir frame pertama). Hanya berjalan bila antrean port
///   masih kosong.
///
/// Kompromi shuffle yang didokumentasikan: yang disimpan adalah urutan
/// putar. Bila shuffle aktif saat disimpan, restore memulihkan urutan
/// putar tersimpan sebagai basis lalu menyalakan shuffle lagi — urutan
/// diacak ulang (lagu yang sedang diputar tetap pertama, himpunan lagu
/// sama). Urutan acak persis tidak bisa dipulihkan tanpa menyimpan
/// urutan asli terpisah.
///
/// Restore memanggil `setQueue` (yang memuat lagu pertama — satu resolve
/// jaringan untuk lagu streaming). Offline, lagu streaming tampil dengan
/// status gagal seperti biasa; lagu terunduh dipulihkan tanpa jaringan.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:laras/data/database.dart';

import 'audio_player_port.dart';
import 'player_state.dart';
import 'track.dart';

/// Persistensi antrean + restore sesudah restart.
class QueuePersistence {
  QueuePersistence({
    required AudioPlayerPort port,
    required LibraryService library,
    String? downloadsDir,
  }) : _port = port, // ignore: prefer_initializing_formals
       _library = library, // ignore: prefer_initializing_formals
       _downloadsDir = downloadsDir; // ignore: prefer_initializing_formals

  final AudioPlayerPort _port;
  final LibraryService _library;
  final String? _downloadsDir;

  static const Duration _queueDebounce = Duration(milliseconds: 500);
  static const Duration _positionInterval = Duration(seconds: 5);

  /// Posisi yang kurang dari ini dari akhir lagu dianggap "lagu habis":
  /// restore mulai dari awal lagu, bukan dari ujungnya.
  static const Duration _nearEndThreshold = Duration(seconds: 5);

  StreamSubscription<PlayerSnapshot>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  Timer? _debounceTimer;
  DateTime? _lastPositionSave;
  bool _saveInFlight = false;
  bool _saveDirty = false;
  bool _disposed = false;

  /// Mulai mengawasi port dan menyimpan perubahan.
  void start() {
    _stateSub ??= _port.stateStream.listen(_onSnapshot);
    _positionSub ??= _port.positionStream.listen(_onPosition);
  }

  void _onSnapshot(PlayerSnapshot snap) {
    // Jeda = momen terbaik menyimpan posisi akurat (pengguna menutup
    // app sesudah jeda tidak kehilangan posisi 5 detik terakhir).
    if (!snap.playing) {
      unawaited(_savePosition());
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_queueDebounce, () {
      unawaited(_saveQueue(_port.snapshot));
    });
  }

  void _onPosition(Duration position) {
    if (!_port.snapshot.playing) return;
    final DateTime now = DateTime.now();
    final DateTime? last = _lastPositionSave;
    if (last != null && now.difference(last) < _positionInterval) return;
    _lastPositionSave = now;
    unawaited(_savePosition());
  }

  /// Simpan antrean + status sekarang juga (tanpa debounce). Dipakai tes
  /// dan bila ada pemicu eksplisit; kegagalan dicatat, bukan dilempar.
  Future<void> saveNow() async {
    _debounceTimer?.cancel();
    await _saveQueue(_port.snapshot);
    await _savePosition();
  }

  Future<void> _saveQueue(PlayerSnapshot snap) async {
    if (_saveInFlight) {
      _saveDirty = true;
      return;
    }
    _saveInFlight = true;
    try {
      await _writeQueue(snap);
      // Perubahan yang tiba selagi menyimpan ditulis sesudahnya.
      while (_saveDirty && !_disposed) {
        _saveDirty = false;
        await _writeQueue(_port.snapshot);
      }
    } on Object catch (e) {
      debugPrint('Laras: simpan antrean gagal: $e');
    } finally {
      _saveInFlight = false;
    }
  }

  Future<void> _writeQueue(PlayerSnapshot snap) async {
    final List<Track> queue = snap.queue;
    if (queue.isEmpty) {
      await _library.clearQueue();
    } else {
      // Lagu wajib ada di tabel songs dulu (FK queue_items -> songs).
      // Satu transaksi lewat importSongs (tanpa masuk Library: sekadar
      // diputar tidak memasukkan lagu ke Library).
      await _library.importSongs(
        queue
            .map(
              (Track track) => SongImport(
                song: track.toSongsCompanion(),
                artistNames: track.artistNames,
                artistChannelIds: track.artistChannelIds,
                album: track.albumCompanion,
              ),
            )
            .toList(growable: false),
        addToLibrary: false,
      );
      await _library.replaceQueue(<QueueItemsCompanion>[
        for (int i = 0; i < queue.length; i++)
          QueueItemsCompanion.insert(
            position: Value<int>(i),
            songId: queue[i].videoId,
          ),
      ]);
    }
    await _library.savePlaybackState(
      currentIndex: snap.currentIndex < 0 ? 0 : snap.currentIndex,
      positionMs: _port.position.inMilliseconds,
      shuffleEnabled: snap.shuffleEnabled,
      repeatMode: _repeatModeValue(snap.repeatMode),
    );
  }

  Future<void> _savePosition() async {
    try {
      await _library.savePlaybackPosition(_port.position.inMilliseconds);
    } on Object catch (e) {
      debugPrint('Laras: simpan posisi gagal: $e');
    }
  }

  /// Pulihkan antrean + posisi dari database. Mengembalikan true bila
  /// ada antrean yang dipulihkan. Kegagalan apa pun mengembalikan false
  /// (app tetap jalan tanpa restore).
  Future<bool> restore() async {
    if (_port.snapshot.queue.isNotEmpty) return false;
    try {
      final List<QueueItem> items = await _library.loadQueue();
      if (items.isEmpty) return false;
      final PlaybackStateData? state = await _library.loadPlaybackState();
      final List<String> ids = items
          .map((QueueItem item) => item.songId)
          .toList(growable: false);
      final List<SongView> views = await _library.songsByIds(ids);
      if (views.isEmpty) return false;
      final List<Track> tracks = views
          .map((SongView view) => view.toTrack(downloadsDir: _downloadsDir))
          .toList(growable: false);
      final int index = (state?.currentIndex ?? 0).clamp(
        0,
        tracks.length - 1,
      );
      await _port.setQueue(tracks, initialIndex: index, autoplay: false);
      if (state != null) {
        if (state.shuffleEnabled) {
          await _port.setShuffle(true);
        }
        await _port.setRepeatMode(_repeatModeFromValue(state.repeatMode));
        final int positionMs = state.positionMs;
        if (positionMs > 0) {
          final Duration? total = tracks[index].duration;
          final bool nearEnd =
              total != null &&
              positionMs >= total.inMilliseconds - _nearEndThreshold.inMilliseconds;
          if (!nearEnd) {
            try {
              await _port.seek(Duration(milliseconds: positionMs));
            } on Object catch (e) {
              // Seek gagal (mis. lagu gagal dimuat offline): antrean
              // tetap pulih, posisi mulai dari awal lagu.
              debugPrint('Laras: seek restore gagal: $e');
            }
          }
        }
      }
      return true;
    } on Object catch (e) {
      debugPrint('Laras: restore antrean gagal: $e');
      return false;
    }
  }

  static int _repeatModeValue(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return RepeatModeValue.off;
      case RepeatMode.all:
        return RepeatModeValue.all;
      case RepeatMode.one:
        return RepeatModeValue.one;
    }
  }

  static RepeatMode _repeatModeFromValue(int value) {
    switch (value) {
      case RepeatModeValue.all:
        return RepeatMode.all;
      case RepeatModeValue.one:
        return RepeatMode.one;
      case RepeatModeValue.off:
      default:
        return RepeatMode.off;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _debounceTimer?.cancel();
    await _stateSub?.cancel();
    await _positionSub?.cancel();
    _stateSub = null;
    _positionSub = null;
  }
}
