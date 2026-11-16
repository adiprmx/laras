/// Tes widget layar Penyimpanan: 4 state (loading/kosong/isi/error),
/// hapus cache, hapus semua unduhan, hapus per lagu.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/core/widgets/loading_rows.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/features/storage/storage_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

import '../../data/test_database.dart';

class _FakeFreeSpace implements FreeSpaceProvider {
  @override
  Future<int?> freeBytes(String path) async => 10 * 1024 * 1024 * 1024;
}

class _UnusedUrlSource implements DownloadUrlSource {
  @override
  Future<DownloadUrl> resolve(String videoId, DownloadQuality quality) {
    throw UnimplementedError('tes penyimpanan tidak mengunduh');
  }
}

void main() {
  late Directory temp;
  late DownloadPaths paths;
  late LarasDatabase db;
  late LibraryService library;
  late StreamCacheService cache;
  late DownloadService downloads;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('laras_storage_widget_test');
    final Directory downloadsDir = Directory('${temp.path}/downloads')
      ..createSync();
    final Directory cacheDir = Directory('${temp.path}/cache')..createSync();
    paths = DownloadPaths(downloadsDir: downloadsDir, cacheDir: cacheDir);
    (db, library) = createTestLibrary();
    cache = StreamCacheService(library: library, paths: paths);
    downloads = DownloadService(
      library: library,
      paths: paths,
      urlSource: _UnusedUrlSource(),
      freeSpace: _FakeFreeSpace(),
    );
  });

  tearDown(() async {
    await downloads.dispose();
    await cache.dispose();
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  // File ditulis SINKRON: badan tes widget berjalan di zona FakeAsync
  // dan `await file.writeAsBytes` (I/O nyata) tidak pernah kembali di
  // sana (terbukti menggantung selamanya, 16 Nov 2026). Operasi
  // database (drift, berbasis microtask) aman di-await di badan tes.
  Future<void> seedDownloadedSong(String songId, String title) async {
    await library.upsertSong(testSong(songId, title: title), addToLibrary: true);
    final File file = paths.downloadFile(songId, 'opus');
    file.writeAsBytesSync(List<int>.filled(500, 3));
    await library.markDownloaded(
      songId: songId,
      filePath: '$songId.opus',
      fileSizeBytes: 500,
    );
  }

  Future<void> seedCacheEntry(String videoId) async {
    final File file = paths.cacheFile(videoId, 251, 'opus');
    file.writeAsBytesSync(List<int>.filled(400, 7));
    final DateTime now = DateTime.now();
    await library.upsertCacheEntry(
      CacheEntriesCompanion.insert(
        key: DownloadPaths.cacheKey(videoId, 251),
        filePath: paths.cacheFileName(videoId, 251, 'opus'),
        sizeBytes: 400,
        lastAccessed: now,
        createdAt: now,
      ),
    );
  }

  AppLocalizations stringsOf(WidgetTester tester) {
    return AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
  }

  Future<void> pumpStorage(
    WidgetTester tester, {
    bool withServices = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[Locale('id')],
        home: LibraryScope(
          service: withServices ? library : null,
          child: DownloadsScope(
            downloads: withServices ? downloads : null,
            cache: withServices ? cache : null,
            child: const StorageScreen(),
          ),
        ),
      ),
    );
  }

  Future<void> closePump(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('loading lalu isi: skeleton dulu, lalu angka nyata', (WidgetTester tester) async {
    await seedDownloadedSong('ddd44444444', 'Lagu Terunduh');
    await seedCacheEntry('aaa11111111');

    await pumpStorage(tester);
    // Frame pertama: FutureBuilder masih menunggu.
    expect(find.byType(LoadingRows), findsOneWidget);

    await tester.pumpAndSettle();
    final AppLocalizations strings = stringsOf(tester);
    expect(find.byType(LoadingRows), findsNothing);
    expect(
      find.text(strings.downloadsSummary(1, '500 B')),
      findsOneWidget,
    );
    expect(find.text('400 B (Batas: 500,0 MB)'), findsOneWidget);
    expect(find.text('10,0 GB'), findsOneWidget);
    expect(find.text('Lagu Terunduh'), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('kosong: angka nol + tombol hapus nonaktif', (WidgetTester tester) async {
    await pumpStorage(tester);
    await tester.pumpAndSettle();

    final AppLocalizations strings = stringsOf(tester);
    expect(
      find.text(strings.downloadsSummary(0, '0 B')),
      findsOneWidget,
    );
    expect(find.text('0 B (Batas: 500,0 MB)'), findsOneWidget);
    expect(find.text(strings.downloadsEmptyTitle), findsOneWidget);
    final OutlinedButton clearButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, strings.clearPlayedSongsSpace),
    );
    expect(clearButton.onPressed, isNull);
    final OutlinedButton deleteAllButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, strings.dlDeleteAllDownloads),
    );
    expect(deleteAllButton.onPressed, isNull);
    await closePump(tester);
  });

  testWidgets('error: tanpa layanan, pesan jujur tampil', (WidgetTester tester) async {
    await pumpStorage(tester, withServices: false);
    await tester.pumpAndSettle();

    final AppLocalizations strings = stringsOf(tester);
    expect(find.text(strings.libraryFailed), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('kosongkan ruang lagu yang pernah diputar: cache hilang, unduhan utuh', (WidgetTester tester) async {
    await seedDownloadedSong('ddd44444444', 'Lagu Terunduh');
    await seedCacheEntry('aaa11111111');
    await pumpStorage(tester);
    await tester.pumpAndSettle();

    final AppLocalizations strings = stringsOf(tester);
    await tester.tap(find.text(strings.clearPlayedSongsSpace));
    await tester.pumpAndSettle();
    expect(find.text(strings.dlClearCacheTitle), findsOneWidget);
    await tester.tap(find.text(strings.delete));
    await tester.pumpAndSettle();

    expect(
      paths.cacheFile('aaa11111111', 251, 'opus').existsSync(),
      isFalse,
    );
    expect(await library.cacheEntry('aaa11111111_251'), isNull);
    // Unduhan tidak ikut terhapus.
    expect(
      paths.downloadFile('ddd44444444', 'opus').existsSync(),
      isTrue,
    );
    expect(find.text(strings.playedSongsSpaceCleared), findsOneWidget);
    // Angka cache kini nol.
    expect(find.text('0 B (Batas: 500,0 MB)'), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('hapus semua unduhan: file hilang, lagu tetap di Library', (WidgetTester tester) async {
    await seedDownloadedSong('ddd44444444', 'Lagu Terunduh');
    await pumpStorage(tester);
    await tester.pumpAndSettle();

    final AppLocalizations strings = stringsOf(tester);
    await tester.tap(find.text(strings.dlDeleteAllDownloads));
    await tester.pumpAndSettle();
    expect(find.text(strings.dlDeleteAllTitle), findsOneWidget);
    expect(
      find.text(strings.dlDeleteAllBody(1, '500 B')),
      findsOneWidget,
    );
    await tester.tap(find.text(strings.delete));
    await tester.pumpAndSettle();

    expect(
      paths.downloadFile('ddd44444444', 'opus').existsSync(),
      isFalse,
    );
    final SongView? view = await library.songById('ddd44444444');
    expect(view?.song.downloadState, DownloadState.notDownloaded);
    expect(find.text(strings.dlAllDownloadsDeleted), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('hapus unduhan per lagu: dialog konfirmasi lalu hilang', (WidgetTester tester) async {
    await seedDownloadedSong('ddd44444444', 'Lagu Terunduh');
    await pumpStorage(tester);
    await tester.pumpAndSettle();

    final AppLocalizations strings = stringsOf(tester);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text(strings.deleteDownloadTitle), findsOneWidget);
    await tester.tap(find.text(strings.delete));
    await tester.pumpAndSettle();

    expect(
      paths.downloadFile('ddd44444444', 'opus').existsSync(),
      isFalse,
    );
    expect(find.text('Lagu Terunduh'), findsNothing);
    await closePump(tester);
  });
}
