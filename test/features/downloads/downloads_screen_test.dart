/// Tes widget tab Unduhan: 4 state (loading/kosong/isi/error), putar
/// lagu terunduh, dan alur hapus unduhan. Database in-memory nyata +
/// DownloadService nyata (server lokal).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/core/widgets/loading_rows.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/features/onboarding/onboarding_flow.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/main.dart';
import 'package:laras/player/player.dart';
import 'package:laras/resilience/honesty_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/test_database.dart';
import '../../player/fakes.dart';

/// Sumber URL palsu: mengarah ke server lokal, ukuran tetap.
class _FakeUrlSource implements DownloadUrlSource {
  _FakeUrlSource(this.baseUrl);

  final String baseUrl;

  @override
  Future<DownloadUrl> resolve(String videoId, DownloadQuality quality) async {
    return DownloadUrl(
      url: '$baseUrl/audio',
      itag: quality.primaryItag,
      mimeType: 'audio/webm; codecs="opus"',
      bitrate: 160000,
      clientName: 'test',
      contentLength: 1000,
    );
  }
}

/// Sisa ruang palsu (10 GB).
class _FakeFreeSpace implements FreeSpaceProvider {
  @override
  Future<int?> freeBytes(String path) async => 10 * 1024 * 1024 * 1024;
}

/// Server yang mengirim header (200 + Content-Length) lalu tidak
/// pernah mengirim body dalam waktu tes: job yang memakainya bertahan
/// di status "mengunduh" dengan total yang diketahui (untuk menguji
/// kelompok Mengunduh/Menunggu tanpa unduhan yang selesai mendadak).
///
/// Header dikirim segera supaya progress terhitung (0,0, bukan null):
/// progress null membuat LinearProgressIndicator tak tentu yang
/// beranimasi selamanya dan `pumpAndSettle()` tidak pernah selesai.
class _HangingServer {
  HttpServer? _server;

  Future<Uri> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((HttpRequest request) async {
      try {
        // bufferOutput=false: header harus sampai ke klien segera
        // (tanpa ini HttpResponse menahan sampai close — lihat catatan
        // di _TestServer download_service_test.dart).
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.set(HttpHeaders.contentLengthHeader, 1000)
          ..bufferOutput = false;
        await request.response.flush();
        await Future<void>.delayed(const Duration(minutes: 5));
        request.response
          ..add(List<int>.filled(1000, 1))
          ..close();
      } on Object catch (_) {}
    });
    return Uri.parse('http://127.0.0.1:${_server!.port}');
  }

  Future<void> stop() async => _server?.close(force: true);
}

