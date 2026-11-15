/// Tes layanan library: riwayat pencarian, hitungan, antrean, sortir.
library;

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('riwayat pencarian dipangkas ke 100 query, terbaru dulu', () async {
    for (int i = 0; i < 105; i++) {
      await service.addSearchQuery('query $i');
    }
    final List<String> recent = await service.recentSearches(limit: 200);
    expect(recent, hasLength(kMaxSearchHistory));
    expect(recent.first, 'query 104');
    expect(recent.last, 'query 5');
  });

  test('query yang sama tidak diduplikasi, naik ke atas daftar', () async {
    await service.addSearchQuery('cinta');
    await service.addSearchQuery('hati');
    await service.addSearchQuery('cinta');
    final List<String> recent = await service.recentSearches();
    expect(recent, <String>['cinta', 'hati']);
  });

  test('query kosong diabaikan, hapus satu dan hapus semua jalan', () async {
    await service.addSearchQuery('   ');
    expect(await service.recentSearches(), isEmpty);
    await service.addSearchQuery('satu');
    await service.addSearchQuery('dua');
    await service.deleteSearchQuery('satu');
    expect(await service.recentSearches(), <String>['dua']);
    await service.clearSearchHistory();
    expect(await service.recentSearches(), isEmpty);
  });

  test('libraryCounts menghitung isi library', () async {
    await seedSongs(service, 3);
    await service.toggleLiked('song-0000');
    await service.createPlaylist('P');
    await service.recordPlay(
      songId: 'song-0001',
      timestamp: DateTime.now(),
      playTimeMs: 12000,
    );
    final LibraryCounts counts = await service.libraryCounts();
    expect(counts.songs, 3);
    expect(counts.artists, 3, reason: 'seed memakai Artis 0, 1, 2');
    expect(counts.albums, 0);
    expect(counts.playlists, 1);
    expect(counts.favorites, 1);
    expect(counts.historyEntries, 1);
    expect(counts.isEmpty, isFalse);
  });

  test('libraryCounts kosong saat database baru', () async {
    final LibraryCounts counts = await service.libraryCounts();
    expect(counts.isEmpty, isTrue);
  });

  test('artistsPage dan albumsPage membawa jumlah lagu Library', () async {
    await service.upsertSong(
      testSong('s1', title: 'Lagu A'),
      artistNames: const <String>['Andi'],
      album: AlbumsCompanion.insert(
        id: 'al1',
        title: 'Album Satu',
        dateAdded: DateTime(2026, 11, 1),
      ),
      addToLibrary: true,
    );
    await service.upsertSong(
      testSong('s2', title: 'Lagu B'),
      artistNames: const <String>['Andi', 'Budi'],
      album: AlbumsCompanion.insert(
        id: 'al1',
        title: 'Album Satu',
        dateAdded: DateTime(2026, 11, 1),
      ),
      addToLibrary: true,
    );
    await service.upsertSong(
      testSong('s3', title: 'Lagu C'),
      artistNames: const <String>['Andi'],
      addToLibrary: false,
    );

    final List<ArtistWithCount> artists = await service.artistsPage();
    expect(
      artists.map((ArtistWithCount a) => (a.artist.name, a.songCount)),
      <(String, int)>[('Andi', 2), ('Budi', 1)],
      reason: 'lagu s3 bukan Library, tidak dihitung',
    );
    final List<AlbumWithCount> albums = await service.albumsPage();
    expect(albums, hasLength(1));
    expect(albums.single.songCount, 2);

    final List<SongView> andi = await service.songsByArtistPage(
      localArtistIdForName('Andi'),
    );
    expect(andi.map((SongView v) => v.id), <String>['s1', 's2', 's3']);
    final List<SongView> albumSongs = await service.songsByAlbumPage('al1');
    expect(albumSongs.map((SongView v) => v.id), <String>['s1', 's2']);

    // Artis yang hanya punya lagu di luar Library tidak tampil di daftar.
    await service.upsertSong(
      testSong('s4', title: 'Lagu D'),
      artistNames: const <String>['Dedi'],
      addToLibrary: false,
    );
    final List<ArtistWithCount> after = await service.artistsPage();
    expect(
      after.map((ArtistWithCount a) => a.artist.name),
      <String>['Andi', 'Budi'],
    );
  });

  test('meaningfulPlayCount menghitung putaran 30 detik ke atas', () async {
    await service.upsertSong(testSong('s1'), artistNames: const <String>[]);
    final DateTime now = DateTime.now();
    await service.recordPlay(songId: 's1', timestamp: now, playTimeMs: 35000);
    await service.recordPlay(songId: 's1', timestamp: now, playTimeMs: 5000);
    await service.recordPlay(
      songId: 's1',
      timestamp: now.subtract(const Duration(days: 40)),
      playTimeMs: 60000,
    );
    expect(await service.meaningfulPlayCount('s1'), 1);
    expect(
      await service.meaningfulPlayCount(
        's1',
        within: const Duration(days: 60),
      ),
      2,
    );
  });

  test('antrean tersimpan: ganti, muat urut posisi, kosongkan', () async {
    await service.upsertSong(testSong('s1'), artistNames: const <String>[]);
    await service.upsertSong(testSong('s2'), artistNames: const <String>[]);
    await service.replaceQueue(<QueueItemsCompanion>[
      QueueItemsCompanion.insert(songId: 's1', position: const Value<int>(0)),
      QueueItemsCompanion.insert(songId: 's2', position: const Value<int>(1)),
    ]);
    final List<QueueItem> loaded = await service.loadQueue();
    expect(
      loaded.map((QueueItem q) => q.songId),
      <String>['s1', 's2'],
    );

    await service.replaceQueue(<QueueItemsCompanion>[
      QueueItemsCompanion.insert(songId: 's2', position: const Value<int>(0)),
    ]);
    expect(
      (await service.loadQueue()).map((QueueItem q) => q.songId),
      <String>['s2'],
    );

    await service.clearQueue();
    expect(await service.loadQueue(), isEmpty);
  });

  test('libraryChanged memberi sinyal saat tabel berubah', () async {
    final Future<void> changed = service.libraryChanged.first;
    await service.upsertSong(
      testSong('s1'),
      artistNames: const <String>[],
      addToLibrary: true,
    );
    await changed.timeout(const Duration(seconds: 5));
  });

  group('LibrarySortPrefs', () {
    test('tanpa prefs, pilihan hidup di memori sesi', () {
      final LibrarySortPrefs prefs = LibrarySortPrefs();
      expect(prefs.songSort, SongSort.newest);
      prefs.songSort = SongSort.byName;
      expect(prefs.songSort, SongSort.byName);
    });

    test('dengan prefs, pilihan tersimpan dan dibaca ulang', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences sp = await SharedPreferences.getInstance();
      // getInstance meng-cache instance; bersihkan kunci dulu supaya tes
      // ini tidak bergantung pada urutan tes lain.
      await sp.remove('laras.sort.songs');
      final LibrarySortPrefs prefs = LibrarySortPrefs(prefs: sp);
      expect(prefs.songSort, SongSort.newest);
      prefs.songSort = SongSort.mostPlayed;
      expect(prefs.songSort, SongSort.mostPlayed);
      // Instance baru membaca nilai tersimpan yang sama.
      final LibrarySortPrefs reloaded = LibrarySortPrefs(prefs: sp);
      expect(reloaded.songSort, SongSort.mostPlayed);
    });

    test('nilai tersimpan yang tidak dikenal kembali ke default', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences sp = await SharedPreferences.getInstance();
      await sp.setString('laras.sort.songs', 'tidak-ada');
      expect(
        LibrarySortPrefs(prefs: sp).songSort,
        SongSort.newest,
      );
    });
  });
}
