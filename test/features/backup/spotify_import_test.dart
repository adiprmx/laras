/// Tes impor playlist Spotify (P8, PRD B10.1, Must #10): parser jalur B
/// (teks/CSV/JSON), parser HTML jalur A dengan fixture halaman asli,
/// validasi tautan (termasuk penolakan domain terlarang), pencocokan
/// ke YouTube Music dengan API palsu, dan pengambilan halaman lewat
/// Dio tiruan (tanpa jaringan).
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/backup/import_report.dart';
import 'package:laras/features/backup/spotify_import.dart';
import 'package:laras/features/search/search_service.dart';

import '../../data/test_database.dart';
import '../search/fake_online_api.dart';

String loadFixture() =>
    File('test/fixtures/spotify_playlist.html').readAsStringSync();

/// Library sekali pakai untuk tes yang tidak butuh database (parser /
/// fetch): database ditutup otomatis sesudah tes.
LibraryService tempLibrary() {
  final (LarasDatabase db, LibraryService library) = createTestLibrary();
  addTearDown(db.close);
  return library;
}

/// API palsu yang menjawab berdasarkan kueri (peta kueri -> lagu).
class QueryFakeApi implements OnlineSearchApi {
  QueryFakeApi(this.byQuery);

  final Map<String, List<SearchSong>> byQuery;
  final List<String> queries = <String>[];

  @override
  Future<GroupedSearchResults> search(String query, {String? params}) async {
    queries.add(query);
    return GroupedSearchResults(songs: byQuery[query] ?? const <SearchSong>[]);
  }

  @override
  Future<BrowsePage> browse(String browseId, {String? params}) async =>
      const BrowsePage(title: '');

  @override
  Future<List<String>> suggest(String input) async => const <String>[];
}

