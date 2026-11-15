/// Interface player milik app: satu-satunya jalan UI ke audio.
///
/// Semua akses audio lewat interface ini; widget tidak pernah memanggil
/// just_audio, audio_service, atau audio_session langsung. Implementasi
/// nyata ([JustAudioPlayerPort]) hidup di balik interface ini dan bisa
/// diganti tanpa menyentuh UI, antrean, atau state management.
///
/// Aturan yang mengikat: antrean menyimpan identitas lagu, bukan URL.
/// URL stream hanya ada di memori implementasi dan tidak pernah keluar
/// lewat interface ini.
library;

import 'player_state.dart';
import 'queue_controller.dart';
import 'track.dart';

export 'queue_controller.dart' show kMaxQueueLength;

abstract class AudioPlayerPort {
  /// Snapshot state terakhir (untuk `initialData` StreamBuilder).
  PlayerSnapshot get snapshot;

  /// State pemutar; disiarkan setiap kali snapshot berubah.
  Stream<PlayerSnapshot> get stateStream;

  /// Posisi putar terakhir.
  Duration get position;

  /// Posisi putar; disiarkan beberapa kali per detik selama memutar.
  Stream<Duration> get positionStream;

  /// Posisi buffer terakhir (seberapa jauh audio sudah diunduh engine).
  Duration get bufferedPosition;

  /// Posisi buffer.
  Stream<Duration> get bufferedPositionStream;

  /// Ganti seluruh antrean dan muat lagu di [initialIndex].
  ///
  /// Melempar [ArgumentError] bila daftar lebih dari [kMaxQueueLength].
  /// Tidak memutar sendiri kecuali [autoplay] benar.
  Future<void> setQueue(
    List<Track> tracks, {
    int initialIndex = 0,
    bool autoplay = false,
  });

  /// Putar lagu yang sedang dimuat (atau muat lalu putar bila belum ada
  /// sumber). Setelah gagal total, memutar berarti mencoba lagi dari awal.
  Future<void> play();

  /// Jeda. Posisi dipertahankan.
  Future<void> pause();

  /// Berhenti total dan lepas sumber audio. Antrean dipertahankan;
  /// [play] sesudahnya memutar lagi dari awal lagu yang sama.
  Future<void> stop();

  /// Lompat ke [position] dalam lagu yang sedang diputar.
  Future<void> seek(Duration position);

  /// Lagu berikutnya. Di ujung antrean: membungkus ke awal bila mode
  /// ulangi semua aktif, diam bila tidak.
  Future<void> skipToNext();

  /// Lagu sebelumnya. Bila posisi sudah lewat 3 detik, kembali ke awal
  /// lagu yang sama.
  Future<void> skipToPrevious();

  /// Lompat ke lagu di [index] urutan putar. Mengetuk lagu yang sedang
  /// diputar memulai ulang lagu itu dari awal.
  Future<void> skipToIndex(int index);

  /// Tambah lagu di ujung antrean. Mengembalikan false bila antrean penuh.
  Future<bool> addToQueue(Track track);

  /// Sisipkan lagu di [index] urutan putar. Mengembalikan false bila
  /// antrean penuh atau indeks di luar jangkauan.
  Future<bool> insertInQueue(int index, Track track);

  /// Hapus lagu di [index] urutan putar. Menghapus lagu yang sedang
  /// diputar memindahkan pemutaran ke lagu berikutnya.
  Future<void> removeFromQueue(int index);

  /// Pindahkan lagu dari [from] ke [to] dalam urutan putar.
  Future<void> moveInQueue(int from, int to);

  /// Kosongkan antrean dan hentikan pemutaran.
  Future<void> clearQueue();

  /// Nyalakan atau matikan mode acak. Lagu yang sedang diputar tetap sama.
  Future<void> setShuffle(bool enabled);

  /// Atur mode pengulangan.
  Future<void> setRepeatMode(RepeatMode mode);

  /// Atur kecepatan putar (1.0 = normal). Nilai dijepit ke 0.25-3.0.
  Future<void> setSpeed(double speed);

  /// Atur nada suara (1.0 = normal). Nilai dijepit ke 0.5-2.0.
  /// Android saja.
  Future<void> setPitch(double pitch);

  /// Nyalakan atau matikan lewati bagian hening. Android saja.
  Future<void> setSkipSilence(bool enabled);

  /// Bebaskan semua resource. Port tidak bisa dipakai lagi sesudah ini.
  Future<void> dispose();
}
