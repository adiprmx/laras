/// Kualitas unduhan: 3 opsi kanonis (PRD B3.2).
///
/// Pemetaan ke itag diputuskan P5 dari format audio yang tersedia di
/// respons player (lihat `pickAudioFormat` di lapisan ekstraksi):
///
/// * Terbaik: itag 251 (Opus, sampai sekitar 160 kbps). Urutan turun
///   mengikuti urutan kualitas streaming kanonis: 251, 140, 250, 249, 139.
/// * Seimbang: itag 140 (AAC 128 kbps). Bila 140 tidak ada, turun ke 250
///   (Opus sekitar 70 kbps, paling dekat karakternya dengan "seimbang"),
///   lalu 249, 139, dan 251 sebagai jalan terakhir (lebih baik lagu
///   terunduh dengan kualitas di atas pilihan daripada gagal).
/// * Hemat data: itag 249 (Opus sekitar 50 kbps), lalu 139 (AAC 48 kbps),
///   lalu naik bila perlu supaya lagu tetap bisa diunduh (250, 140, 251).
///
/// Perkiraan ukuran memakai rumus PRD (bitrate x durasi / 8) dengan
/// bitrate nominal tiap tingkat: 160 kbps, 128 kbps, 50 kbps. Angka ini
/// adalah perkiraan untuk dialog unduh, bukan janji: ukuran nyata
/// dibaca dari `contentLength` server saat unduhan berjalan.
library;

/// Kualitas unduhan.
enum DownloadQuality {
  /// Terbaik: itag 251 (Opus sampai sekitar 160 kbps).
  best,

  /// Seimbang: itag 140 (AAC 128 kbps).
  balanced,

  /// Hemat data: itag 249 (Opus sekitar 50 kbps) atau 139.
  dataSaver;

  /// Urutan itag yang dicoba untuk kualitas ini (pertama = pilihan utama).
  List<int> get itagOrder {
    switch (this) {
      case DownloadQuality.best:
        return const <int>[251, 140, 250, 249, 139];
      case DownloadQuality.balanced:
        return const <int>[140, 250, 249, 139, 251];
      case DownloadQuality.dataSaver:
        return const <int>[249, 139, 250, 140, 251];
    }
  }

  /// Bitrate nominal (bit per detik) untuk perkiraan ukuran.
  int get nominalBitrate {
    switch (this) {
      case DownloadQuality.best:
        return 160000;
      case DownloadQuality.balanced:
        return 128000;
      case DownloadQuality.dataSaver:
        return 50000;
    }
  }

  /// Perkiraan ukuran file (byte) untuk lagu berdurasi [duration],
  /// memakai rumus bitrate x durasi / 8.
  int estimateBytes(Duration duration) {
    return nominalBitrate * duration.inSeconds ~/ 8;
  }

  /// Itag utama kualitas ini (dipakai kolom `quality` di download_jobs).
  int get primaryItag => itagOrder.first;

  /// Kualitas dari itag utama yang tersimpan, atau null bila tidak dikenal.
  static DownloadQuality? fromPrimaryItag(int itag) {
    for (final DownloadQuality quality in DownloadQuality.values) {
      if (quality.primaryItag == itag) return quality;
    }
    return null;
  }
}
