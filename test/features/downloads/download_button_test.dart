/// Tes widget DownloadButton: dialog pilih kualitas, enqueue, status
/// terunduh + dialog hapus, dan sembunyi saat layanan tidak tersedia.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/features/downloads/download_button.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/track.dart';

import '../../data/test_database.dart';

class _FakeFreeSpace implements FreeSpaceProvider {
  @override
  Future<int?> freeBytes(String path) async => 10 * 1024 * 1024 * 1024;
}

/// Resolve yang tidak pernah selesai: job bertahan "mengunduh" supaya
/// tombol menampilkan progress secara deterministik (URL mati akan
/// gagal cepat dan tombol kembali ke ikon unduh sebelum tes sempat
/// memeriksanya).
class _HangingUrlSource implements DownloadUrlSource {
  @override
  Future<DownloadUrl> resolve(String videoId, DownloadQuality quality) {
    return Completer<DownloadUrl>().future;
  }
}

void main() {
  late Directory temp;
  late DownloadPaths paths;
  late LarasDatabase db;
  late LibraryService library;
  late DownloadService downloads;

  const Track track = Track(
    videoId: 'aaa11111111',
    title: 'Lagu Uji',
    duration: Duration(seconds: 180),
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('laras_dl_button_test');
    final Directory downloadsDir = Directory('${temp.path}/downloads')
      ..createSync();
    final Directory cacheDir = Directory('${temp.path}/cache')..createSync();
    paths = DownloadPaths(downloadsDir: downloadsDir, cacheDir: cacheDir);
    (db, library) = createTestLibrary();
    downloads = DownloadService(
      library: library,
      paths: paths,
      urlSource: _HangingUrlSource(),
      freeSpace: _FakeFreeSpace(),
      backoffFor: (_) => Duration.zero,
    );
    // JANGAN panggil downloads.start() di sini: start() meluncurkan
    // future tak-tertunggu (_pump + _emitSnapshot) yang terikat zona
    // async nyata setUp; saat badan tes masuk FakeAsync, loop nyata
    // ditangguhkan, future itu tidak pernah selesai, dan karena drift
    // menyerikan semua operasi lewat satu Lock, SEMUA query drift di
    // badan tes menggantung selamanya (terbukti 16 Nov 2026).
    // start() dipanggil di badan tes lewat pumpButton.
  });

  tearDown(() async {
    await downloads.dispose();
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  AppLocalizations stringsOf(WidgetTester tester) {
    return AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
  }

  Future<void> pumpButton(
    WidgetTester tester, {
    bool withServices = true,
  }) async {
    // start() di badan tes (zona FakeAsync): future pompa/emit-nya
    // berjalan di zona yang sama dengan tes dan maju lewat pump.
    if (withServices) downloads.start();
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
            cache: null,
            child: const Scaffold(
              body: Center(child: DownloadButton(track: track)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> closePump(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('belum diunduh: dialog kualitas lalu enqueue + snackbar', (WidgetTester tester) async {
    await pumpButton(tester);

    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pumpAndSettle();

    final AppLocalizations strings = stringsOf(tester);
    expect(find.text(strings.dlDownloadQualityTitle), findsOneWidget);
    expect(find.textContaining(strings.qualityBest), findsOneWidget);
    expect(find.textContaining(strings.qualityBalanced), findsOneWidget);
    expect(find.textContaining(strings.qualityDataSaver), findsOneWidget);
    // Perkiraan Terbaik untuk 180 dtk: 160000 x 180 / 8 = 3.600.000 B
    // = 3,4 MB.
    expect(find.textContaining('3,4 MB'), findsOneWidget);

    await tester.tap(find.text(strings.download));
    // JANGAN pumpAndSettle di sini: sesudah enqueue, tombol menampilkan
    // CircularProgressIndicator tak tentu (total belum diketahui) yang
    // beranimasi selamanya dan membuat pumpAndSettle tidak pernah
    // selesai. Pompa frame manual sampai snackbar muncul.
    for (
      int i = 0;
      i < 30 && find.text(strings.dlQueued).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text(strings.dlQueued), findsOneWidget);
    final DownloadJob? job = await library.downloadJobBySongId('aaa11111111');
    expect(job, isNotNull);
    expect(job!.quality, 251);
    // Tombol kini menampilkan progress (lagu sedang diunduh).
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('terunduh: ikon selesai, ketuk membuka dialog hapus', (WidgetTester tester) async {
    await library.upsertSong(
      testSong('aaa11111111', title: 'Lagu Uji'),
      addToLibrary: true,
    );
    final File file = paths.downloadFile('aaa11111111', 'opus');
    file.writeAsBytesSync(List<int>.filled(500, 3));
    await library.markDownloaded(
      songId: 'aaa11111111',
      filePath: 'aaa11111111.opus',
      fileSizeBytes: 500,
    );
    await pumpButton(tester);

    expect(find.byIcon(Icons.download_done), findsOneWidget);
    await tester.tap(find.byIcon(Icons.download_done));
    await tester.pumpAndSettle();

    final AppLocalizations strings = stringsOf(tester);
    expect(find.text(strings.deleteDownloadTitle), findsOneWidget);
    await tester.tap(find.text(strings.delete));
    await tester.pumpAndSettle();

    expect(file.existsSync(), isFalse);
    final SongView? view = await library.songById('aaa11111111');
    expect(view?.song.downloadState, DownloadState.notDownloaded);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('tanpa layanan: tombol sembunyi total', (WidgetTester tester) async {
    await pumpButton(tester, withServices: false);

    expect(find.byIcon(Icons.download_outlined), findsNothing);
    expect(find.byIcon(Icons.download_done), findsNothing);
    await closePump(tester);
  });
}
