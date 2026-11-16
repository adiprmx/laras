/// Cache streaming manual (PRD B3.3, arsitektur 5.1).
///
/// Keputusan yang mengikat (sudah diputuskan PRD/arsitektur, BUKAN
/// pilihan P5):
///
/// * Cache MANUAL (file `.part` lalu rename + manifest tabel
///   `cache_entries`), BUKAN `LockCachingAudioSource`. Kelas itu ADA di
///   just_audio 0.10.6 (terverifikasi di source paket:
///   `just_audio.dart:3373`, `class LockCachingAudioSource extends
///   StreamAudioSource`), tapi ditolak dengan tiga alasan berbasis bukti:
///   (1) masih eksperimental menurut dokumentasi resminya sendiri;
///   (2) diimplementasikan lewat proxy HTTP localhost (butuh cleartext
///   non-HTTPS di Android + satu server lokal per pemutaran);
///   (3) tidak punya batas ukuran, LRU, atau manifest — eviction 500 MB
///   dan pemisahan dari unduhan tidak bisa ditegakkan lewat API-nya
///   (hanya `clearCache()` per sumber).
///
/// Cara kerja: pemutar memanggil [PlaybackCache.noteResolved] setiap
/// kali sebuah lagu berhasil di-resolve; service ini lalu mengunduh
/// salinan penuh file itu di latar (best-effort, satu file dalam satu
/// waktu, resume Range bila `.part` sudah ada). Saat lagu itu diputar
/// lagi, pemutar memakai file cache lewat [PlaybackCache.fileFor]
/// (offline penuh). Eviction LRU berjalan setiap selesai memasukkan
/// entri dan saat rekonsiliasi: entri paling lama tidak diakses dihapus
/// sampai total di bawah batas. Penghapusan file memakai API SINKRON
/// (`deleteSync`/`existsSync`): hapus file adalah operasi metadata
/// sub-detik, dan API async-nya tidak pernah kembali bila dipanggil dari
/// handler widget di tes widget (zona FakeAsync — terbukti menggantung,
/// 16 Nov 2026). Eviction TIDAK PERNAH menyentuh
/// direktori unduhan (direktori terpisah, K9) dan tidak pernah menghapus
/// file yang sedang diputar (videoId yang dilindungi lewat
/// [protectedVideoId]).
library;

// ignore_for_file: prefer_initializing_formals - konstruktor publik memakai
// parameter bernama publik + field privat; initializing formal akan
// membuat nama parameter menjadi privat dan tidak bisa dipakai pemanggil.


import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:laras/data/database.dart';

import 'download_paths.dart';

/// Batas default cache streaming: 500 MB (PRD B3.3).
const int kDefaultCacheLimitBytes = 500 * 1024 * 1024;

/// Interface cache yang dipakai pemutar. Dipisah supaya port player
/// tidak bergantung pada implementasi penuh [StreamCacheService]
/// (dan supaya tes player bisa memakai cache palsu).
abstract class PlaybackCache {
  /// File cache lengkap untuk [videoId], atau null bila belum di-cache.
  ///
  /// Memanggil ini memperbarui waktu akses terakhir entri (LRU).
  /// Entri yang filenya hilang/rusak dibersihkan dan mengembalikan null.
  Future<File?> fileFor(String videoId);

  /// Catat bahwa [videoId] baru saja di-resolve ke [url]: antre
  /// pengunduhan salinan cache di latar (best-effort, tanpa throw).
  void noteResolved(String videoId, String url, int itag, String mimeType);

  /// Hapus entri cache [videoId] (semua itag) beserta filenya.
  /// Dipanggil pemutar bila file cache ternyata gagal diputar.
  Future<void> invalidate(String videoId);
}

/// Hasil rekonsiliasi cache.
class CacheReconcileResult {
  const CacheReconcileResult({
    required this.staleEntriesDeleted,
    required this.orphanFilesDeleted,
  });

  /// Entri manifest yang filenya sudah tidak ada.
  final int staleEntriesDeleted;

  /// File di direktori cache tanpa entri manifest.
  final int orphanFilesDeleted;
}

