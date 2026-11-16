/// Tes widget halaman detail browse: header + lagu bisa diputar,
/// kartu membuka halaman berikut, gagal muat + coba lagi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/onboarding/onboarding_flow.dart';
import 'package:laras/features/search/browse_detail_screen.dart';
import 'package:laras/features/search/search_service.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/main.dart';
import 'package:laras/player/player.dart';
import 'package:laras/resilience/honesty_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/test_database.dart';
import '../../player/fakes.dart';
import 'fake_online_api.dart';

const BrowsePage artistPage = BrowsePage(
  title: 'Noah',
  subtitle: 'Artis • 33,5 jt pendengar bulanan',
  shelves: <BrowseShelf>[
    BrowseShelf(
      title: 'Top songs',
      isSongList: true,
      items: <BrowseItem>[
        BrowseItem(
          kind: BrowseItemKind.song,
          title: 'Semua Tentang Kita',
          artist: 'Noah',
          videoId: 'vid1',
          durationSeconds: 268,
        ),
        BrowseItem(
          kind: BrowseItemKind.song,
          title: 'Separuh Aku',
          artist: 'Noah',
          videoId: 'vid2',
          durationSeconds: 240,
        ),
      ],
    ),
    BrowseShelf(
      title: 'Albums',
      items: <BrowseItem>[
        BrowseItem(
          kind: BrowseItemKind.album,
          title: 'Sebuah Nama, Sebuah Cerita',
          subtitle: 'Album • 2008',
          browseId: 'MPREtest1',
        ),
      ],
    ),
  ],
);

const BrowsePage albumPage = BrowsePage(
  title: 'Sebuah Nama, Sebuah Cerita',
  subtitle: 'Album • Noah • 2008',
  shelves: <BrowseShelf>[
    BrowseShelf(
      title: 'Lagu',
      isSongList: true,
      items: <BrowseItem>[
        BrowseItem(
          kind: BrowseItemKind.song,
          title: 'Hari Yang Cerah',
          artist: 'Peterpan',
          videoId: 'vid3',
          durationSeconds: 200,
        ),
      ],
    ),
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
    api = FakeOnlineApi(browsePage: artistPage);
    searchService = SearchService(api: api, library: library);
  });

  tearDown(() async {
    await port.dispose();
    await db.close();
  });

  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<AppLocalizations> pumpDetail(
    WidgetTester tester, {
    String browseId = 'UCtest1',
    String title = 'Noah',
  }) async {
    // Matikan urutan first-run (diuji di first_run_test.dart).
    SharedPreferences.setMockInitialValues(<String, Object>{
      kOnboardingShownKey: true,
      kHonestySheetShownKey: true,
    });
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
    // Buka halaman detail lewat navigasi dari beranda: pakai push
    // langsung lewat context beranda.
    final BuildContext context = tester.element(find.byType(Scaffold).first);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            BrowseDetailScreen(browseId: browseId, title: title),
      ),
    );
    await tester.pumpAndSettle();
    return strings;
  }

  testWidgets('menampilkan header + lagu, ketuk lagu memutar', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    final AppLocalizations strings = await pumpDetail(tester);
    expect(find.text('Noah'), findsWidgets);
    expect(find.text('Top songs'), findsOneWidget);
    expect(find.text('Semua Tentang Kita'), findsOneWidget);
    expect(find.text('Separuh Aku'), findsOneWidget);
    expect(find.text(strings.playAll), findsOneWidget);
    await tester.tap(find.text('Separuh Aku'));
    await tester.pumpAndSettle();
    expect(port.setQueueCalls.length, 1);
    expect(port.setQueueCalls.single.$1.length, 2);
    expect(port.setQueueCalls.single.$2, 1);
  });

  testWidgets('tombol Putar Semua memutar dari lagu pertama', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    final AppLocalizations strings = await pumpDetail(tester);
    await tester.tap(find.text(strings.playAll));
    await tester.pumpAndSettle();
    expect(port.setQueueCalls.length, 1);
    expect(port.setQueueCalls.single.$2, 0);
  });

  testWidgets('ketuk kartu album membuka halaman album', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    // API palsu menjawab halaman berbeda per browseId.
    api.browsePage = artistPage;
    final _BrowseByIdApi byId = _BrowseByIdApi(<String, BrowsePage>{
      'UCtest1': artistPage,
      'MPREtest1': albumPage,
    });
    searchService = SearchService(api: byId, library: library);
    await pumpDetail(tester);
    await tester.tap(find.text('Sebuah Nama, Sebuah Cerita'));
    await tester.pumpAndSettle();
    expect(find.text('Hari Yang Cerah'), findsOneWidget);
    expect(byId.lastBrowseId, 'MPREtest1');
  });

  testWidgets('gagal muat menampilkan pesan + coba lagi', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    api.browseError = networkError;
    final AppLocalizations strings = await pumpDetail(tester);
    expect(find.text(strings.browseFailedTitle), findsOneWidget);
    expect(find.text(strings.exploreNeedsInternet), findsOneWidget);
    api.browseError = null;
    await tester.tap(find.text(strings.retry));
    await tester.pumpAndSettle();
    expect(find.text('Semua Tentang Kita'), findsOneWidget);
  });

  testWidgets('halaman tanpa lagu menampilkan pesan kosong', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    api.browsePage = const BrowsePage(title: 'Kosong');
    final AppLocalizations strings = await pumpDetail(
      tester,
      browseId: 'UCempty',
      title: 'Kosong',
    );
    expect(find.text(strings.noSongsInBrowse), findsOneWidget);
  });
}

/// API palsu yang menjawab per browseId (untuk navigasi berantai).
class _BrowseByIdApi implements OnlineSearchApi {
  _BrowseByIdApi(this.pages);

  final Map<String, BrowsePage> pages;
  String? lastBrowseId;

  @override
  Future<GroupedSearchResults> search(String query, {String? params}) async {
    return const GroupedSearchResults();
  }

  @override
  Future<BrowsePage> browse(String browseId, {String? params}) async {
    lastBrowseId = browseId;
    return pages[browseId] ?? const BrowsePage(title: '');
  }

  @override
  Future<List<String>> suggest(String input) async => const <String>[];
}