/// Dio yang menjawab pengambilan halaman dengan [html] (tanpa jaringan).
Dio stubDio(String html, {int statusCode = 200}) {
  final Dio dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        handler.resolve(
          Response<String>(
            requestOptions: options,
            statusCode: statusCode,
            data: html,
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('parseSpotifyText', () {
    test('baris "Artis - Judul", penomoran dihapus, judul saja diizinkan',
        () {
      final List<SpotifyTrackRef> tracks = SpotifyImportService
          .parseSpotifyText(
            '1. Billie Eilish - BIRDS OF A FEATHER\n'
            'Arctic Monkeys - I Wanna Be Yours\n'
            'Sailor Song\n'
            '\n'
            '  \n',
          );
      expect(tracks.length, 3);
      expect(tracks[0].artist, 'Billie Eilish');
      expect(tracks[0].title, 'BIRDS OF A FEATHER');
      expect(tracks[1].label, 'Arctic Monkeys - I Wanna Be Yours');
      expect(tracks[2].artist, isEmpty);
      expect(tracks[2].title, 'Sailor Song');
    });

    test('pemisah en dash / em dash dikenali', () {
      final List<SpotifyTrackRef> tracks = SpotifyImportService
          .parseSpotifyText('Noah – Separuh Aku\nPeterpan — Ada Apa Denganmu');
      expect(tracks[0].artist, 'Noah');
      expect(tracks[0].title, 'Separuh Aku');
      expect(tracks[1].artist, 'Peterpan');
    });

    test('teks kosong / hanya spasi -> SpotifyFileException', () {
      expect(
        () => SpotifyImportService.parseSpotifyText('   \n\n  '),
        throwsA(isA<SpotifyFileException>()),
      );
    });
  });

  group('parseSpotifyCsv', () {
    test('header artist+track, kolom dikutip dikenali', () {
      final List<SpotifyTrackRef> tracks = SpotifyImportService
          .parseSpotifyCsv(
            'Track Name,Artist Name(s),Album Name\n'
            '"BIRDS OF A FEATHER","Billie Eilish","HIT ME HARD AND SOFT"\n'
            '"I Wanna Be Yours","Arctic Monkeys","AM"\n',
          );
      expect(tracks.length, 2);
      expect(tracks[0].artist, 'Billie Eilish');
      expect(tracks[0].title, 'BIRDS OF A FEATHER');
    });

    test('tanpa header, 2 kolom = artis, judul', () {
      final List<SpotifyTrackRef> tracks = SpotifyImportService
          .parseSpotifyCsv('Billie Eilish,BIRDS OF A FEATHER\nArctic Monkeys,I Wanna Be Yours');
      expect(tracks.length, 2);
      expect(tracks[0].artist, 'Billie Eilish');
    });

    test('CSV tanpa lagu -> SpotifyFileException', () {
      expect(
        () => SpotifyImportService.parseSpotifyCsv('artist,track\n'),
        throwsA(isA<SpotifyFileException>()),
      );
    });
  });

  group('parseSpotifyJson', () {
    test('daftar di tingkat atas + wrapper {"tracks": [...]}', () {
      final SpotifyPlaylistDraft a = SpotifyImportService.parseSpotifyJson(
        '[{"Track Name":"BIRDS OF A FEATHER","Artist Name(s)":"Billie Eilish"}]',
      );
      expect(a.tracks.length, 1);
      expect(a.tracks[0].label, 'Billie Eilish - BIRDS OF A FEATHER');
      final SpotifyPlaylistDraft b = SpotifyImportService.parseSpotifyJson(
        '{"tracks":[{"name":"Sailor Song","artists":["Gigi Perez"]}]}',
      );
      expect(b.tracks[0].artist, 'Gigi Perez');
    });

    test('wrapper playlist + nama playlist terbaca', () {
      final SpotifyPlaylistDraft draft = SpotifyImportService
          .parseSpotifyJson(
            '{"playlist":{"name":"Chill Hits","tracks":['
            '{"track":{"name":"Sailor Song","artists":[{"name":"Gigi Perez"}]}}'
            ']}}',
          );
      expect(draft.name, 'Chill Hits');
      expect(draft.tracks.length, 1);
      expect(draft.tracks[0].artist, 'Gigi Perez');
    });

    test('JSON bukan daftar lagu -> SpotifyFileException', () {
      expect(
        () => SpotifyImportService.parseSpotifyJson('{"foo": 1}'),
        throwsA(isA<SpotifyFileException>()),
      );
      expect(
        () => SpotifyImportService.parseSpotifyJson('bukan json'),
        throwsA(isA<SpotifyFileException>()),
      );
    });
  });

  group('parseFile (deteksi dari isi)', () {
    test('JSON terdeteksi walau tanpa nama file', () {
      final SpotifyImportService service = SpotifyImportService(
        library: tempLibrary(),
        api: FakeOnlineApi(),
      );
      final SpotifyPlaylistDraft draft = service.parseFile(
        Uint8List.fromList(
          utf8.encode('[{"name":"Sailor Song","artist":"Gigi Perez"}]'),
        ),
      );
      expect(draft.tracks.length, 1);
    });

    test('teks biasa terdeteksi sebagai daftar teks', () {
      final SpotifyImportService service = SpotifyImportService(
        library: tempLibrary(),
        api: FakeOnlineApi(),
      );
      final SpotifyPlaylistDraft draft = service.parseFile(
        Uint8List.fromList(utf8.encode('Noah - Separuh Aku\n')),
        fileName: 'daftar.txt',
      );
      expect(draft.tracks.length, 1);
      expect(draft.tracks[0].artist, 'Noah');
    });
  });

  group('validateSpotifyPlaylistUrl', () {
    test('tautan playlist valid, query/fragment dibuang', () {
      final Uri uri = SpotifyImportService.validateSpotifyPlaylistUrl(
        'https://open.spotify.com/playlist/37i9dQZF1DX4WYpdgoIcn6?si=abc#frag',
      );
      expect(uri.toString(),
          'https://open.spotify.com/playlist/37i9dQZF1DX4WYpdgoIcn6');
    });

    test('domain terlarang ditolak: api + accounts (Must #10)', () {
      for (final String url in <String>[
        'https://api.spotify.com/v1/playlists/37i9dQZF1DX4WYpdgoIcn6',
        'https://accounts.spotify.com/authorize?client_id=x',
        'https://open.spotify.com/track/6dOtVTDdiauQNBQEDOtlAB',
        'https://open.spotify.com/playlist/terlalu-pendek',
        'http://open.spotify.com/playlist/37i9dQZF1DX4WYpdgoIcn6',
        'https://open.spotify.com/playlist/37i9dQZF1DX4WYpdgoIcn6/extra',
        'bukan tautan',
        '',
      ]) {
        expect(
          () => SpotifyImportService.validateSpotifyPlaylistUrl(url),
          throwsA(
            isA<SpotifyLinkException>().having(
              (SpotifyLinkException e) => e.kind,
              'kind',
              SpotifyLinkErrorKind.invalidUrl,
            ),
          ),
          reason: url,
        );
      }
    });
  });

  group('parseSpotifyPlaylistHtml (jalur A)', () {
    test('fixture halaman asli: nama + 3 lagu terbaca', () {
      final SpotifyPlaylistDraft draft =
          SpotifyImportService.parseSpotifyPlaylistHtml(loadFixture());
      expect(draft.name, 'Chill Hits');
      expect(draft.tracks.length, 3);
      expect(draft.tracks[0].title, 'BIRDS OF A FEATHER');
      expect(draft.tracks[0].artist, 'Billie Eilish');
      expect(draft.tracks[1].title, 'I Wanna Be Yours');
      expect(draft.tracks[1].artist, 'Arctic Monkeys');
      expect(draft.tracks[2].title, 'Sailor Song');
      expect(draft.tracks[2].artist, 'Gigi Perez');
      expect(draft.truncated, isFalse);
    });

    test('entitas HTML di-decode + fallback nama dari tag title', () {
      final SpotifyPlaylistDraft draft =
          SpotifyImportService.parseSpotifyPlaylistHtml(
            '<html><head><title>Lagu &#x27;80-an | Spotify Playlist</title>'
            '</head><body>'
            '<div aria-label="I Love You, I&#x27;m Sorry" data-testid="track-row">'
            '<span data-testid="internal-artist-link"><a href="/x">Gracie &amp; Co</a></span>'
            '</div></body></html>',
          );
      expect(draft.name, "Lagu '80-an");
      expect(draft.tracks.length, 1);
      expect(draft.tracks[0].title, "I Love You, I'm Sorry");
      expect(draft.tracks[0].artist, 'Gracie & Co');
    });

    test('halaman tanpa baris lagu -> draf kosong (bukan crash)', () {
      final SpotifyPlaylistDraft draft =
          SpotifyImportService.parseSpotifyPlaylistHtml(
            '<html><head><title>Spotify</title></head><body>kosong</body></html>',
          );
      expect(draft.tracks, isEmpty);
    });

    test('lebih dari 30 baris -> terpotong di 30 + truncated=true', () {
      final StringBuffer html = StringBuffer('<html><body>');
      for (int i = 0; i < 35; i++) {
        html.write(
          '<div aria-label="Lagu $i" data-testid="track-row">'
          '<span data-testid="internal-artist-link"><a>Artis $i</a></span>'
          '</div>',
        );
      }
      html.write('</body></html>');
      final SpotifyPlaylistDraft draft =
          SpotifyImportService.parseSpotifyPlaylistHtml(html.toString());
      expect(draft.tracks.length, 30);
      expect(draft.truncated, isTrue);
    });
  });

  group('fetchFromLink (Dio tiruan, tanpa jaringan)', () {
    test('halaman fixture -> draf dengan nama + lagu', () async {
      final SpotifyImportService service = SpotifyImportService(
        library: tempLibrary(),
        api: FakeOnlineApi(),
        dio: stubDio(loadFixture()),
      );
      final SpotifyPlaylistDraft draft = await service.fetchFromLink(
        'https://open.spotify.com/playlist/37i9dQZF1DX4WYpdgoIcn6',
      );
      expect(draft.name, 'Chill Hits');
      expect(draft.tracks.length, 3);
    });

    test('HTTP 404 -> unreadable; halaman kosong lagu -> empty', () async {
      final LibraryService library = tempLibrary();
      final SpotifyImportService notFound = SpotifyImportService(
        library: library,
        api: FakeOnlineApi(),
        dio: stubDio('tidak ditemukan', statusCode: 404),
      );
      await expectLater(
        notFound.fetchFromLink(
          'https://open.spotify.com/playlist/37i9dQZF1DX4WYpdgoIcn6',
        ),
        throwsA(
          isA<SpotifyLinkException>().having(
            (SpotifyLinkException e) => e.kind,
            'kind',
            SpotifyLinkErrorKind.unreadable,
          ),
        ),
      );
      final SpotifyImportService empty = SpotifyImportService(
        library: library,
        api: FakeOnlineApi(),
        dio: stubDio('<html><body>tanpa lagu</body></html>'),
      );
      await expectLater(
        empty.fetchFromLink(
          'https://open.spotify.com/playlist/37i9dQZF1DX4WYpdgoIcn6',
        ),
        throwsA(
          isA<SpotifyLinkException>().having(
            (SpotifyLinkException e) => e.kind,
            'kind',
            SpotifyLinkErrorKind.empty,
          ),
        ),
      );
    });
  });

  group('importDraft (pencocokan)', () {
    late LarasDatabase db;
    late LibraryService library;

    setUp(() {
      (db, library) = createTestLibrary();
    });

    tearDown(() async {
      await db.close();
    });

    test('cocok -> playlist baru berisi lagu; tidak cocok -> laporan gagal',
        () async {
      final QueryFakeApi api = QueryFakeApi(<String, List<SearchSong>>{
        'Billie Eilish BIRDS OF A FEATHER': <SearchSong>[
          const SearchSong(
            videoId: 'vid-birds',
            title: 'BIRDS OF A FEATHER',
            artist: 'Billie Eilish',
            durationSeconds: 210,
          ),
        ],
        'Arctic Monkeys I Wanna Be Yours': <SearchSong>[
          const SearchSong(
            videoId: 'vid-yours',
            title: 'I Wanna Be Yours',
            artist: 'Arctic Monkeys',
          ),
        ],
      });
      final SpotifyImportService service = SpotifyImportService(
        library: library,
        api: api,
        matchDelay: Duration.zero,
      );
      final ImportReport report = await service.importDraft(
        const SpotifyPlaylistDraft(
          name: 'Chill Hits',
          tracks: <SpotifyTrackRef>[
            SpotifyTrackRef(title: 'BIRDS OF A FEATHER', artist: 'Billie Eilish'),
            SpotifyTrackRef(title: 'I Wanna Be Yours', artist: 'Arctic Monkeys'),
            SpotifyTrackRef(title: 'Lagu Tidak Ada', artist: 'Artis Fiktif'),
          ],
        ),
        playlistName: 'Chill Hits',
      );
      expect(report.succeeded, 2);
      expect(report.failed, 1);
      expect(report.failures[0].reason, ImportFailureReason.notFound);
      expect(report.failures[0].label, contains('Lagu Tidak Ada'));
      expect(report.playlistId, isNotNull);
      expect(report.playlistName, 'Chill Hits');
      final BackupSnapshot snap = await library.backupSnapshot();
      expect(snap.playlists.length, 1);
      expect(snap.playlists[0].$2.toSet(), <String>{'vid-birds', 'vid-yours'});
      // Kueri pencocokan TIDAK masuk riwayat pencarian.
      expect(snap.searchHistory, isEmpty);
    });

    test('judul mirip tapi artis beda -> tidak ditebak (gagal notFound)',
        () async {
      final QueryFakeApi api = QueryFakeApi(<String, List<SearchSong>>{
        'Noah Separuh Aku': <SearchSong>[
          const SearchSong(
            videoId: 'vid-lain',
            title: 'Separuh Aku',
            artist: 'Artis Lain',
          ),
        ],
      });
      final SpotifyImportService service = SpotifyImportService(
        library: library,
        api: api,
        matchDelay: Duration.zero,
      );
      final ImportReport report = await service.importDraft(
        const SpotifyPlaylistDraft(
          tracks: <SpotifyTrackRef>[
            SpotifyTrackRef(title: 'Separuh Aku', artist: 'Noah'),
          ],
        ),
        playlistName: 'Tes',
      );
      expect(report.succeeded, 0);
      expect(report.failed, 1);
      // Semua gagal -> TIDAK ada playlist yang dibuat.
      expect(report.playlistId, isNull);
      final BackupSnapshot snap = await library.backupSnapshot();
      expect(snap.playlists, isEmpty);
    });

    test('normalisasi: kurung, tanda baca, kapitalisasi diabaikan', () async {
      final QueryFakeApi api = QueryFakeApi(<String, List<SearchSong>>{
        'Noah Separuh Aku (Remastered)': <SearchSong>[
          const SearchSong(
            videoId: 'vid-noah',
            title: 'Separuh Aku (Remastered 2020)',
            artist: 'NOAH',
          ),
        ],
      });
      final SpotifyImportService service = SpotifyImportService(
        library: library,
        api: api,
        matchDelay: Duration.zero,
      );
      final ImportReport report = await service.importDraft(
        const SpotifyPlaylistDraft(
          tracks: <SpotifyTrackRef>[
            SpotifyTrackRef(title: 'Separuh Aku (Remastered)', artist: 'Noah'),
          ],
        ),
        playlistName: 'Tes',
      );
      expect(report.succeeded, 1);
    });

    test('duplikat videoId dihitung sudah ada (bukan gagal)', () async {
      final QueryFakeApi api = QueryFakeApi(<String, List<SearchSong>>{
        'Noah Separuh Aku': <SearchSong>[
          const SearchSong(
            videoId: 'vid-noah',
            title: 'Separuh Aku',
            artist: 'Noah',
          ),
        ],
      });
      final SpotifyImportService service = SpotifyImportService(
        library: library,
        api: api,
        matchDelay: Duration.zero,
      );
      final ImportReport report = await service.importDraft(
        const SpotifyPlaylistDraft(
          tracks: <SpotifyTrackRef>[
            SpotifyTrackRef(title: 'Separuh Aku', artist: 'Noah'),
            SpotifyTrackRef(title: 'Separuh Aku', artist: 'Noah'),
          ],
        ),
        playlistName: 'Tes',
      );
      expect(report.succeeded, 1);
      expect(report.alreadyExisted, 1);
      expect(report.failed, 0);
    });

    test('jaringan putus di tengah: sisanya gagal network, yang cocok tersimpan',
        () async {
      final FakeOnlineApi api = FakeOnlineApi(
        results: const GroupedSearchResults(
          songs: <SearchSong>[
            SearchSong(
              videoId: 'vid-a',
              title: 'Lagu A',
              artist: 'Artis A',
            ),
          ],
        ),
      );
      // Panggilan pertama berhasil, lalu jaringan putus.
      final OnlineSearchApi flaky = _FlakyApi(api, failAfter: 1);
      final SpotifyImportService service = SpotifyImportService(
        library: library,
        api: flaky,
        matchDelay: Duration.zero,
      );
      final ImportReport report = await service.importDraft(
        const SpotifyPlaylistDraft(
          tracks: <SpotifyTrackRef>[
            SpotifyTrackRef(title: 'Lagu A', artist: 'Artis A'),
            SpotifyTrackRef(title: 'Lagu B', artist: 'Artis B'),
            SpotifyTrackRef(title: 'Lagu C', artist: 'Artis C'),
          ],
        ),
        playlistName: 'Tes',
      );
      expect(report.succeeded, 1);
      expect(report.failed, 2);
      expect(
        report.failures
            .every((ImportFailure f) => f.reason == ImportFailureReason.network),
        isTrue,
      );
      expect(report.playlistId, isNotNull);
    });

    test('dibatalkan: sisanya gagal cancelled, yang cocok tersimpan', () async {
      final FakeOnlineApi api = FakeOnlineApi(
        results: const GroupedSearchResults(
          songs: <SearchSong>[
            SearchSong(
              videoId: 'vid-a',
              title: 'Lagu A',
              artist: 'Artis A',
            ),
          ],
        ),
      );
      final SpotifyImportService service = SpotifyImportService(
        library: library,
        api: api,
        matchDelay: Duration.zero,
      );
      int progressCalls = 0;
      final ImportReport report = await service.importDraft(
        const SpotifyPlaylistDraft(
          tracks: <SpotifyTrackRef>[
            SpotifyTrackRef(title: 'Lagu A', artist: 'Artis A'),
            SpotifyTrackRef(title: 'Lagu B', artist: 'Artis B'),
          ],
        ),
        playlistName: 'Tes',
        onProgress: (int done, int total) {
          progressCalls++;
        },
        isCancelled: () => progressCalls >= 1,
      );
      expect(report.succeeded, 1);
      expect(report.failed, 1);
      expect(
        report.failures[0].reason,
        ImportFailureReason.cancelled,
      );
      expect(report.playlistId, isNotNull);
    });
  });

  group('normalizeTrackText', () {
    test('huruf kecil, tanda baca, kurung, diakritik', () {
      expect(
        SpotifyImportService.normalizeTrackText('Beyoncé - Halo (Remix) [2020]'),
        'beyonce halo',
      );
      expect(
        SpotifyImportService.normalizeTrackText('  SEPARUH AKU!  '),
        'separuh aku',
      );
    });
  });
}

/// Pembungkus API yang melempar error jaringan sesudah N panggilan sukses.
class _FlakyApi implements OnlineSearchApi {
  _FlakyApi(this.inner, {required this.failAfter});

  final OnlineSearchApi inner;
  final int failAfter;
  int _calls = 0;

  @override
  Future<GroupedSearchResults> search(String query, {String? params}) async {
    _calls++;
    if (_calls > failAfter) throw networkError;
    return inner.search(query, params: params);
  }

  @override
  Future<BrowsePage> browse(String browseId, {String? params}) =>
      inner.browse(browseId, params: params);

  @override
  Future<List<String>> suggest(String input) => inner.suggest(input);
}
