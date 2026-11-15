/// Logika antrean murni: urutan putar, acak, ulang, dan batas 200 lagu.
///
/// Tanpa dependensi engine apa pun, jadi seluruh perilaku antrean bisa
/// dites tanpa platform audio. Engine (just_audio) selalu jalan dengan
/// shuffle mati: urutan putar sepenuhnya milik controller ini.
///
/// Dua daftar dijaga: urutan asli (urutan lagu dimasukkan) dan urutan
/// putar (sama dengan urutan asli bila acak mati; lagu yang sedang
/// diputar di depan + sisanya diacak bila acak aktif). Mematikan acak
/// mengembalikan urutan asli dengan lagu yang sedang diputar tetap sama.
library;

import 'dart:math';

import 'player_state.dart';
import 'track.dart';

/// Batas antrean (PRD): 200 lagu. Pesan ke pengguna ada di ARB `queueFull`.
const int kMaxQueueLength = 200;

class QueueController {
  QueueController({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<Track> _original = <Track>[];
  List<Track> _playOrder = <Track>[];
  int _currentIndex = -1;
  bool _shuffleEnabled = false;
  RepeatMode _repeatMode = RepeatMode.off;

  /// Antrean dalam urutan putar.
  List<Track> get tracks => List<Track>.unmodifiable(_playOrder);

  int get length => _playOrder.length;

  bool get isEmpty => _playOrder.isEmpty;

  int get currentIndex => _currentIndex;

  Track? get current =>
      _currentIndex >= 0 && _currentIndex < _playOrder.length
      ? _playOrder[_currentIndex]
      : null;

  bool get shuffleEnabled => _shuffleEnabled;

  RepeatMode get repeatMode => _repeatMode;

  /// Lagu setelah lagu yang sedang diputar, tanpa memperhitungkan
  /// pengulangan (untuk pramuat jendela gapless). Null di ujung antrean.
  Track? get trackAfterCurrent {
    if (_currentIndex < 0 || _currentIndex + 1 >= _playOrder.length) {
      return null;
    }
    return _playOrder[_currentIndex + 1];
  }

  /// Ganti seluruh antrean. Melempar [ArgumentError] bila daftar lebih
  /// dari [kMaxQueueLength] atau [initialIndex] di luar jangkauan.
  void setQueue(List<Track> tracks, {int initialIndex = 0}) {
    if (tracks.length > kMaxQueueLength) {
      throw ArgumentError(
        'Antrean maksimal $kMaxQueueLength lagu, got ${tracks.length}.',
      );
    }
    if (tracks.isEmpty) {
      _original = <Track>[];
      _playOrder = <Track>[];
      _currentIndex = -1;
      return;
    }
    if (initialIndex < 0 || initialIndex >= tracks.length) {
      throw ArgumentError('initialIndex $initialIndex di luar antrean.');
    }
    _original = List<Track>.of(tracks);
    if (_shuffleEnabled) {
      _playOrder = _shuffledWithFirst(tracks[initialIndex], tracks);
      _currentIndex = 0;
    } else {
      _playOrder = List<Track>.of(tracks);
      _currentIndex = initialIndex;
    }
  }

  /// Tambah lagu di ujung antrean. Mengembalikan false bila antrean penuh.
  bool add(Track track) {
    if (_playOrder.length >= kMaxQueueLength) return false;
    _original.add(track);
    _playOrder.add(track);
    if (_currentIndex < 0) _currentIndex = 0;
    return true;
  }

  /// Sisipkan lagu di [index] urutan putar. Mengembalikan false bila
  /// antrean penuh atau indeks di luar jangkauan.
  bool insert(int index, Track track) {
    if (_playOrder.length >= kMaxQueueLength) return false;
    if (index < 0 || index > _playOrder.length) return false;
    if (_shuffleEnabled) {
      // Urutan asli tidak punya posisi yang sepadan dengan sisipan acak;
      // lagu masuk di ujung urutan asli supaya tetap ada saat acak dimatikan.
      _original.add(track);
    } else {
      _original.insert(index, track);
    }
    _playOrder.insert(index, track);
    if (_currentIndex < 0) {
      _currentIndex = 0;
    } else if (index <= _currentIndex) {
      _currentIndex++;
    }
    return true;
  }

  /// Hapus lagu di [index] urutan putar, kembalikan lagu yang dihapus.
  /// Indeks lagu yang sedang diputar dijaga tetap menunjuk lagu yang sama.
  Track removeAt(int index) {
    final Track removed = _playOrder.removeAt(index);
    _original.remove(removed);
    if (_playOrder.isEmpty) {
      _currentIndex = -1;
    } else if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      // Lagu yang sedang diputar dihapus: indeks tetap, kini menunjuk
      // lagu berikutnya; bila yang dihapus adalah lagu terakhir, mundur.
      if (_currentIndex >= _playOrder.length) {
        _currentIndex = _playOrder.length - 1;
      }
    }
    return removed;
  }

  /// Pindahkan lagu dari [from] ke [to] dalam urutan putar. Lagu yang
  /// sedang diputar diikuti identitasnya, bukan indeksnya.
  void move(int from, int to) {
    if (from == to) return;
    final Track current = _playOrder[_currentIndex];
    final Track moved = _playOrder.removeAt(from);
    _playOrder.insert(to, moved);
    if (!_shuffleEnabled) {
      _original.remove(moved);
      _original.insert(to, moved);
    }
    _currentIndex = _playOrder.indexOf(current);
  }

  void clear() {
    _original = <Track>[];
    _playOrder = <Track>[];
    _currentIndex = -1;
  }

  void jumpTo(int index) {
    if (index < 0 || index >= _playOrder.length) {
      throw ArgumentError('Indeks antrean $index di luar jangkauan.');
    }
    _currentIndex = index;
  }

  void setShuffle(bool enabled) {
    if (enabled == _shuffleEnabled) return;
    _shuffleEnabled = enabled;
    final Track? now = current;
    if (now == null) return;
    if (enabled) {
      _playOrder = _shuffledWithFirst(now, _original);
      _currentIndex = 0;
    } else {
      _playOrder = List<Track>.of(_original);
      _currentIndex = _playOrder.indexOf(now);
    }
  }

  void setRepeatMode(RepeatMode mode) {
    _repeatMode = mode;
  }

  /// Indeks berikutnya saat lagu selesai sendiri (otomatis). Mode ulangi
  /// satu lagu kembali ke lagu yang sama; mode ulangi semua membungkus
  /// ke awal; mode mati mengembalikan null di ujung antrean.
  int? nextIndexForCompletion() {
    if (_currentIndex < 0) return null;
    if (_repeatMode == RepeatMode.one) return _currentIndex;
    if (_currentIndex + 1 < _playOrder.length) return _currentIndex + 1;
    if (_repeatMode == RepeatMode.all) return 0;
    return null;
  }

  /// Indeks berikutnya saat pengguna menekan tombol berikutnya. Mode
  /// ulangi satu lagu diperlakukan seperti mode mati: tombol berikutnya
  /// selalu pindah lagu.
  int? nextIndexForSkip() {
    if (_currentIndex < 0) return null;
    if (_currentIndex + 1 < _playOrder.length) return _currentIndex + 1;
    if (_repeatMode == RepeatMode.all) return 0;
    return null;
  }

  /// Indeks sebelumnya saat pengguna menekan tombol sebelumnya. Mode
  /// ulangi semua membungkus ke ujung antrean.
  int? previousIndexForSkip() {
    if (_currentIndex < 0) return null;
    if (_currentIndex > 0) return _currentIndex - 1;
    if (_repeatMode == RepeatMode.all) return _playOrder.length - 1;
    return null;
  }

  List<Track> _shuffledWithFirst(Track first, List<Track> pool) {
    final List<Track> rest = pool.where((t) => !identical(t, first)).toList();
    for (int i = rest.length - 1; i > 0; i--) {
      final int j = _random.nextInt(i + 1);
      final Track tmp = rest[i];
      rest[i] = rest[j];
      rest[j] = tmp;
    }
    return <Track>[first, ...rest];
  }
}
