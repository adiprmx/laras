/// Tes pencarian lokal FTS5: judul, artis, ranking, awalan, dan keamanan.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';

import 'test_database.dart';

void main() {
  late LarasDatabase db;
  late LibraryService service;

  setUp(() async {
    (db, service) = createTestLibrary();
    await service.upsertSong(
      testSong('s1', title: 'Semua Tentang Kita'),
      artistNames: const <String>['Andi'],
      addToLibrary: true,
    );
    await service.upsertSong(
      testSong('s2', title: 'Rahasia Hati'),
      artistNames: const <String>['Budi'],
      addToLibrary: true,
    );
    await service.upsertSong(
      testSong('s3', title: 'Cinta'),
      artistNames: const <String>['Citra'],
      addToLibrary: true,
    );
    await service.upsertSong(
      testSong('s4', title: 'Cinta dan Air Mata dan Hujan dan Rindu dan Senja'),
      artistNames: const <String>['Dedi'],
      addToLibrary: true,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('mencari judul menemukan lagu yang cocok', () async {
    final LocalSearchResults results = await service.searchLocal('tentang');
    expect(results.songs.map((SongView v) => v.id), <String>['s1']);
  });

  test('mencari nama artis menemukan lagu dan artisnya', () async {
    final LocalSearchResults results = await service.searchLocal('budi');
    expect(results.songs.map((SongView v) => v.id), <String>['s2']);
    expect(results.artists.map((Artist a) => a.name), <String>['Budi']);
  });

  test('ketikan sebagian menemukan hasil lewat awalan', () async {
    final LocalSearchResults results = await service.searchLocal('sem');
    expect(
      results.songs.map((SongView v) => v.id),
      contains('s1'),
    );
  });

  test('beberapa kata berarti AND: semua kata harus cocok', () async {
    final LocalSearchResults results = await service.searchLocal('semua kita');
    expect(results.songs.map((SongView v) => v.id), <String>['s1']);
  });

  test('bila AND kosong, OR dipakai sebagai cadangan', () async {
    // Tidak ada lagu yang mengandung "tentang" DAN "hati" sekaligus.
    final LocalSearchResults results = await service.searchLocal('tentang hati');
    expect(
      results.songs.map((SongView v) => v.id).toSet(),
      <String>{'s1', 's2'},
    );
  });

  test('judul pendek yang sama persis berperingkat lebih tinggi (bm25)', () async {
    final LocalSearchResults results = await service.searchLocal('cinta');
    expect(results.songs, hasLength(2));
    expect(
      results.songs.first.id,
      's3',
      reason: 'judul "Cinta" (1 kata) harus berperingkat di atas judul panjang',
    );
  });

  test('karakter khusus FTS5 tidak melempar dan tidak merusak pencarian', () async {
    final LocalSearchResults results = await service.searchLocal(
      'cinta " (uji) : ^ + - *',
    );
    expect(results.songs.map((SongView v) => v.id).toSet(), <String>{'s3', 's4'});
  });

  test('query kosong atau hanya karakter khusus mengembalikan hasil kosong', () async {
    expect((await service.searchLocal('')).isEmpty, isTrue);
    expect((await service.searchLocal('   ')).isEmpty, isTrue);
    expect((await service.searchLocal('!!!???')).isEmpty, isTrue);
  });

  test('lagu yang hanya diputar (bukan Library) ikut ditemukan', () async {
    await service.upsertSong(
      testSong('s5', title: 'Lagu Pinggir Jalan'),
      artistNames: const <String>['Eko'],
    );
    final LocalSearchResults results = await service.searchLocal('pinggir');
    expect(results.songs.map((SongView v) => v.id), <String>['s5']);
  });

  test('rebuildFts memulihkan indeks setelah tabel FTS dikosongkan', () async {
    await db.customStatement('DELETE FROM library_search');
    expect((await service.searchLocal('tentang')).isEmpty, isTrue);

    await service.rebuildFts();

    final LocalSearchResults results = await service.searchLocal('tentang');
    expect(results.songs.map((SongView v) => v.id), <String>['s1']);
    final LocalSearchResults artists = await service.searchLocal('andi');
    expect(artists.artists.map((Artist a) => a.name), <String>['Andi']);
  });

  test('judul yang diubah ikut berubah di hasil pencarian', () async {
    await service.upsertSong(
      testSong('s1', title: 'Judul Sama Sekali Baru'),
      artistNames: const <String>['Andi'],
    );
    expect((await service.searchLocal('tentang')).isEmpty, isTrue);
    final LocalSearchResults results = await service.searchLocal('baru');
    expect(results.songs.map((SongView v) => v.id), <String>['s1']);
  });
}
