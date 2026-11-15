/// Tes database drift: skema v1, foreign key, upsert, favorit, riwayat.
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'test_database.dart';

void main() {
  late LarasDatabase db;
  late LibraryService service;

  setUp(() {
    (db, service) = createTestLibrary();
  });

  tearDown(() async {
    await db.close();
  });

  test('membuka database membuat 15 tabel + tabel FTS5', () async {
    final List<QueryRow> rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type IN ('table', 'view') "
          'ORDER BY name',
        )
        .get();
    final Set<String> names = rows
        .map((QueryRow r) => r.read<String>('name'))
        .toSet();
    const List<String> expected = <String>[
      'album_artists',
      'albums',
      'artists',
      'cache_entries',
      'download_jobs',
      'formats',
      'library_search',
      'local_items',
      'lyrics',
      'play_events',
      'playlist_songs',
      'playlists',
      'queue_items',
      'search_history',
      'song_artists',
      'songs',
    ];
    for (final String table in expected) {
      expect(names, contains(table), reason: 'tabel $table harus ada');
    }
    // FTS5 punya tabel bayangan (data, idx, content, docsize, config);
    // keberadaannya membuktikan modul fts5 aktif di SQLite ini.
    expect(names, contains('library_search_data'));
  });

  test('foreign key ditegakkan: play event lagu tak dikenal ditolak', () async {
    await expectLater(
      () => db
          .into(db.playEvents)
          .insert(
            PlayEventsCompanion.insert(
              songId: 'tidak-ada',
              timestamp: DateTime.now(),
              playTimeMs: 12000,
            ),
          ),
      // Drift melempar SqliteException mentah, atau membungkusnya dalam
      // DriftWrappedException bila bisa menambah konteks.
      throwsA(
        anyOf(
          isA<sqlite3.SqliteException>(),
          isA<DriftWrappedException>(),
        ),
      ),
    );
  });

  test('upsertSong menyimpan lagu + artis + FTS dalam satu transaksi', () async {
    await service.upsertSong(
      testSong('s1', title: 'Semua Tentang Kita'),
      artistNames: <String>['Andi', 'Budi'],
      addToLibrary: true,
    );

    final SongView? view = await service.songById('s1');
    expect(view, isNotNull);
    expect(view!.song.title, 'Semua Tentang Kita');
    expect(view.song.inLibrary, isTrue);
    expect(view.artistNames, <String>['Andi', 'Budi']);

    // FTS: ditemukan lewat judul dan lewat nama artis.
    final LocalSearchResults byTitle = await service.searchLocal('tentang');
    expect(byTitle.songs.map((SongView v) => v.id), contains('s1'));
    final LocalSearchResults byArtist = await service.searchLocal('budi');
    expect(byArtist.songs.map((SongView v) => v.id), contains('s1'));
  });

  test('upsertSong kedua mempertahankan favorit dan tanggal tambah', () async {
    await service.upsertSong(
      testSong('s1', title: 'Judul Lama'),
      artistNames: const <String>['Andi'],
      addToLibrary: true,
    );
    await service.toggleLiked('s1');
    final DateTime addedBefore = (await service.songById('s1'))!.song.dateAdded;

    await service.upsertSong(
      testSong('s1', title: 'Judul Baru'),
      artistNames: const <String>['Andi'],
    );

    final SongView view = (await service.songById('s1'))!;
    expect(view.song.title, 'Judul Baru');
    expect(view.song.liked, isTrue, reason: 'favorit harus dipertahankan');
    expect(view.song.inLibrary, isTrue);
    expect(view.song.dateAdded, addedBefore);
  });

  test('toggleLiked membalik status dan memasukkan lagu ke Library', () async {
    await service.upsertSong(testSong('s1'), artistNames: const <String>[]);
    expect(await service.isLiked('s1'), isFalse);

    expect(await service.toggleLiked('s1'), isTrue);
    expect(await service.isLiked('s1'), isTrue);
    expect((await service.songById('s1'))!.song.inLibrary, isTrue);

    expect(await service.toggleLiked('s1'), isFalse);
    expect(await service.isLiked('s1'), isFalse);
    // Melepas favorit tidak mengeluarkan lagu dari Library.
    expect((await service.songById('s1'))!.song.inLibrary, isTrue);
  });

  test('toggleLiked lagu yang belum ada melempar StateError', () async {
    await expectLater(
      () => service.toggleLiked('tidak-ada'),
      throwsStateError,
    );
  });

  test('watchIsLiked menyiarkan perubahan favorit', () async {
    await service.upsertSong(testSong('s1'), artistNames: const <String>[]);
    final Stream<bool> stream = service.watchIsLiked('s1');
    expect(await stream.first, isFalse);
    await service.toggleLiked('s1');
    expect(await stream.first, isTrue);
  });

  test('recordPlay memangkas riwayat ke 10.000 entri', () async {
    await service.upsertSong(
      testSong('s1'),
      artistNames: const <String>[],
      addToLibrary: true,
    );
    // Sisipkan 10.005 event langsung (batch) supaya tes tidak lambat,
    // lalu satu recordPlay memicu pemangkasan.
    final DateTime base = DateTime(2026, 11, 1);
    await db.batch((Batch batch) {
      batch.insertAll(
        db.playEvents,
        List<PlayEventsCompanion>.generate(
          10005,
          (int i) => PlayEventsCompanion.insert(
            songId: 's1',
            timestamp: base.add(Duration(seconds: i)),
            playTimeMs: 12000,
          ),
        ),
      );
    });
    await service.recordPlay(
      songId: 's1',
      timestamp: base.add(const Duration(days: 30)),
      playTimeMs: 15000,
    );

    final int count = (await service.libraryCounts()).historyEntries;
    expect(count, kMaxPlayEvents);
    // Event terbaru (yang baru dicatat) harus selamat dari pemangkasan.
    final List<PlayHistoryEntry> page = await service.historyPage(limit: 1);
    expect(page.single.event.playTimeMs, 15000);
    // Total waktu putar hanya bertambah dari recordPlay (event batch
    // di atas menyisip langsung, melewati recordPlay).
    final Song song = (await service.songById('s1'))!.song;
    expect(song.totalPlayTimeMs, 15000);
  });

  test('removeFromLibrary mengeluarkan lagu tapi riwayat tetap ada', () async {
    await service.upsertSong(
      testSong('s1'),
      artistNames: const <String>[],
      addToLibrary: true,
    );
    await service.toggleLiked('s1');
    final int playlistId = await service.createPlaylist('Campuran');
    await service.addSongToPlaylist(playlistId, 's1');
    await service.recordPlay(
      songId: 's1',
      timestamp: DateTime.now(),
      playTimeMs: 12000,
    );

    await service.removeFromLibrary('s1');

    final SongView view = (await service.songById('s1'))!;
    expect(view.song.inLibrary, isFalse);
    expect(view.song.liked, isFalse);
    expect(
      await service.playlistSongsPage(playlistId),
      isEmpty,
      reason: 'lagu harus keluar dari playlist',
    );
    expect(
      (await service.libraryCounts()).historyEntries,
      1,
      reason: 'riwayat adalah fakta yang sudah terjadi',
    );
  });
}
