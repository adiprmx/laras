/// Rekonsiliasi saat start (PRD B3.3): sinkronkan database dengan file
/// yang benar-benar ada di disk.
///
/// Jalan di latar saat start dingin, tanpa memblokir layar utama.
/// Idempotent: dijalankan dua kali berturut-turut, hasil kedua
/// menemukan tidak ada lagi yang perlu diperbaiki.
///
/// Yang dilakukan (berurutan):
/// 1. Job berstatus "mengunduh" kembali ke antrean (app mati di tengah
///    unduhan; `.part`-nya masih ada dan bisa di-resume).
/// 2. Job selesai lebih dari 7 hari dihapus dari riwayat (lagu tetap
///    di Library, PRD B3.2).
/// 3. Lagu bertanda terunduh yang filenya hilang atau ukurannya tidak
///    cocok diturunkan statusnya ke belum diunduh (lagu tetap di
///    Library; file rusak dihapus). Jumlahnya dilaporkan untuk snackbar.
/// 4. File `.part` tanpa job aktif dihapus.
/// 5. File final di direktori unduhan tanpa baris lagu terunduh
///    (file yatim) dihapus.
/// 6. Cache direkonsiliasi lewat [StreamCacheService.reconcile].
///
/// Penghapusan file memakai API SINKRON (`deleteSync`/`existsSync`):
/// hapus file adalah operasi metadata sub-detik, dan API async-nya tidak
/// pernah kembali bila dipanggil dari handler widget di tes widget (zona
/// FakeAsync — terbukti menggantung, 16 Nov 2026).
///
/// Tanpa pemeriksaan hash file di v1 (PRD: ukuran cocok cukup untuk
/// file yang ditulis app sendiri).
library;

import 'dart:io';

import 'package:laras/data/database.dart';

import 'download_paths.dart';
import 'stream_cache.dart';

/// Hasil satu putaran rekonsiliasi.
class ReconcileResult {
  const ReconcileResult({
    required this.missingDownloads,
    required this.orphanPartsDeleted,
    required this.orphanDownloadsDeleted,
    required this.jobsResetToQueued,
    required this.completedJobsPruned,
    required this.staleCacheEntriesDeleted,
    required this.orphanCacheFilesDeleted,
  });

  const ReconcileResult.empty()
    : missingDownloads = 0,
      orphanPartsDeleted = 0,
      orphanDownloadsDeleted = 0,
      jobsResetToQueued = 0,
      completedJobsPruned = 0,
      staleCacheEntriesDeleted = 0,
      orphanCacheFilesDeleted = 0;

  /// File unduhan yang hilang/rusak (status lagu diperbaiki).
  final int missingDownloads;

  /// File `.part` tanpa job yang dihapus.
  final int orphanPartsDeleted;

  /// File final yatim di direktori unduhan yang dihapus.
  final int orphanDownloadsDeleted;

  /// Job "mengunduh" yang dikembalikan ke antrean.
  final int jobsResetToQueued;

  /// Job selesai lebih dari 7 hari yang dihapus dari riwayat.
  final int completedJobsPruned;

  /// Entri cache yang filenya sudah tidak ada.
  final int staleCacheEntriesDeleted;

  /// File yatim di direktori cache yang dihapus.
  final int orphanCacheFilesDeleted;

  /// Benar bila tidak ada yang perlu diperbaiki.
  bool get isClean =>
      missingDownloads == 0 &&
      orphanPartsDeleted == 0 &&
      orphanDownloadsDeleted == 0 &&
      jobsResetToQueued == 0 &&
      completedJobsPruned == 0 &&
      staleCacheEntriesDeleted == 0 &&
      orphanCacheFilesDeleted == 0;
}

/// Jalankan rekonsiliasi penuh.
Future<ReconcileResult> reconcileDownloads({
  required LibraryService library,
  required DownloadPaths paths,
  required StreamCacheService cache,
}) async {
  final int jobsReset = await library.resetRunningJobsToQueued();
  final int pruned = await library.pruneCompletedJobs();

  // Lagu terunduh: file harus ada dan ukurannya cocok.
  int missing = 0;
  final List<DownloadedFileInfo> files = await library.downloadedFiles();
  final Set<String> knownNames = <String>{};
  for (final DownloadedFileInfo info in files) {
    final String? relative = info.filePath;
    if (relative == null) {
      await library.clearDownloadState(info.songId);
      missing++;
      continue;
    }
    knownNames.add(relative);
    final File? file = paths.downloadFileFromRelative(relative);
    bool ok = false;
    if (file != null) {
      try {
        ok = await file.exists() &&
            await file.length() == info.fileSizeBytes;
      } on FileSystemException {
        ok = false;
      }
    }
    if (!ok) {
      // File rusak (ada tapi ukuran tidak cocok) dihapus supaya tidak
      // dikira unduhan utuh oleh pemutar.
      if (file != null) {
        try {
          if (file.existsSync()) file.deleteSync();
        } on FileSystemException {
          // Coba lagi di rekonsiliasi berikutnya.
        }
      }
      await library.clearDownloadState(info.songId);
      missing++;
    }
  }

  // File .part dan file final yatim di direktori unduhan.
  final List<DownloadJob> jobs = await library.downloadJobs();
  final Set<String> activeSongIds = jobs
      .where(
        (DownloadJob j) =>
            j.status == DownloadJobStatus.queued ||
            j.status == DownloadJobStatus.running ||
            j.status == DownloadJobStatus.paused,
      )
      .map((DownloadJob j) => j.songId)
      .toSet();
  int orphanParts = 0;
  int orphanFinals = 0;
  late List<FileSystemEntity> listed;
  try {
    listed = paths.downloadsDir.listSync();
  } on FileSystemException {
    listed = <FileSystemEntity>[];
  }
  for (final FileSystemEntity entity in listed) {
    if (entity is! File) continue;
    final String name = entity.path.split('/').last;
    if (name.endsWith('.part')) {
      final String base = name.substring(0, name.length - 5);
      final String songId = base.split('.').first;
      if (!activeSongIds.contains(songId)) {
        try {
          entity.deleteSync();
          orphanParts++;
        } on FileSystemException {
          // Coba lagi di rekonsiliasi berikutnya.
        }
      }
      continue;
    }
    if (!knownNames.contains(name)) {
      try {
        entity.deleteSync();
        orphanFinals++;
      } on FileSystemException {
        // Coba lagi di rekonsiliasi berikutnya.
      }
    }
  }

  final CacheReconcileResult cacheResult = await cache.reconcile();
  return ReconcileResult(
    missingDownloads: missing,
    orphanPartsDeleted: orphanParts,
    orphanDownloadsDeleted: orphanFinals,
    jobsResetToQueued: jobsReset,
    completedJobsPruned: pruned,
    staleCacheEntriesDeleted: cacheResult.staleEntriesDeleted,
    orphanCacheFilesDeleted: cacheResult.orphanFilesDeleted,
  );
}