void main() {
  late Directory temp;
  late DownloadPaths paths;
  late LarasDatabase db;
  late LibraryService library;
  late FakeAudioPlayerPort port;
  late PlayerService playerService;
  late StreamCacheService cache;
  late DownloadService downloads;
  late _HangingServer server;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('laras_dl_widget_test');
    final Directory downloadsDir = Directory('${temp.path}/downloads')
      ..createSync();
    final Directory cacheDir = Directory('${temp.path}/cache')..createSync();
    paths = DownloadPaths(downloadsDir: downloadsDir, cacheDir: cacheDir);
    (db, library) = createTestLibrary();
    port = FakeAudioPlayerPort();
    playerService = PlayerService(
      port: port,
      resolver: FakeAudioResolver(),
      solver: FakeSignatureSolver(),
    );
    cache = StreamCacheService(library: library, paths: paths);
    // Server + layanan dibuat di setUp (zona async nyata): HttpServer.bind
    // adalah I/O nyata yang menggantung bila dipanggil di badan tes widget
    // (zona FakeAsync — terbukti 16 Nov 2026). Layanan TIDAK di-start di
    // sini: tes yang butuh memanggil downloads.start() sendiri (sinkron,
    // aman di badan tes); tes loading sengaja tidak memanggilnya.
    server = _HangingServer();
    final Uri base = await server.start();
    downloads = DownloadService(
      library: library,
      paths: paths,
      urlSource: _FakeUrlSource(base.toString()),
      freeSpace: _FakeFreeSpace(),
      backoffFor: (_) => Duration.zero,
      // Server tes adalah HTTP lokal (127.0.0.1): validator allowlist
      // produksi (R2-M1) dilonggarkan di sini.
      urlValidator: (_) => true,
    );
  });

  tearDown(() async {
    await server.stop();
    await downloads.dispose();
    await cache.dispose();
    await db.close();
    await port.dispose();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

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

  AppLocalizations stringsOf(WidgetTester tester) {
    return AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    bool withLibrary = true,
    bool withDownloads = true,
    bool failed = false,
  }) async {
    // Matikan urutan first-run (diuji di first_run_test.dart).
    SharedPreferences.setMockInitialValues(<String, Object>{
      kOnboardingShownKey: true,
      kHonestySheetShownKey: true,
    });
    await tester.pumpWidget(
      LarasApp(
        playerService: playerService,
        libraryService: withLibrary ? library : null,
        libraryFailed: failed,
        downloadService: withDownloads ? downloads : null,
        streamCache: withDownloads ? cache : null,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDownloadsTab(WidgetTester tester) async {
    final AppLocalizations strings = stringsOf(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(strings.tabDownloads),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> closePump(WidgetTester tester) async {
    // Pelajaran P3: tutup pump widget yang memakai watch* supaya tidak
    // ada Timer drift yang menggantung sesudah tes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('kosong: judul + isi empty state tampil', (WidgetTester tester) async {
    downloads.start();
    await pumpApp(tester);
    await openDownloadsTab(tester);

    final AppLocalizations strings = stringsOf(tester);
    expect(find.text(strings.downloadsEmptyTitle), findsOneWidget);
    expect(find.text(strings.downloadsEmptyBody), findsOneWidget);
    expect(find.text(strings.tabDownloads), findsWidgets);
    await closePump(tester);
  });

  testWidgets('loading: skeleton tampil sebelum snapshot pertama tiba', (WidgetTester tester) async {
    // Layanan dibuat di setUp TANPA start(): tidak ada snapshot yang dikirim.
    // Matikan urutan first-run (diuji di first_run_test.dart).
    SharedPreferences.setMockInitialValues(<String, Object>{
      kOnboardingShownKey: true,
      kHonestySheetShownKey: true,
    });
    await tester.pumpWidget(
      LarasApp(
        playerService: playerService,
        libraryService: library,
        downloadService: downloads,
        streamCache: cache,
      ),
    );
    await tester.pump();
    await openDownloadsTab(tester);

    // StreamBuilder belum punya data: skeleton, bukan empty state.
    expect(find.byType(LoadingRows), findsOneWidget);
    final AppLocalizations strings = stringsOf(tester);
    expect(find.text(strings.downloadsEmptyTitle), findsNothing);
    await closePump(tester);
  });

  testWidgets('error: tanpa database, pesan jujur tampil', (WidgetTester tester) async {
    await pumpApp(tester, withLibrary: false, withDownloads: false, failed: true);
    await openDownloadsTab(tester);

    final AppLocalizations strings = stringsOf(tester);
    expect(find.text(strings.libraryFailed), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('isi: kelompok Mengunduh/Menunggu/Selesai tampil', (WidgetTester tester) async {
    // Seed SEBELUM start(): snapshot pertama start() harus sudah
    // memuat lagu terunduh (seed langsung ke DB tidak memicu emisi
    // snapshot baru).
    await seedDownloadedSong('ddd44444444', 'Lagu Terunduh');
    downloads.start();
    // B mengunduh (server menggantung), C menunggu di belakang B.
    await downloads.enqueue(
      const Track(
        videoId: 'aaa11111111',
        title: 'Lagu Mengunduh',
        duration: Duration(seconds: 180),
      ),
    );
    await downloads.enqueue(
      const Track(
        videoId: 'bbb22222222',
        title: 'Lagu Menunggu',
        duration: Duration(seconds: 180),
      ),
    );
    await pumpApp(tester);
    await openDownloadsTab(tester);

    final AppLocalizations strings = stringsOf(tester);
    expect(find.text(strings.dlDownloading), findsOneWidget);
    expect(find.text(strings.dlWaiting), findsOneWidget);
    expect(find.text(strings.dlDone), findsOneWidget);
    expect(find.text('Lagu Mengunduh'), findsOneWidget);
    expect(find.text('Lagu Menunggu'), findsOneWidget);
    expect(find.text('Lagu Terunduh'), findsOneWidget);
    // Ringkasan: 1 lagu terunduh, 500 B.
    expect(
      find.text(strings.downloadsSummary(1, '500 B')),
      findsOneWidget,
    );
    await closePump(tester);
  });

  testWidgets('ketuk lagu terunduh memutar dari file lokal', (WidgetTester tester) async {
    // Seed sebelum start() (alasan sama dengan tes "isi").
    await seedDownloadedSong('ddd44444444', 'Lagu Terunduh');
    downloads.start();
    await pumpApp(tester);
    await openDownloadsTab(tester);

    await tester.tap(find.text('Lagu Terunduh'));
    await tester.pumpAndSettle();

    expect(port.setQueueCalls, hasLength(1));
    final (List<Track>, int, bool) call = port.setQueueCalls.single;
    expect(call.$2, 0);
    expect(call.$3, isTrue);
    expect(call.$1.single.videoId, 'ddd44444444');
    expect(call.$1.single.isLocal, isTrue);
    expect(
      call.$1.single.localPath,
      endsWith('ddd44444444.opus'),
    );
    await closePump(tester);
  });

  testWidgets('hapus unduhan lewat menu: dialog konfirmasi lalu file hilang', (WidgetTester tester) async {
    // Seed sebelum start() (alasan sama dengan tes "isi").
    await seedDownloadedSong('ddd44444444', 'Lagu Terunduh');
    downloads.start();
    await pumpApp(tester);
    await openDownloadsTab(tester);

    final AppLocalizations strings = stringsOf(tester);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.dlRemoveDownload));
    await tester.pumpAndSettle();
    // Dialog konfirmasi menyebut judul lagu.
    expect(find.text(strings.deleteDownloadTitle), findsOneWidget);
    expect(
      find.text(strings.dlDeleteDownloadBody('Lagu Terunduh')),
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
    // Daftar kini kosong.
    expect(find.text(strings.downloadsEmptyTitle), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('tombol Kelola penyimpanan membuka layar Penyimpanan', (WidgetTester tester) async {
    downloads.start();
    await pumpApp(tester);
    await openDownloadsTab(tester);

    final AppLocalizations strings = stringsOf(tester);
    await tester.tap(find.text(strings.manageStorage));
    await tester.pumpAndSettle();

    expect(find.text(strings.dlStorageTitle), findsOneWidget);
    await closePump(tester);
  });
}
