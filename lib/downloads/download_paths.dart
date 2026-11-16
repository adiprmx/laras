/// Lokasi penyimpanan unduhan dan cache streaming (arsitektur 5.1).
///
/// Keputusan lokasi (P5, mengikuti arsitektur yang sudah diputuskan
/// Fase 1):
///
/// * Unduhan: app-specific external storage
///   (`getExternalStorageDirectory()` + `/downloads`). Di bawah scoped
///   storage API 29+, app tidak butuh izin tambahan untuk direktori
///   miliknya sendiri, dan file ikut terhapus saat app dihapus
///   (perilaku yang benar untuk konten unduhan app). Bila external
///   storage tidak tersedia (null), jatuh ke documents directory.
///   `getApplicationDocumentsDirectory()` TIDAK dipakai sebagai utama:
///   penyimpanan internal lebih sempit di HP target (RAM 3 GB) dan
///   unduhan adalah pemakai ruang terbesar app.
/// * Cache streaming: `getTemporaryDirectory()` + `/stream-cache`.
///   Sistem boleh membersihkan direktori ini saat ruang menipis; itu
///   bisa diterima karena cache bisa dibangun ulang (berbeda dengan
///   unduhan yang tidak boleh hilang diam-diam).
///
/// Dua direktori TERPISAH adalah pagar K9: eviction cache hanya
/// menyentuh direktori cache dan tidak pernah menghapus unduhan.
///
/// Nama file: `<videoId>.<ekstensi>` untuk unduhan (arsitektur 5.1),
/// `<videoId>_<itag>.<ekstensi>` untuk cache (kunci manifest
/// `cache_entries` adalah videoId + itag). videoId YouTube hanya berisi
/// huruf, angka, `-`, dan `_`, jadi aman sebagai nama file; validasi
/// tetap ditegakkan (ArgumentError bila ada karakter lain) supaya
/// metadata dari jaringan tidak pernah bisa dipakai path traversal
/// (arsitektur S6). Judul lagu TIDAK dipakai sebagai nama file.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Nama subdirektori unduhan di dalam storage app.
const String kDownloadsDirName = 'downloads';

/// Nama subdirektori cache streaming di dalam direktori temporer.
const String kStreamCacheDirName = 'stream-cache';

/// Karakter yang diizinkan di videoId (alfabet base64 URL-safe YouTube).
final RegExp _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');

/// Karakter yang diizinkan di ekstensi file.
final RegExp _extensionPattern = RegExp(r'^[a-z0-9]+$');

/// Ekstensi file dari mimeType format audio.
///
/// Opus di dalam webm disimpan sebagai `.opus` (ExoPlayer membaca
/// kontennya, ekstensi hanya penanda); AAC di dalam mp4 sebagai `.m4a`.
/// mimeType yang tidak dikenal memakai `.bin` supaya file tetap bisa
/// ditulis tanpa menebak-nebak.
String extensionForMimeType(String mimeType) {
  final String lower = mimeType.toLowerCase();
  if (lower.contains('opus')) return 'opus';
  if (lower.startsWith('audio/mp4')) return 'm4a';
  if (lower.startsWith('audio/webm')) return 'webm';
  if (lower.startsWith('audio/mpeg')) return 'mp3';
  return 'bin';
}

/// Jalur-jalur penyimpanan unduhan dan cache.
class DownloadPaths {
  DownloadPaths({required this.downloadsDir, required this.cacheDir});

  /// Buat direktori (bila belum ada) dan kembalikan jalurnya.
  ///
  /// Dipanggil sekali di `main()` sesudah database terbuka. Gagal bila
  /// direktori tidak bisa dibuat; pemanggil menangani kegagalan itu
  /// (app tetap jalan tanpa layanan unduhan).
  static Future<DownloadPaths> create() async {
    final Directory? external = await getExternalStorageDirectory();
    final Directory base =
        external ?? await getApplicationDocumentsDirectory();
    final Directory downloads = Directory('${base.path}/$kDownloadsDirName');
    await downloads.create(recursive: true);
    final Directory temp = await getTemporaryDirectory();
    final Directory cache = Directory('${temp.path}/$kStreamCacheDirName');
    await cache.create(recursive: true);
    return DownloadPaths(downloadsDir: downloads, cacheDir: cache);
  }

  /// Direktori unduhan permanen.
  final Directory downloadsDir;

  /// Direktori cache streaming (sementara, boleh di-eviction).
  final Directory cacheDir;

