/// Tes metode LibraryService baru P7: lirik, status pemutar, songsByIds,
/// dan importSongs tanpa masuk Library.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';

import 'test_database.dart';

void main() {
  late LarasDatabase db;
  late LibraryService library;

  setUp(() {
    (db, library) = createTestLibrary();
  });

  tearDown(() async {
    await db.close();
  });

  group('lirik (P7)', () {
    test('getLyrics null bila belum ada; saveLyrics lalu terbaca', () async {
      expect(await library.getLyrics('song-1'), isNull);
      await library.upsertSong(testSong('song-1'));
      await library.saveLyrics(
        songId: 'song-1',
        lyrics: 'Lirik polos',
        syncedLyrics: '[00:01.00]Sinkron',
      );
      final Lyric? lyric = await library.getLyrics('song-1');
      expect(lyric, isNotNull);
      expect(lyric!.lyrics, 'Lirik polos');
      expect(lyric.syncedLyrics, '[00:01.00]Sinkron');
    });

    test('saveLyrics kedua menimpa yang pertama', () async {
      await library.upsertSong(testSong('song-1'));
      await library.saveLyrics(songId: 'song-1', lyrics: 'Versi 1');
      await library.saveLyrics(
        songId: 'song-1',
        lyrics: 'Versi 2',
        syncedLyrics: '[00:02.00]V2',
      );
      final Lyric? lyric = await library.getLyrics('song-1');
      expect(lyric!.lyrics, 'Versi 2');
      expect(lyric.syncedLyrics, '[00:02.00]V2');
    });
  });

  group('status pemutar (P7, MUST #3)', () {
    test('loadPlaybackState null bila belum pernah disimpan', () async {
      expect(await library.loadPlaybackState(), isNull);
    });

    test('savePlaybackState + loadPlaybackState round-trip', () async {
      await library.savePlaybackState(
        currentIndex: 3,
        positionMs: 123456,
        shuffleEnabled: true,
        repeatMode: RepeatModeValue.one,
      );
      final PlaybackStateData? state = await library.loadPlaybackState();
      expect(state, isNotNull);
      expect(state!.id, 1);
      expect(state.currentIndex, 3);
      expect(state.positionMs, 123456);
      expect(state.shuffleEnabled, isTrue);
      expect(state.repeatMode, RepeatModeValue.one);
    });

    test('savePlaybackState kedua menimpa (satu baris saja)', () async {
      await library.savePlaybackState(
        currentIndex: 0,
        positionMs: 0,
        shuffleEnabled: false,
        repeatMode: 0,
      );
      await library.savePlaybackState(
        currentIndex: 5,
        positionMs: 999,
        shuffleEnabled: true,
        repeatMode: 1,
      );
      final List<PlaybackStateData> rows = await db
          .select(db.playbackState)
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.currentIndex, 5);
    });

    test('savePlaybackPosition mempertahankan indeks/mode', () async {
      await library.savePlaybackState(
        currentIndex: 2,
        positionMs: 1000,
        shuffleEnabled: true,
        repeatMode: RepeatModeValue.all,
      );
      await library.savePlaybackPosition(54321);
      final PlaybackStateData? state = await library.loadPlaybackState();
      expect(state!.positionMs, 54321);
      expect(state.currentIndex, 2);
      expect(state.shuffleEnabled, isTrue);
      expect(state.repeatMode, RepeatModeValue.all);
    });

    test('savePlaybackPosition tanpa baris membuat baris default', () async {
      await library.savePlaybackPosition(777);
      final PlaybackStateData? state = await library.loadPlaybackState();
      expect(state, isNotNull);
      expect(state!.positionMs, 777);
      expect(state.currentIndex, 0);
      expect(state.shuffleEnabled, isFalse);
      expect(state.repeatMode, RepeatModeValue.off);
    });
  });

  group('songsByIds (P7)', () {
    test('mengembalikan lagu sesuai urutan ids', () async {
      await library.importSongs(<SongImport>[
        SongImport(song: testSong('c')),
        SongImport(song: testSong('a')),
        SongImport(song: testSong('b')),
      ]);
      final List<SongView> views = await library.songsByIds(
        <String>['b', 'a', 'c'],
      );
      expect(
        views.map((SongView v) => v.id).toList(),
        <String>['b', 'a', 'c'],
      );
    });

    test('id yang tidak ada dilewati', () async {
      await library.importSongs(<SongImport>[SongImport(song: testSong('a'))]);
      final List<SongView> views = await library.songsByIds(
        <String>['a', 'hilang', 'juga-hilang'],
      );
      expect(views.map((SongView v) => v.id).toList(), <String>['a']);
    });

    test('daftar kosong mengembalikan daftar kosong', () async {
      expect(await library.songsByIds(<String>[]), isEmpty);
    });
  });

  group('importSongs addToLibrary (P7)', () {
    test('addToLibrary false tidak memasukkan lagu ke Library', () async {
      await library.importSongs(
        <SongImport>[SongImport(song: testSong('q1'))],
        addToLibrary: false,
      );
      final SongView? view = await library.songById('q1');
      expect(view, isNotNull);
      expect(view!.song.inLibrary, isFalse);
    });

    test('default addToLibrary true (perilaku lama)', () async {
      await library.importSongs(
        <SongImport>[SongImport(song: testSong('q2'))],
      );
      final SongView? view = await library.songById('q2');
      expect(view!.song.inLibrary, isTrue);
    });

    test('channelId artis diteruskan lewat SongImport', () async {
      await library.importSongs(<SongImport>[
        SongImport(
          song: testSong('q3'),
          artistNames: <String>['Artis Asli'],
          artistChannelIds: <String?>['UCkanal123'],
        ),
      ]);
      final Artist? artist = await library.artistById('UCkanal123');
      expect(artist, isNotNull);
      expect(artist!.name, 'Artis Asli');
    });
  });
}
