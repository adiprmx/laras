/// Tes API lagu yang tidak bisa diputar di LibraryService (P6, B4.7).
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  test('mark/clear/isUnplayable', () async {
    await library.upsertSong(testSong('s1'), addToLibrary: true);
    expect(await library.isUnplayable('s1'), isFalse);
    await library.markUnplayable('s1');
    expect(await library.isUnplayable('s1'), isTrue);
    await library.clearUnplayable('s1');
    expect(await library.isUnplayable('s1'), isFalse);
  });

  test('isUnplayable false untuk lagu yang tidak ada', () async {
    expect(await library.isUnplayable('tidak-ada'), isFalse);
  });

  test('markDownloaded membersihkan tanda unplayable', () async {
    await library.upsertSong(testSong('s1'), addToLibrary: true);
    await library.markUnplayable('s1');
    expect(await library.isUnplayable('s1'), isTrue);
    await library.markDownloaded(
      songId: 's1',
      filePath: 's1.m4a',
      fileSizeBytes: 1000,
    );
    expect(await library.isUnplayable('s1'), isFalse);
    expect(await library.isDownloaded('s1'), isTrue);
  });

  test('isDownloaded false bila belum terunduh / tanpa filePath', () async {
    await library.upsertSong(testSong('s1'), addToLibrary: true);
    expect(await library.isDownloaded('s1'), isFalse);
    await library.setDownloadState('s1', DownloadState.downloaded);
    // Status terunduh tapi filePath null (tidak konsisten) = bukan unduhan.
    expect(await library.isDownloaded('s1'), isFalse);
  });

  test('unplayableCount hanya menghitung yang bukan unduhan', () async {
    await library.upsertSong(testSong('s1'), addToLibrary: true);
    await library.upsertSong(testSong('s2'), addToLibrary: true);
    await library.upsertSong(testSong('s3'), addToLibrary: true);
    await library.markUnplayable('s1');
    await library.markUnplayable('s2');
    await library.markDownloaded(
      songId: 's2',
      filePath: 's2.m4a',
      fileSizeBytes: 1000,
    );
    // s2 terunduh (tanda dibersihkan) -> hanya s1 yang dihitung.
    expect(await library.unplayableCount(), 1);
  });

  test('deleteUnplayableSongs menghapus yang bertanda, bukan unduhan',
      () async {
    await library.upsertSong(testSong('s1'), addToLibrary: true);
    await library.upsertSong(testSong('s2'), addToLibrary: true);
    await library.upsertSong(testSong('s3'), addToLibrary: true);
    await library.markUnplayable('s1');
    await library.markUnplayable('s2');
    await library.markDownloaded(
      songId: 's2',
      filePath: 's2.m4a',
      fileSizeBytes: 1000,
    );
    // s2 terunduh: tandanya dibersihkan saat markDownloaded, jadi
    // tandai lagi secara paksa lewat update langsung untuk menguji
    // penjaga delete (unduhan tidak ikut terhapus walau bertanda).
    await (db.update(db.songs)..where((Songs s) => s.id.equals('s2'))).write(
      const SongsCompanion(unplayable: Value<bool>(true)),
    );
    final int deleted = await library.deleteUnplayableSongs();
    expect(deleted, 1);
    expect(await library.songById('s1'), isNull);
    expect(await library.songById('s2'), isNotNull);
    expect(await library.songById('s3'), isNotNull);
    expect(await library.unplayableCount(), 0);
  });

  test('deleteUnplayableSongs membersihkan entri playlist + FTS', () async {
    await library.upsertSong(
      testSong('s1'),
      artistNames: <String>['Artis Unik'],
      addToLibrary: true,
    );
    final int playlistId = await library.createPlaylist('P1');
    await library.addSongToPlaylist(playlistId, 's1');
    await library.markUnplayable('s1');
    expect(await library.deleteUnplayableSongs(), 1);
    // Entri playlist ikut hilang (cascade/manual).
    final List<PlaylistSongEntry> inPlaylist =
        await library.playlistSongsPage(playlistId);
    expect(inPlaylist, isEmpty);
    // Pencarian FTS tidak lagi menemukan lagu yang dihapus.
    final LocalSearchResults found = await library.searchLocal('Unik');
    expect(found.songs, isEmpty);
  });

  test('deleteUnplayableSongs mengembalikan 0 bila tidak ada yang bertanda',
      () async {
    await library.upsertSong(testSong('s1'), addToLibrary: true);
    expect(await library.deleteUnplayableSongs(), 0);
  });
}