/// Layanan cache streaming.
class StreamCacheService implements PlaybackCache {
  StreamCacheService({
    required LibraryService library,
    required DownloadPaths paths,
    Dio? dio,
    int cacheLimitBytes = kDefaultCacheLimitBytes,
    bool Function()? isBusy,
    String? Function()? protectedVideoId,
  }) : _library = library,
       _paths = paths,
       _dio = dio ?? Dio(),
       _cacheLimitBytes = cacheLimitBytes,
       _isBusy = isBusy,
       _protectedVideoId = protectedVideoId;

  final LibraryService _library;
  final DownloadPaths _paths;
  final Dio _dio;
  final int _cacheLimitBytes;

  /// Benar bila ada unduhan aktif: fetch cache ditunda supaya tidak
  /// berebut bandwidth dengan unduhan yang diminta pengguna.
  /// Null berarti "tidak sibuk".
  bool Function()? _isBusy;

  /// videoId yang sedang diputar (tidak boleh di-eviction). Callback
  /// mengembalikan null bila tidak ada lagu yang diputar.
  String? Function()? _protectedVideoId;

  /// Fetch yang sedang berjalan (maks 1): kunci manifestnya.
  String? _fetchingKey;

  /// Antrean fetch tertunda (videoId -> (url, itag, mimeType)).
  final Map<String, (String, int, String)> _pending =
      <String, (String, int, String)>{};

  bool _disposed = false;

  /// Ubah penanda sibuk (di-wire main.dart ke DownloadService).
  set isBusy(bool Function()? value) => _isBusy = value;

  /// Ubah penanda lagu yang sedang diputar (di-wire main.dart ke port).
  set protectedVideoId(String? Function()? value) =>
      _protectedVideoId = value;

  /// Batas cache saat ini (byte).
  int get cacheLimitBytes => _cacheLimitBytes;

  @override
  Future<File?> fileFor(String videoId) async {
    final List<CacheEntry> entries = await _library.cacheEntriesForVideo(
      videoId,
    );
    // Entri terbaru yang diakses dulu (bila ada lebih dari satu itag).
    entries.sort(
      (CacheEntry a, CacheEntry b) => b.lastAccessed.compareTo(a.lastAccessed),
    );
    for (final CacheEntry entry in entries) {
      final File file = File('${_paths.cacheDir.path}/${entry.filePath}');
      bool usable = false;
      try {
        if (await file.exists()) {
          final int size = await file.length();
          usable = size == entry.sizeBytes && size > 0;
        }
      } on FileSystemException {
        usable = false;
      }
      if (usable) {
        await _library.touchCacheEntry(entry.key, DateTime.now());
        return file;
      }
      // Entri basi: file hilang atau ukurannya tidak cocok.
      await _library.deleteCacheEntry(entry.key);
      try {
        if (file.existsSync()) file.deleteSync();
      } on FileSystemException {
        // File tidak bisa dihapus: rekonsiliasi berikutnya mencoba lagi.
      }
    }
    return null;
  }

  @override
  void noteResolved(String videoId, String url, int itag, String mimeType) {
    if (_disposed) return;
    _pending[videoId] = (url, itag, mimeType);
    unawaited(_pump());
  }

  /// Coba jalankan fetch yang tertunda (dipanggil saat antrean unduhan
  /// kosong, dan sesudah tiap noteResolved).
  Future<void> pumpPending() async {
    if (_disposed) return;
    await _pump();
  }

  Future<void> _pump() async {
    if (_fetchingKey != null) return;
    if (_pending.isEmpty) return;
    if (_isBusy?.call() ?? false) return;
    final MapEntry<String, (String, int, String)> next = _pending.entries.first;
    _pending.remove(next.key);
    final String videoId = next.key;
    final (String, int, String) job = next.value;
    final String key = DownloadPaths.cacheKey(videoId, job.$2);
    // Sudah lengkap di cache: tidak perlu fetch lagi.
    final CacheEntry? existing = await _library.cacheEntry(key);
    if (existing != null) {
      final File file = File('${_paths.cacheDir.path}/${existing.filePath}');
      try {
        if (await file.exists() &&
            await file.length() == existing.sizeBytes) {
          await _pump();
          return;
        }
      } on FileSystemException {
        // Lanjut fetch ulang.
      }
    }
    _fetchingKey = key;
    try {
      await _fetch(videoId, job.$1, job.$2, job.$3);
    } on Object catch (_) {
      // Best-effort: gagal fetch cache tidak pernah menjadi error
      // pengguna; lagu tetap bisa diputar dari jaringan.
    } finally {
      _fetchingKey = null;
      if (!_disposed) await _pump();
    }
  }

