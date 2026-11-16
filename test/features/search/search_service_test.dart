/// Tes SearchService dengan API online palsu (tanpa jaringan):
/// gabung lokal + online, aturan riwayat, saran, klasifikasi kegagalan,
/// dan gabung artis latar.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/search/search_service.dart';

import '../../data/test_database.dart';
import 'fake_online_api.dart';

void main() {
  late LarasDatabase db;
  late LibraryService library;
  late FakeOnlineApi api;
  late SearchService service;

  setUp(() {
    (db, library) = createTestLibrary();
    api = FakeOnlineApi();
    service = SearchService(api: api, library: library);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedLocal() async {
    await library.upsertSong(
      testSong('local1', title: 'Noah Lokal'),
      artistNames: <String>['Noah'],
      addToLibrary: true,
    );
  }

  test('menggabungkan hasil lokal dan online dalam satu pencarian', () async {
    await seedLocal();
    api.results = const GroupedSearchResults(
      songs: <SearchSong>[
        SearchSong(videoId: 'on1', title: 'Noah Online', artist: 'Noah'),
      ],
    );
    final CombinedSearch result = await service.search('noah');
    expect(result.local.songs.length, 1);
    expect(result.local.songs.single.song.title, 'Noah Lokal');
    expect(result.online!.songs.length, 1);
    expect(result.online!.songs.single.title, 'Noah Online');
    expect(result.failure, isNull);
  });

  test('query yang berhasil dicatat ke riwayat', () async {
    await service.search('noah');
    expect(await service.recentSearches(), <String>['noah']);
  });

  test('query yang gagal total karena jaringan TIDAK masuk riwayat', () async {
    api.searchError = networkError;
    final CombinedSearch result = await service.search('noah');
    expect(result.failure, OnlineFailure.network);
    expect(result.online, isNull);
    expect(await service.recentSearches(), isEmpty);
  });

  test('hasil lokal tetap ada walau online gagal', () async {
    await seedLocal();
    api.searchError = networkError;
    final CombinedSearch result = await service.search('noah');
    expect(result.local.songs.length, 1);
    expect(result.failure, OnlineFailure.network);
  });

  test('kegagalan parse diklasifikasikan sebagai parse', () async {
    api.searchError = parseError;
    final CombinedSearch result = await service.search('noah');
    expect(result.failure, OnlineFailure.parse);
  });

  test('saran jaringan dipakai bila ada, riwayat sebagai cadangan', () async {
    api.suggestions = <String>['noah', 'noah band'];
    expect(await service.suggestions('no'), <String>['noah', 'noah band']);
    // Jaringan gagal -> saran dari riwayat lokal.
    api.suggestError = networkError;
    await library.addSearchQuery('nora');
    await library.addSearchQuery('noah lokal');
    expect(await service.suggestions('no'), <String>['noah lokal', 'nora']);
  });

  test(
    'saran tidak pernah melempar: gagal total menghasilkan kosong',
    () async {
      api.suggestError = networkError;
      final SearchService noLibrary = SearchService(api: api);
      expect(await noLibrary.suggestions('no'), isEmpty);
    },
  );

  test('param filter diteruskan ke API', () async {
    await service.search(
      'noah',
      params: 'EgWKAQIIAWoSEAQQAxAFEAkQChAVEBAQDhAR',
    );
    expect(api.lastSearchParams, 'EgWKAQIIAWoSEAQQAxAFEAkQChAVEBAQDhAR');
  });

  test('pencarian menggabungkan artis semu ke channelId di latar', () async {
    await library.upsertSong(
      testSong('local1', title: 'Lagu Noah'),
      artistNames: <String>['Noah'],
      addToLibrary: true,
    );
    expect(
      (await library.artistsPage()).single.artist.id,
      startsWith('local-'),
    );
    api.results = const GroupedSearchResults(
      songs: <SearchSong>[
        SearchSong(
          videoId: 'on1',
          title: 'Lagu Noah',
          artist: 'Noah',
          artistChannelId: 'UCCMnLkUAdm_NGMDTTC-nvDQ',
        ),
      ],
    );
    await service.search('noah');
    // Gabung berjalan di latar (unawaited): tunggu sebentar.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      (await library.artistsPage()).single.artist.id,
      'UCCMnLkUAdm_NGMDTTC-nvDQ',
    );
  });

  test('browseHome memakai cache 6 jam, forceRefresh memuat ulang', () async {
    api.browsePage = const BrowsePage(
      title: '',
      shelves: <BrowseShelf>[BrowseShelf(title: 'Rak Satu')],
    );
    final BrowseOutcome first = await service.browseHome();
    expect(first.isSuccess, isTrue);
    expect(api.browseCalls, 1);
    final BrowseOutcome second = await service.browseHome();
    expect(second.isSuccess, isTrue);
    expect(api.browseCalls, 1, reason: 'cache dipakai, tanpa request');
    await service.browseHome(forceRefresh: true);
    expect(api.browseCalls, 2);
  });

  test('browseHome gagal memakai data terakhir bila ada', () async {
    api.browsePage = const BrowsePage(
      title: '',
      shelves: <BrowseShelf>[BrowseShelf(title: 'Rak Satu')],
    );
    await service.browseHome();
    api.browseError = networkError;
    final BrowseOutcome outcome = await service.browseHome(forceRefresh: true);
    expect(outcome.isSuccess, isTrue);
    expect(outcome.fromCache, isTrue);
    expect(outcome.failure, OnlineFailure.network);
    expect(outcome.page!.shelves.single.title, 'Rak Satu');
  });

  test('tanpa library, pencarian online tetap jalan', () async {
    api.results = const GroupedSearchResults(
      songs: <SearchSong>[SearchSong(videoId: 'on1', title: 'Noah Online')],
    );
    final SearchService noLibrary = SearchService(api: api);
    final CombinedSearch result = await noLibrary.search('noah');
    expect(result.local.isEmpty, isTrue);
    expect(result.online!.songs.length, 1);
  });
}