  static void _checkVideoId(String videoId) {
    if (!_videoIdPattern.hasMatch(videoId)) {
      throw ArgumentError.value(
        videoId,
        'videoId',
        'videoId hanya boleh berisi huruf, angka, - dan _',
      );
    }
  }

  static void _checkExtension(String extension) {
    if (!_extensionPattern.hasMatch(extension)) {
      throw ArgumentError.value(
        extension,
        'extension',
        'ekstensi hanya boleh berisi huruf kecil dan angka',
      );
    }
  }

  /// Nama file unduhan (relatif, disimpan di `songs.file_path`).
  String downloadFileName(String videoId, String extension) {
    _checkVideoId(videoId);
    _checkExtension(extension);
    return '$videoId.$extension';
  }

  /// File unduhan final untuk [videoId].
  File downloadFile(String videoId, String extension) {
    return File('${downloadsDir.path}/${downloadFileName(videoId, extension)}');
  }

  /// File sementara unduhan (`.part`), di-rename saat selesai.
  File downloadPartFile(String videoId, String extension) {
    return File('${downloadFile(videoId, extension).path}.part');
  }

  /// Benar bila [relativePath] adalah nama relatif unduhan yang sah
  /// (`<videoId>.<ekstensi>`). Dipakai pemanggil yang hanya punya
  /// direktori sebagai string dan tidak bisa memakai
  /// [downloadFileFromRelative] (mis. `SongView.toTrack`, R2-L3).
  static bool isValidDownloadRelativePath(String relativePath) {
    final List<String> parts = relativePath.split('.');
    if (parts.length != 2) return false;
    if (!_videoIdPattern.hasMatch(parts[0])) return false;
    if (!_extensionPattern.hasMatch(parts[1])) return false;
    return true;
  }

  /// File unduhan dari nama relatif yang tersimpan di database.
  ///
  /// Nama relatif selalu `<videoId>.<ekstensi>`; bila formatnya tidak
  /// cocok (data lama/rusak), mengembalikan null daripada menebak path.
  File? downloadFileFromRelative(String relativePath) {
    if (!isValidDownloadRelativePath(relativePath)) return null;
    return File('${downloadsDir.path}/$relativePath');
  }

  /// Nama file cache (kunci manifest + ekstensi).
  String cacheFileName(String videoId, int itag, String extension) {
    _checkVideoId(videoId);
    _checkExtension(extension);
    return '${videoId}_$itag.$extension';
  }

  /// File cache final untuk [videoId] + [itag].
  File cacheFile(String videoId, int itag, String extension) {
    return File('${cacheDir.path}/${cacheFileName(videoId, itag, extension)}');
  }

  /// File sementara cache (`.part`).
  File cachePartFile(String videoId, int itag, String extension) {
    return File('${cacheFile(videoId, itag, extension).path}.part');
  }

  /// Benar bila [relativePath] adalah nama relatif cache yang sah
  /// (`<videoId>_<itag>.<ekstensi>`). videoId boleh berisi `_`, jadi
  /// itag dipisahkan di `_` TERAKHIR dan harus berupa angka saja.
  static bool isValidCacheRelativePath(String relativePath) {
    final List<String> parts = relativePath.split('.');
    if (parts.length != 2) return false;
    final String name = parts[0];
    final int cut = name.lastIndexOf('_');
    if (cut <= 0) return false;
    if (!_videoIdPattern.hasMatch(name.substring(0, cut))) return false;
    if (!RegExp(r'^[0-9]+$').hasMatch(name.substring(cut + 1))) return false;
    if (!_extensionPattern.hasMatch(parts[1])) return false;
    return true;
  }

  /// File cache dari nama relatif yang tersimpan di database (R2-L3).
  ///
  /// Cermin [downloadFileFromRelative]: nama relatif selalu
  /// `<videoId>_<itag>.<ekstensi>`; bila formatnya tidak cocok (data
  /// lama/rusak — mis. `../` dari database yang dirusak), mengembalikan
  /// null daripada membangun path di luar direktori cache. Enam situs
  /// di `StreamCacheService` yang dulu membangun `File` langsung dari
  /// `entry.filePath` WAJIB memakai helper ini.
  File? cacheFileFromRelative(String relativePath) {
    if (!isValidCacheRelativePath(relativePath)) return null;
    return File('${cacheDir.path}/$relativePath');
  }

  /// Kunci manifest cache untuk [videoId] + [itag].
  static String cacheKey(String videoId, int itag) => '${videoId}_$itag';
}
