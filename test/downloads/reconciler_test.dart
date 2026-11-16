import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';

import '../data/test_database.dart';

void main() {
  late Directory temp;
  late DownloadPaths paths;
  late LarasDatabase db;
  late LibraryService library;
  late StreamCacheService cache;

  Future<void> seedDownloadedSong(
    String songId, {
    int size = 500,
    bool writeFile = true,
  }) async {
    await library.upsertSong(testSong(songId), addToLibrary: true);
    if (writeFile) {
      final File file = paths.downloadFile(songId, 'opus');
      await file.writeAsBytes(List<int>.filled(size, 3));
    }
    await library.markDownloaded(
      songId: songId,
      filePath: '$songId.opus',
      fileSizeBytes: size,
    );
  }

  Future<void> seedJob(
    String songId, {
    required int status,
    DateTime? updatedAt,
  }) async {
    await library.upsertDownloadJob(
      DownloadJobsCompanion.insert(
        songId: songId,
        status: status,
        updatedAt: updatedAt ?? DateTime.now(),
      ),
    );
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('laras_reconcile_test');
    final Directory downloads = Directory('${temp.path}/downloads')
      ..createSync();
    final Directory cacheDir = Directory('${temp.path}/cache')..createSync();
    paths = DownloadPaths(downloadsDir: downloads, cacheDir: cacheDir);
    (db, library) = createTestLibrary();
    cache = StreamCacheService(library: library, paths: paths);
  });

  tearDown(() async {
    await cache.dispose();
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<ReconcileResult> run() {
    return reconcileDownloads(library: library, paths: paths, cache: cache);
  }

  test('keadaan bersih: tidak ada yang diperbaiki', () async {
    final ReconcileResult result = await run();
    expect(result.isClean, isTrue);
    expect(result.missingDownloads, 0);
    expect(result.jobsResetToQueued, 0);
  });

  test('job mengunduh kembali ke antrean', () async {
    await library.upsertSong(testSong('aaa11111111'), addToLibrary: true);
    await seedJob('aaa11111111', status: DownloadJobStatus.running);

    final ReconcileResult result = await run();

    expect(result.jobsResetToQueued, 1);
    final DownloadJob? job = await library.downloadJobBySongId('aaa11111111');
    expect(job?.status, DownloadJobStatus.queued);
  });

  test('job selesai lebih dari 7 hari dihapus, yang baru dipertahankan', () async {
    await library.upsertSong(testSong('aaa11111111'), addToLibrary: true);
    await library.upsertSong(testSong('bbb22222222'), addToLibrary: true);
    await seedJob(
      'aaa11111111',
      status: DownloadJobStatus.completed,
      updatedAt: DateTime.now().subtract(const Duration(days: 8)),
    );
    await seedJob(
      'bbb22222222',
      status: DownloadJobStatus.completed,
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    final ReconcileResult result = await run();

    expect(result.completedJobsPruned, 1);
    expect(await library.downloadJobBySongId('aaa11111111'), isNull);
    expect(
      await library.downloadJobBySongId('bbb22222222'),
      isNotNull,
    );
  });

  test('file unduhan hilang: status lagu diperbaiki, dihitung', () async {
    await seedDownloadedSong('aaa11111111', writeFile: false);

    final ReconcileResult result = await run();

    expect(result.missingDownloads, 1);
    final SongView? view = await library.songById('aaa11111111');
    expect(view?.song.downloadState, DownloadState.notDownloaded);
    expect(view?.song.filePath, isNull);
    // Lagu tetap di Library.
    expect(view?.song.inLibrary, isTrue);
  });

  test('file unduhan ukurannya tidak cocok: file dihapus, status diperbaiki', () async {
    await library.upsertSong(testSong('aaa11111111'), addToLibrary: true);
    final File file = paths.downloadFile('aaa11111111', 'opus');
    await file.writeAsBytes(List<int>.filled(100, 3));
    await library.markDownloaded(
      songId: 'aaa11111111',
      filePath: 'aaa11111111.opus',
      fileSizeBytes: 500,
    );

    final ReconcileResult result = await run();

    expect(result.missingDownloads, 1);
    expect(await file.exists(), isFalse);
    final SongView? view = await library.songById('aaa11111111');
    expect(view?.song.downloadState, DownloadState.notDownloaded);
  });

  test('file .part tanpa job aktif dihapus, .part job aktif dipertahankan', () async {
    final File orphanPart = paths.downloadPartFile('zzz99999999', 'opus');
    await orphanPart.writeAsBytes(List<int>.filled(50, 1));
    await library.upsertSong(testSong('aaa11111111'), addToLibrary: true);
    await seedJob('aaa11111111', status: DownloadJobStatus.queued);
    final File activePart = paths.downloadPartFile('aaa11111111', 'opus');
    await activePart.writeAsBytes(List<int>.filled(50, 1));

    final ReconcileResult result = await run();

    expect(result.orphanPartsDeleted, 1);
    expect(await orphanPart.exists(), isFalse);
    expect(await activePart.exists(), isTrue);
  });

  test('file final yatim dihapus, file unduhan sah dipertahankan', () async {
    await seedDownloadedSong('aaa11111111');
    final File orphan = paths.downloadFile('zzz99999999', 'opus');
    await orphan.writeAsBytes(List<int>.filled(50, 1));

    final ReconcileResult result = await run();

    expect(result.orphanDownloadsDeleted, 1);
    expect(await orphan.exists(), isFalse);
    expect(
      await paths.downloadFile('aaa11111111', 'opus').exists(),
      isTrue,
    );
  });

  test('cache: entri basi + file yatim dibersihkan', () async {
    final DateTime now = DateTime.now();
    await library.upsertCacheEntry(
      CacheEntriesCompanion.insert(
        key: 'aaa11111111_251',
        filePath: 'aaa11111111_251.opus',
        sizeBytes: 400,
        lastAccessed: now,
        createdAt: now,
      ),
    );
    final File orphanCache = File('${paths.cacheDir.path}/orphan_251.opus');
    await orphanCache.writeAsBytes(List<int>.filled(10, 1));

    final ReconcileResult result = await run();

    expect(result.staleCacheEntriesDeleted, 1);
    expect(result.orphanCacheFilesDeleted, 1);
    expect(await library.cacheEntry('aaa11111111_251'), isNull);
    expect(await orphanCache.exists(), isFalse);
  });

  test('idempotent: putaran kedua bersih', () async {
    await seedDownloadedSong('aaa11111111', writeFile: false);
    await library.upsertSong(testSong('bbb22222222'), addToLibrary: true);
    await seedJob('bbb22222222', status: DownloadJobStatus.running);
    final File orphan = paths.downloadFile('zzz99999999', 'opus');
    await orphan.writeAsBytes(List<int>.filled(50, 1));

    final ReconcileResult first = await run();
    expect(first.isClean, isFalse);
    expect(first.missingDownloads, 1);
    expect(first.jobsResetToQueued, 1);
    expect(first.orphanDownloadsDeleted, 1);

    final ReconcileResult second = await run();
    expect(second.isClean, isTrue);
  });
}
