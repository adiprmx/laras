/// Tes permukaan beranda (K-F2-08 + K-F2-09):
/// 5 lagu langsung terlihat dengan sampul + tombol putar, tanpa ketukan
/// tambahan; mengetuk lagu memutar lewat port; seksi library muncul bila
/// ada lagu; status tekan (skala) bekerja di tombol putar.
library;

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/home/home_screen.dart';
import 'package:laras/features/library/song_row.dart';
import 'package:laras/features/search/search_service.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/main.dart';
import 'package:laras/player/player.dart';

import '../../data/test_database.dart';
import '../../player/fakes.dart';
import '../search/fake_online_api.dart';

const BrowsePage homeExplorePage = BrowsePage(
  title: '',
  shelves: <BrowseShelf>[
    BrowseShelf(
      title: "Today's biggest hits",
      items: <BrowseItem>[
        BrowseItem(
          kind: BrowseItemKind.playlist,
          title: 'Hit Hari Ini',
          subtitle: 'Playlist • YouTube Music',
          browseId: 'VLRDtest1',
        ),
        BrowseItem(
          kind: BrowseItemKind.playlist,
          title: 'Top 50 Indonesia',
          subtitle: 'Playlist • YouTube Music',
          browseId: 'VLRDtest2',
        ),
      ],
    ),
  ],
);

