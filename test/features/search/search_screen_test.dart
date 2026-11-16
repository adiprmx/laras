/// Tes widget tab Cari: riwayat, saran, hasil gabung lokal + online,
/// kegagalan online, hapus riwayat, filter Library saja.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/search/search_service.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/main.dart';
import 'package:laras/player/player.dart';

import '../../data/test_database.dart';
import '../../player/fakes.dart';
import 'fake_online_api.dart';

const GroupedSearchResults onlineResults = GroupedSearchResults(
  songs: <SearchSong>[
    SearchSong(videoId: 'on1', title: 'Noah Online', artist: 'Noah'),
    SearchSong(videoId: 'on2', title: 'Noah Online Dua', artist: 'Noah'),
  ],
  albums: <SearchAlbum>[
    SearchAlbum(browseId: 'MPREtest1', title: 'Album Noah'),
  ],
  artists: <SearchArtist>[SearchArtist(channelId: 'UCtest1', name: 'Noah')],
  playlists: <SearchPlaylist>[
    SearchPlaylist(browseId: 'VLPLtest1', title: 'Playlist Noah'),
  ],
);

void main() {
  late FakeAudioPlayerPort port;
  late PlayerService playerService;
  late LarasDatabase db;
  late LibraryService library;
  late FakeOnlineApi api;
  late SearchService searchService;

  setUp(() {
    port = FakeAudioPlayerPort();
    playerService = PlayerService(
      port: port,
      resolver: FakeAudioResolver(),
      solver: FakeSignatureSolver(),
    );
    (db, library) = createTestLibrary();
    api = FakeOnlineApi(results: onlineResults);
    searchService = SearchService(api: api, library: library);
  });

  tearDown(() async {
    await port.dispose();
    await db.close();
  });

  void setPhoneViewport(WidgetTester tester) {
    // Viewport tinggi supaya seluruh kelompok hasil ter-build tanpa scroll
    // (ListView membangun item secara malas).
    tester.view.physicalSize = const Size(1170, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<AppLocalizations> pumpSearch(WidgetTester tester) async {
    await tester.pumpWidget(
      LarasApp(
        playerService: playerService,
        libraryService: library,
        searchService: searchService,
      ),
    );
    await tester.pumpAndSettle();
    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    await tester.tap(find.text(strings.tabSearch));
    await tester.pumpAndSettle();
    return strings;
  }

  Future<void> submitQuery(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan petunjuk bila belum ada riwayat', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    final AppLocalizations strings = await pumpSearch(tester);
    expect(find.text(strings.searchHint), findsOneWidget);
    expect(find.text(strings.recentSearches), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('mengetik menampilkan saran TANPA pencarian jaringan', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    api.suggestions = <String>['noah', 'noah band'];
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'no');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('noah'), findsOneWidget);
    expect(find.text('noah band'), findsOneWidget);
    expect(api.searchCalls, 0, reason: 'mengetik tidak boleh mencari');
    expect(api.suggestCalls, 1);
  });

  testWidgets('submit menampilkan hasil lokal dulu lalu kelompok online', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await library.upsertSong(
      testSong('local1', title: 'Noah Lokal'),
      artistNames: <String>['Noah'],
      addToLibrary: true,
    );
    final AppLocalizations strings = await pumpSearch(tester);
    await submitQuery(tester, 'noah');
    expect(find.text(strings.fromYourLibrary), findsOneWidget);
    expect(find.text('Noah Lokal'), findsOneWidget);
    expect(find.text('Noah Online'), findsOneWidget);
    expect(find.text(strings.albums), findsOneWidget);
    expect(find.text('Album Noah'), findsOneWidget);
    expect(find.text(strings.artists), findsOneWidget);
    expect(find.text(strings.playlists), findsOneWidget);
    expect(find.text('Playlist Noah'), findsOneWidget);
    // Hasil lokal tampil sebelum hasil online di daftar.
    final double localY = tester.getTopLeft(find.text('Noah Lokal')).dy;
    final double onlineY = tester.getTopLeft(find.text('Noah Online')).dy;
    expect(localY, lessThan(onlineY));
    // Query tercatat ke riwayat.
    expect(await library.recentSearches(), <String>['noah']);
  });

  testWidgets('ketuk lagu online memutar lagu itu + antrean hasil', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await pumpSearch(tester);
    await submitQuery(tester, 'noah');
    await tester.tap(find.text('Noah Online Dua'));
    await tester.pumpAndSettle();
    expect(port.setQueueCalls.length, 1);
    expect(port.setQueueCalls.single.$1.length, 2);
    expect(port.setQueueCalls.single.$2, 1);
    expect(port.setQueueCalls.single.$1[1].videoId, 'on2');
  });

  testWidgets('tanpa hasil menampilkan pesan tidak ada hasil', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    api.results = const GroupedSearchResults();
    final AppLocalizations strings = await pumpSearch(tester);
    await submitQuery(tester, 'zzzztidakada');
    expect(find.text(strings.noResultsTitle), findsOneWidget);
    expect(find.text(strings.searchNoResults('zzzztidakada')), findsOneWidget);
  });

  testWidgets('online gagal: banner + hasil lokal tetap tampil', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await library.upsertSong(
      testSong('local1', title: 'Noah Lokal'),
      artistNames: <String>['Noah'],
      addToLibrary: true,
    );
    api.searchError = networkError;
    final AppLocalizations strings = await pumpSearch(tester);
    await submitQuery(tester, 'noah');
    expect(find.text(strings.searchNeedsInternet), findsOneWidget);
    expect(find.text('Noah Lokal'), findsOneWidget);
    expect(find.text('Noah Online'), findsNothing);
    // Coba lagi dari banner.
    api.searchError = null;
    await tester.tap(find.text(strings.retry));
    await tester.pumpAndSettle();
    expect(find.text('Noah Online'), findsOneWidget);
  });

  testWidgets('hapus riwayat per item + urungkan mengembalikan', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await library.addSearchQuery('noah');
    await library.addSearchQuery('queen');
    final AppLocalizations strings = await pumpSearch(tester);
    expect(find.text('noah'), findsOneWidget);
    // Tombol silang di baris riwayat 'noah'.
    final Finder row = find.ancestor(
      of: find.text('noah'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(find.text('noah'), findsNothing);
    expect(find.text('queen'), findsOneWidget);
    expect(find.text(strings.historyDeleted), findsOneWidget);
    await tester.tap(find.text(strings.undo));
    await tester.pumpAndSettle();
    expect(find.text('noah'), findsOneWidget);
  });

  testWidgets('hapus semua riwayat memakai dialog konfirmasi', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await library.addSearchQuery('noah');
    final AppLocalizations strings = await pumpSearch(tester);
    await tester.tap(find.text(strings.deleteAll));
    await tester.pumpAndSettle();
    expect(find.text(strings.clearSearchHistoryTitle), findsOneWidget);
    // Batal dulu: riwayat tetap ada.
    await tester.tap(find.text(strings.cancel));
    await tester.pumpAndSettle();
    expect(find.text('noah'), findsOneWidget);
    // Lalu konfirmasi hapus.
    await tester.tap(find.text(strings.deleteAll));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.delete));
    await tester.pumpAndSettle();
    expect(find.text('noah'), findsNothing);
    expect(find.text(strings.searchHint), findsOneWidget);
  });

  testWidgets('ketuk riwayat mengirim kueri itu', (WidgetTester tester) async {
    setPhoneViewport(tester);
    await library.addSearchQuery('noah');
    await pumpSearch(tester);
    await tester.tap(find.text('noah'));
    await tester.pumpAndSettle();
    expect(find.text('Noah Online'), findsOneWidget);
    expect(api.searchCalls, 1);
  });

  testWidgets('filter Library saja menyembunyikan kelompok online', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await library.upsertSong(
      testSong('local1', title: 'Noah Lokal'),
      artistNames: <String>['Noah'],
      addToLibrary: true,
    );
    final AppLocalizations strings = await pumpSearch(tester);
    await submitQuery(tester, 'noah');
    expect(find.text('Noah Online'), findsOneWidget);
    await tester.tap(find.text(strings.filterLibraryOnly));
    await tester.pumpAndSettle();
    expect(find.text('Noah Lokal'), findsOneWidget);
    expect(find.text('Noah Online'), findsNothing);
    expect(find.text(strings.albums), findsNothing);
  });

  testWidgets('tombol silang kolom cari mengembalikan ke riwayat', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await library.addSearchQuery('noah');
    final AppLocalizations strings = await pumpSearch(tester);
    await submitQuery(tester, 'noah');
    expect(find.text('Noah Online'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('Noah Online'), findsNothing);
    expect(find.text(strings.recentSearches), findsOneWidget);
  });
}