  /// Unduh satu file cache (resume Range dari `.part` bila ada).
  Future<void> _fetch(
    String videoId,
    String url,
    int itag,
    String mimeType,
  ) async {
    final String extension = extensionForMimeType(mimeType);
    final File partFile = _paths.cachePartFile(videoId, itag, extension);
    final File finalFile = _paths.cacheFile(videoId, itag, extension);
    int downloaded = 0;
    try {
      if (await partFile.exists()) downloaded = await partFile.length();
    } on FileSystemException {
      downloaded = 0;
    }
    final Response<ResponseBody> response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: downloaded > 0
            ? <String, String>{'Range': 'bytes=$downloaded-'}
            : null,
        // Timeout: cache fetch tidak boleh menggantung selamanya.
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final int? status = response.statusCode;
    final bool resumed = status == 206;
    if (status != 200 && status != 206) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
      );
    }
    final int? total = _contentLength(response, resumed, downloaded);
    final IOSink sink = partFile.openWrite(
      mode: resumed ? FileMode.append : FileMode.write,
    );
    int received = resumed ? downloaded : 0;
    try {
      await for (final List<int> chunk in response.data!.stream) {
        sink.add(chunk);
        // Flush per chunk (alasan sama seperti DownloadService: tanpa
        // ini .part di disk tetap 0 sampai close dan resume kehilangan
        // semua progress bila app mati di tengah fetch).
        await sink.flush();
        received += chunk.length;
      }
      await sink.close();
    } on Object catch (_) {
      try {
        await sink.close();
      } on Object catch (_) {}
      rethrow;
    }
    if (total != null && received != total) {
      throw StateError(
        'cache $videoId tidak lengkap: $received dari $total byte',
      );
    }
    await partFile.rename(finalFile.path);
    final DateTime now = DateTime.now();
    await _library.upsertCacheEntry(
      CacheEntriesCompanion.insert(
        key: DownloadPaths.cacheKey(videoId, itag),
        filePath: _paths.cacheFileName(videoId, itag, extension),
        sizeBytes: received,
        lastAccessed: now,
        createdAt: now,
      ),
    );
    await evictIfNeeded();
  }

  /// Total byte dari header Content-Length (206 berarti sisa; tambah
  /// offset resume) atau Content-Range. Null bila tidak diketahui.
  int? _contentLength(
    Response<ResponseBody> response,
    bool resumed,
    int downloaded,
  ) {
    if (resumed) {
      final String? range = response.headers.value('content-range');
      if (range != null) {
        final List<String> parts = range.split('/');
        if (parts.length == 2) return int.tryParse(parts[1]);
      }
      final String? length = response.headers.value(HttpHeaders.contentLengthHeader);
      final int? remaining = length == null ? null : int.tryParse(length);
      return remaining == null ? null : remaining + downloaded;
    }
    final String? length = response.headers.value(HttpHeaders.contentLengthHeader);
    return length == null ? null : int.tryParse(length);
  }

  /// Eviction LRU: hapus entri paling lama tidak diakses sampai total
  /// di bawah batas. Tidak pernah menyentuh direktori unduhan (hanya
  /// file di direktori cache yang dihapus) dan tidak pernah menghapus
  /// lagu yang sedang diputar.
  Future<void> evictIfNeeded({Set<String>? excludeVideoIds}) async {
    final Set<String> excluded = <String>{...?excludeVideoIds};
    final String? protected = _protectedVideoId?.call();
    if (protected != null) excluded.add(protected);
    final StorageStats stats = await _library.storageStats();
    int total = stats.playedSongsBytes;
    if (total <= _cacheLimitBytes) return;
    final List<CacheEntry> entries = await _library.cacheEntriesByLru();
    for (final CacheEntry entry in entries) {
      if (total <= _cacheLimitBytes) break;
      // Kunci adalah `${videoId}_$itag`; videoId sendiri bisa berisi `_`
      // (mis. 'NL8WUtq_NDY'), jadi pisahkan di `_` TERAKHIR.
      final int cut = entry.key.lastIndexOf('_');
      final String entryVideoId = cut <= 0
          ? entry.key
          : entry.key.substring(0, cut);
      if (excluded.contains(entryVideoId)) continue;
      final File file = File('${_paths.cacheDir.path}/${entry.filePath}');
      try {
        if (file.existsSync()) file.deleteSync();
      } on FileSystemException {
        // File tidak bisa dihapus: lewati, entri tetap dihapus supaya
        // manifest tidak menumpuk entri mati.
      }
      await _library.deleteCacheEntry(entry.key);
      total -= entry.sizeBytes;
    }
  }

  /// Kosongkan seluruh cache streaming. Unduhan tidak ikut terhapus
  /// (direktori terpisah + manifest terpisah).
  Future<void> clearAll() async {
    final List<CacheEntry> entries = await _library.allCacheEntries();
    for (final CacheEntry entry in entries) {
      final File file = File('${_paths.cacheDir.path}/${entry.filePath}');
      try {
        if (file.existsSync()) file.deleteSync();
      } on FileSystemException {
        // Lanjut: entri tetap dihapus.
      }
    }
    await _library.deleteCacheEntries(
      entries.map((CacheEntry e) => e.key).toList(growable: false),
    );
    // Bersihkan juga file yatim (termasuk .part yang tertinggal).
    await _deleteOrphanFiles();
  }

  /// Rekonsiliasi cache: entri yang filenya hilang dihapus dari manifest,
  /// file yatim di direktori cache dihapus.
  Future<CacheReconcileResult> reconcile() async {
    int staleEntries = 0;
    final List<CacheEntry> entries = await _library.allCacheEntries();
    for (final CacheEntry entry in entries) {
      final File file = File('${_paths.cacheDir.path}/${entry.filePath}');
      bool ok = false;
      try {
        ok = await file.exists() &&
            await file.length() == entry.sizeBytes;
      } on FileSystemException {
        ok = false;
      }
      if (!ok) {
        await _library.deleteCacheEntry(entry.key);
        staleEntries++;
        try {
          if (file.existsSync()) file.deleteSync();
        } on FileSystemException {
          // Coba lagi di rekonsiliasi berikutnya.
        }
      }
    }
    final int orphans = await _deleteOrphanFiles();
    return CacheReconcileResult(
      staleEntriesDeleted: staleEntries,
      orphanFilesDeleted: orphans,
    );
  }

  /// Hapus file di direktori cache yang tidak punya entri manifest
  /// (termasuk `.part` dari fetch yang terputus). File fetch yang sedang
  /// berjalan tidak disentuh (kuncinya ada di [_fetchingKey]).
  Future<int> _deleteOrphanFiles() async {
    final List<CacheEntry> entries = await _library.allCacheEntries();
    final Set<String> known = entries
        .map((CacheEntry e) => e.filePath)
        .toSet();
    int deleted = 0;
    final List<FileSystemEntity> listed = _listCacheDir();
    for (final FileSystemEntity entity in listed) {
      if (entity is! File) continue;
      final String name = entity.path.split('/').last;
      if (known.contains(name)) continue;
      if (_fetchingKey != null && name.startsWith(_fetchingKey!)) continue;
      try {
        entity.deleteSync();
        deleted++;
      } on FileSystemException {
        // Lanjut ke file berikutnya.
      }
    }
    return deleted;
  }

  /// Isi direktori cache, atau daftar kosong bila tidak bisa dibaca.
  List<FileSystemEntity> _listCacheDir() {
    try {
      return _paths.cacheDir.listSync();
    } on FileSystemException {
      return <FileSystemEntity>[];
    }
  }

  @override
  Future<void> invalidate(String videoId) async {
    final List<CacheEntry> entries = await _library.cacheEntriesForVideo(
      videoId,
    );
    for (final CacheEntry entry in entries) {
      final File file = File('${_paths.cacheDir.path}/${entry.filePath}');
      try {
        if (file.existsSync()) file.deleteSync();
      } on FileSystemException {
        // Lanjut: entri tetap dihapus.
      }
      await _library.deleteCacheEntry(entry.key);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _pending.clear();
    _dio.close(force: true);
  }
}