void main() {
  late FakeAudioPlayerPort port;
  late PlayerService playerService;

  setUp(() {
    port = FakeAudioPlayerPort();
    playerService = PlayerService(
      port: port,
      resolver: FakeAudioResolver(),
      solver: FakeSignatureSolver(),
    );
  });

  tearDown(() async {
    await port.dispose();
  });

  /// Viewport HP 390x1600 supaya semua 5 lagu muat tanpa scroll.
  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    LibraryService? libraryService,
    SearchService? searchService,
  }) async {
    await tester.pumpWidget(
      LarasApp(
        playerService: playerService,
        libraryService: libraryService,
        searchService: searchService,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('beranda menampilkan 5 lagu dengan tombol putar, tanpa '
      'ketukan tambahan', (WidgetTester tester) async {
    setPhoneViewport(tester);
    await pumpHome(tester);

    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.homeSongsTitle), findsOneWidget);
    expect(find.text(strings.homeSongsHint), findsOneWidget);

    // Kelima lagu terlihat langsung (judul + durasi), tanpa empty state.
    for (final Track track in homeTracks) {
      expect(find.text(track.title), findsOneWidget);
    }
    expect(find.text(strings.homeEmptyTitle), findsNothing);
    // Tidak ada lagi tombol/jargon demo spike di permukaan.
    expect(find.textContaining('spike', findRichText: true), findsNothing);
    expect(find.textContaining('demo', findRichText: true), findsNothing);

    // 6 tombol putar bulat: 1 kepala seksi + 5 per lagu.
    expect(find.byType(RoundPlayButton), findsNWidgets(6));
  });

  testWidgets('sampul album tampil dari thumbnail videoId', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await pumpHome(tester);

    final Finder covers = find.byType(CachedNetworkImage);
    expect(covers, findsNWidgets(5));
    final List<String> urls = tester
        .widgetList<CachedNetworkImage>(covers)
        .map((CachedNetworkImage w) => w.imageUrl)
        .toList(growable: false);
    for (final Track track in homeTracks) {
      expect(
        urls,
        contains('https://i.ytimg.com/vi/${track.videoId}/hqdefault.jpg'),
      );
    }
  });

  testWidgets('mengetuk lagu memutar antrean 5 lagu dari lagu itu', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await pumpHome(tester);

    // Ketuk judul lagu ketiga (indeks 2).
    await tester.tap(find.text(homeTracks[2].title));
    await tester.pump();
    expect(port.setQueueCalls, hasLength(1));
    final (List<Track>, int, bool) call = port.setQueueCalls.single;
    expect(call.$1.map((Track t) => t.videoId), <String>[
      for (final Track t in homeTracks) t.videoId,
    ]);
    expect(call.$2, 2);
    expect(call.$3, isTrue); // autoplay
  });

  testWidgets('tombol putar kepala seksi memutar dari lagu pertama', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await pumpHome(tester);

    await tester.tap(find.byType(RoundPlayButton).first);
    await tester.pump();
    expect(port.setQueueCalls, hasLength(1));
    expect(port.setQueueCalls.single.$2, 0);
    expect(port.setQueueCalls.single.$3, isTrue);
  });

  testWidgets('tombol putar mengecil saat ditekan (status tekan)', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await pumpHome(tester);

    final Finder button = find.byType(RoundPlayButton).first;
    final Finder scale = find.descendant(
      of: button,
      matching: find.byType(AnimatedScale),
    );
    expect(tester.widget<AnimatedScale>(scale).scale, 1.0);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(button),
    );
    // onTapDown tertunda kPressTimeout (100 ms) karena tombol berada di
    // dalam scrollable yang bersaing di arena gesture (efek
    // AlwaysScrollableScrollPhysics untuk pull-to-refresh): pump 150 ms
    // supaya status tekan terdaftar.
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<AnimatedScale>(scale).scale, lessThan(1.0));

    await gesture.up();
    await tester.pump();
    expect(tester.widget<AnimatedScale>(scale).scale, 1.0);
  });

  testWidgets('seksi Baru Ditambahkan muncul bila library berisi lagu', (
    WidgetTester tester,
  ) async {
    final (LarasDatabase db, LibraryService library) = createTestLibrary();
    addTearDown(db.close);
    await library.upsertSong(
      testSong('lib1', title: 'Lagu Library A'),
      artistNames: const <String>['Artis A'],
      addToLibrary: true,
    );
    await library.upsertSong(
      testSong('lib2', title: 'Lagu Library B'),
      artistNames: const <String>['Artis B'],
      addToLibrary: true,
    );

    setPhoneViewport(tester);
    await pumpHome(tester, libraryService: library);

    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.homeLibraryTitle), findsOneWidget);
    expect(find.text('Lagu Library A'), findsOneWidget);
    expect(find.text('Lagu Library B'), findsOneWidget);
  });

  testWidgets('seksi library sembunyi bila library kosong', (
    WidgetTester tester,
  ) async {
    final (LarasDatabase db, LibraryService library) = createTestLibrary();
    addTearDown(db.close);

    setPhoneViewport(tester);
    await pumpHome(tester, libraryService: library);

    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.homeLibraryTitle), findsNothing);
  });

  testWidgets('seksi Baru diputar muncul dari riwayat putar', (
    WidgetTester tester,
  ) async {
    final (LarasDatabase db, LibraryService library) = createTestLibrary();
    addTearDown(db.close);
    await library.upsertSong(
      testSong('lib1', title: 'Lagu Diputar A'),
      addToLibrary: true,
    );
    await library.upsertSong(
      testSong('lib2', title: 'Lagu Diputar B'),
      addToLibrary: true,
    );
    await library.recordPlay(
      songId: 'lib1',
      timestamp: DateTime(2026, 11, 16, 10, 0, 1),
      playTimeMs: 60000,
    );
    await library.recordPlay(
      songId: 'lib2',
      timestamp: DateTime(2026, 11, 16, 10, 0, 2),
      playTimeMs: 60000,
    );

    setPhoneViewport(tester);
    await pumpHome(tester, libraryService: library);

    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.sectionRecent), findsOneWidget);
    // Tiap lagu tampil di dua seksi (Baru Ditambahkan + Baru diputar).
    expect(find.text('Lagu Diputar A'), findsNWidgets(2));
    expect(find.text('Lagu Diputar B'), findsNWidgets(2));
  });

  testWidgets('seksi Favorit muncul bila ada lagu yang ditandai hati', (
    WidgetTester tester,
  ) async {
    final (LarasDatabase db, LibraryService library) = createTestLibrary();
    addTearDown(db.close);
    await library.upsertSong(
      testSong('lib1', title: 'Lagu Favorit'),
      addToLibrary: true,
    );
    await library.upsertSong(
      testSong('lib2', title: 'Lagu Biasa'),
      addToLibrary: true,
    );
    await library.toggleLiked('lib1');

    setPhoneViewport(tester);
    await pumpHome(tester, libraryService: library);

    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.favorites), findsOneWidget);
    // 'Lagu Favorit' tampil di dua seksi (Baru Ditambahkan + Favorit),
    // 'Lagu Biasa' hanya di Baru Ditambahkan.
    expect(find.text('Lagu Favorit'), findsNWidgets(2));
    expect(find.text('Lagu Biasa'), findsOneWidget);
  });

  testWidgets('seksi Playlist kamu muncul dan bisa dibuka', (
    WidgetTester tester,
  ) async {
    final (LarasDatabase db, LibraryService library) = createTestLibrary();
    addTearDown(db.close);
    await library.createPlaylist('Playlist Santai');
    await library.upsertSong(
      testSong('lib1', title: 'Lagu Di Playlist'),
      addToLibrary: true,
    );

    setPhoneViewport(tester);
    await pumpHome(tester, libraryService: library);

    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.sectionYourPlaylists), findsOneWidget);
    expect(find.text('Playlist Santai'), findsOneWidget);
    await tester.ensureVisible(find.text('Playlist Santai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playlist Santai'));
    await tester.pumpAndSettle();
    // Layar detail playlist terbuka (judul playlist di AppBar).
    expect(find.text('Playlist Santai'), findsWidgets);
  });

  testWidgets('seksi Jelajah menampilkan rak dari internet', (
    WidgetTester tester,
  ) async {
    final (LarasDatabase db, LibraryService library) = createTestLibrary();
    addTearDown(db.close);
    final FakeOnlineApi api = FakeOnlineApi(browsePage: homeExplorePage);
    final SearchService searchService = SearchService(
      api: api,
      library: library,
    );

    setPhoneViewport(tester);
    await pumpHome(
      tester,
      libraryService: library,
      searchService: searchService,
    );

    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.sectionExplore), findsOneWidget);
    expect(find.text("Today's biggest hits"), findsOneWidget);
    expect(find.text('Hit Hari Ini'), findsOneWidget);
    expect(find.text(strings.moodsAndGenres), findsOneWidget);
    expect(api.browseCalls, 1);
  });

  testWidgets('Jelajah gagal jaringan: pesan tanpa tombol coba lagi', (
    WidgetTester tester,
  ) async {
    final (LarasDatabase db, LibraryService library) = createTestLibrary();
    addTearDown(db.close);
    final FakeOnlineApi api = FakeOnlineApi(browseError: networkError);
    final SearchService searchService = SearchService(
      api: api,
      library: library,
    );

    setPhoneViewport(tester);
    await pumpHome(
      tester,
      libraryService: library,
      searchService: searchService,
    );

    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.sectionExplore), findsOneWidget);
    expect(find.text(strings.exploreNeedsInternet), findsOneWidget);
    // PRD B6.3: saat offline tidak ada tombol "Coba lagi".
    expect(find.text(strings.retry), findsNothing);
  });

  testWidgets('Jelajah gagal server: pesan + coba lagi berhasil', (
    WidgetTester tester,
  ) async {
    final (LarasDatabase db, LibraryService library) = createTestLibrary();
    addTearDown(db.close);
    final FakeOnlineApi api = FakeOnlineApi(
      browsePage: homeExplorePage,
      browseError: const ExtractorException(
        ResolveFailureCause.emptyResponse,
        detail: 'server kosong (tes)',
      ),
    );
    final SearchService searchService = SearchService(
      api: api,
      library: library,
    );

    setPhoneViewport(tester);
    await pumpHome(
      tester,
      libraryService: library,
      searchService: searchService,
    );

    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.exploreFailedHttp), findsOneWidget);
    expect(find.text(strings.retry), findsOneWidget);
    api.browseError = null;
    await tester.tap(find.text(strings.retry));
    await tester.pumpAndSettle();
    expect(find.text('Hit Hari Ini'), findsOneWidget);
  });

  testWidgets('seksi Jelajah sembunyi bila tidak ada layanan pencarian', (
    WidgetTester tester,
  ) async {
    final (LarasDatabase db, LibraryService library) = createTestLibrary();
    addTearDown(db.close);

    setPhoneViewport(tester);
    await pumpHome(tester, libraryService: library);

    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.sectionExplore), findsNothing);
  });

  testWidgets('banner error tampil bila lagu pilihan gagal diputar (P0)', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    port.emitSnapshot(
      PlayerSnapshot(
        currentTrack: homeTracks.first,
        queue: homeTracks,
        currentIndex: 0,
        status: PlayerStatus.error,
        lastError: const PlaybackFailure(
          kind: PlaybackFailureKind.network,
          trackTitle: 'Lagu Pilihan',
        ),
      ),
    );
    await pumpHome(tester);
    // Pesan lengkap banner (mini-player hanya menampilkan versi singkat).
    expect(
      find.text('Tidak ada internet. Periksa koneksi, lalu coba lagi.'),
      findsOneWidget,
    );
    // Tombol coba lagi banner memanggil port.play().
    await tester.tap(find.text('Coba lagi'));
    expect(port.playCalls, 1);
  });

  testWidgets('banner error sembunyi bila lagu yang gagal bukan lagu pilihan',
      (WidgetTester tester) async {
    setPhoneViewport(tester);
    port.emitSnapshot(
      PlayerSnapshot(
        currentTrack: const Track(
          videoId: 'bukan-kanari',
          title: 'Lagu Lain',
        ),
        queue: const <Track>[
          Track(videoId: 'bukan-kanari', title: 'Lagu Lain'),
        ],
        currentIndex: 0,
        status: PlayerStatus.error,
        lastError: const PlaybackFailure(
          kind: PlaybackFailureKind.network,
          trackTitle: 'Lagu Lain',
        ),
      ),
    );
    await pumpHome(tester);
    expect(
      find.text('Tidak ada internet. Periksa koneksi, lalu coba lagi.'),
      findsNothing,
    );
    expect(find.text('Coba lagi'), findsNothing);
  });
}
