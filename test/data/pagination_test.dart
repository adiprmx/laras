/// Tes pagination keyset 50 per halaman (PRD B4.4).
library;

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';

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

  test('120 lagu terbagi 50/50/20 tanpa tumpang tindih dan tanpa celah', () async {
    final List<String> ids = await seedSongs(service, 120);

    final List<SongView> page1 = await service.songsPage();
    expect(page1, hasLength(50));
    final List<SongView> page2 = await service.songsPage(after: page1.last);
    expect(page2, hasLength(50));
    final List<SongView> page3 = await service.songsPage(after: page2.last);
    expect(page3, hasLength(20));
    final List<SongView> page4 = await service.songsPage(after: page3.last);
    expect(page4, isEmpty);

    final Set<String> seen = <String>{
      for (final SongView v in <SongView>[...page1, ...page2, ...page3]) v.id,
    };
    expect(seen, hasLength(120));
    expect(seen, containsAll(ids));
  });

  test('sisipan di tengah tidak menggeser halaman berikut (keyset)', () async {
    await seedSongs(service, 100);
    final List<SongView> page1 = await service.songsPage();
    final String expectedNextFirst = (await service.songsPage(after: page1.last)).first.id;

    // Sisipkan lagu baru (paling baru) di antara dua pemanggilan halaman.
    await service.upsertSong(
      testSong('baru-0000', title: 'Lagu Baru'),
      artistNames: const <String>['Artis Baru'],
      addToLibrary: true,
    );

    // Halaman kedua harus identik dengan sebelum sisipan: keyset tidak
    // memakai offset, jadi sisipan di awal tidak menggeser apa pun.
    final List<SongView> page2 = await service.songsPage(after: page1.last);
    expect(page2.first.id, expectedNextFirst);
    expect(
      page2.map((SongView v) => v.id),
      isNot(contains('baru-0000')),
    );
    expect(
      page2.map((SongView v) => v.id).toSet().intersection(
        page1.map((SongView v) => v.id).toSet(),
      ),
      isEmpty,
    );
  });

  test('urut terbaru memakai tanggal tambah, lalu id sebagai penyeimbang', () async {
    final DateTime base = DateTime(2026, 11, 1);
    // Tiga lagu dengan tanggal tambah berbeda, disisip acak.
    for (final (String, int) item in <(String, int)>[
      ('b', 2),
      ('a', 1),
      ('c', 3),
    ]) {
      await db
          .into(db.songs)
          .insert(
            SongsCompanion.insert(
              id: item.$1,
              title: 'Lagu ${item.$1}',
              inLibrary: const Value<bool>(true),
              dateAdded: base.add(Duration(days: item.$2)),
              dateModified: base.add(Duration(days: item.$2)),
            ),
          );
    }
    final List<SongView> page = await service.songsPage();
    expect(
      page.map((SongView v) => v.id).toList(),
      <String>['c', 'b', 'a'],
    );
  });

  test('urut nama memakai huruf kecil dan stabil antar halaman', () async {
    await seedSongs(service, 60);
    final List<SongView> page1 = await service.songsPage(sort: SongSort.byName);
    final List<SongView> page2 = await service.songsPage(
      sort: SongSort.byName,
      after: page1.last,
    );
    expect(page1, hasLength(50));
    expect(page2, hasLength(10));
    final List<String> titles = <String>[
      for (final SongView v in <SongView>[...page1, ...page2])
        v.song.title.toLowerCase(),
    ];
    final List<String> sorted = List<String>.of(titles)..sort();
    expect(titles, sorted);
  });

  test('urut sering diputar memakai total waktu putar', () async {
    await seedSongs(service, 3);
    await service.recordPlay(
      songId: 'song-0001',
      timestamp: DateTime.now(),
      playTimeMs: 60000,
    );
    await service.recordPlay(
      songId: 'song-0002',
      timestamp: DateTime.now(),
      playTimeMs: 10000,
    );
    final List<SongView> page = await service.songsPage(
      sort: SongSort.mostPlayed,
    );
    expect(
      page.map((SongView v) => v.id).toList(),
      <String>['song-0001', 'song-0002', 'song-0000'],
    );
  });

  test('tabel kosong mengembalikan halaman kosong', () async {
    expect(await service.songsPage(), isEmpty);
    expect(await service.favoriteSongsPage(), isEmpty);
    expect(await service.historyPage(), isEmpty);
    expect(await service.artistsPage(), isEmpty);
    expect(await service.albumsPage(), isEmpty);
    expect(await service.playlistsPage(), isEmpty);
  });

  test('kelipatan persis 50: halaman ketiga kosong', () async {
    await seedSongs(service, 100);
    final List<SongView> page1 = await service.songsPage();
    final List<SongView> page2 = await service.songsPage(after: page1.last);
    expect(page1, hasLength(50));
    expect(page2, hasLength(50));
    expect(await service.songsPage(after: page2.last), isEmpty);
  });

  test('riwayat 60 entri terbagi 50/10, terbaru dulu', () async {
    await service.upsertSong(
      testSong('s1'),
      artistNames: const <String>[],
      addToLibrary: true,
    );
    final DateTime base = DateTime(2026, 11, 1);
    await db.batch((Batch batch) {
      batch.insertAll(
        db.playEvents,
        List<PlayEventsCompanion>.generate(
          60,
          (int i) => PlayEventsCompanion.insert(
            songId: 's1',
            timestamp: base.add(Duration(minutes: i)),
            playTimeMs: 12000,
          ),
        ),
      );
    });
    final List<PlayHistoryEntry> page1 = await service.historyPage();
    final List<PlayHistoryEntry> page2 = await service.historyPage(
      after: page1.last,
    );
    expect(page1, hasLength(50));
    expect(page2, hasLength(10));
    expect(
      page1.first.event.timestamp,
      base.add(const Duration(minutes: 59)),
    );
    expect(page2.last.event.timestamp, base);
  });
}
