/// Tes playlist: CRUD, tambah/hapus lagu, urutan, validasi.
library;

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

  Future<void> seedThreeSongs() async {
    await service.upsertSong(
      testSong('s1', title: 'Lagu Satu'),
      artistNames: const <String>['Andi'],
      addToLibrary: true,
    );
    await service.upsertSong(
      testSong('s2', title: 'Lagu Dua'),
      artistNames: const <String>['Budi'],
      addToLibrary: true,
    );
    await service.upsertSong(
      testSong('s3', title: 'Lagu Tiga'),
      artistNames: const <String>['Citra'],
      addToLibrary: true,
    );
  }

  test('buat, baca, ubah nama dan deskripsi, lalu hapus playlist', () async {
    final int id = await service.createPlaylist(
      'Campuran',
      description: 'Lagu-lagu pilihan',
    );
    final Playlist created = (await service.playlistById(id))!;
    expect(created.name, 'Campuran');
    expect(created.description, 'Lagu-lagu pilihan');

    await service.renamePlaylist(id, 'Campuran Baru');
    await service.updatePlaylistDescription(id, null);
    final Playlist renamed = (await service.playlistById(id))!;
    expect(renamed.name, 'Campuran Baru');
    expect(renamed.description, isNull);

    await service.deletePlaylist(id);
    expect(await service.playlistById(id), isNull);
  });

  test('validasi nama dan deskripsi playlist', () async {
    await expectLater(
      () => service.createPlaylist('   '),
      throwsArgumentError,
    );
    await expectLater(
      () => service.createPlaylist('x' * 101),
      throwsArgumentError,
    );
    await expectLater(
      () => service.createPlaylist('Nama', description: 'y' * 501),
      throwsArgumentError,
    );
    final int id = await service.createPlaylist('Oke');
    await expectLater(
      () => service.renamePlaylist(id, ''),
      throwsArgumentError,
    );
    await expectLater(
      () => service.updatePlaylistDescription(id, 'z' * 501),
      throwsArgumentError,
    );
  });

  test('tambah lagu mengisi posisi berurutan dan memasukkan ke Library', () async {
    await service.upsertSong(testSong('s1'), artistNames: const <String>[]);
    expect((await service.songById('s1'))!.song.inLibrary, isFalse);
    final int id = await service.createPlaylist('P');

    expect(await service.addSongToPlaylist(id, 's1'), isTrue);
    expect((await service.songById('s1'))!.song.inLibrary, isTrue);

    await service.upsertSong(testSong('s2'), artistNames: const <String>[]);
    await service.addSongToPlaylist(id, 's2');
    final List<PlaylistSongEntry> entries = await service.playlistSongsPage(id);
    expect(entries.map((PlaylistSongEntry e) => e.position), <int>[0, 1]);
    expect(
      entries.map((PlaylistSongEntry e) => e.song.id),
      <String>['s1', 's2'],
    );
  });

  test('lagu yang sama tidak bisa ditambahkan dua kali', () async {
    await seedThreeSongs();
    final int id = await service.createPlaylist('P');
    expect(await service.addSongToPlaylist(id, 's1'), isTrue);
    expect(await service.addSongToPlaylist(id, 's1'), isFalse);
    expect(
      (await service.playlistsPage()).single.songCount,
      1,
    );
  });

  test('addSongsToPlaylist melewati duplikat dan menghitung yang masuk', () async {
    await seedThreeSongs();
    final int id = await service.createPlaylist('P');
    await service.addSongToPlaylist(id, 's1');
    final int added = await service.addSongsToPlaylist(
      id,
      <String>['s1', 's2', 's3'],
    );
    expect(added, 2);
    final List<PlaylistSongEntry> entries = await service.playlistSongsPage(id);
    expect(
      entries.map((PlaylistSongEntry e) => e.song.id),
      <String>['s1', 's2', 's3'],
    );
  });

  test('hapus lagu merapatkan posisi tanpa lubang', () async {
    await seedThreeSongs();
    final int id = await service.createPlaylist('P');
    await service.addSongsToPlaylist(id, <String>['s1', 's2', 's3']);

    await service.removeSongFromPlaylist(id, 's2');

    final List<PlaylistSongEntry> entries = await service.playlistSongsPage(id);
    expect(
      entries.map((PlaylistSongEntry e) => e.song.id),
      <String>['s1', 's3'],
    );
    expect(entries.map((PlaylistSongEntry e) => e.position), <int>[0, 1]);
  });

  test('pindah lagu mengubah urutan dan posisi tetap rapat', () async {
    await seedThreeSongs();
    final int id = await service.createPlaylist('P');
    await service.addSongsToPlaylist(id, <String>['s1', 's2', 's3']);

    await service.moveSongInPlaylist(id, 's3', 0);

    final List<PlaylistSongEntry> entries = await service.playlistSongsPage(id);
    expect(
      entries.map((PlaylistSongEntry e) => e.song.id),
      <String>['s3', 's1', 's2'],
    );
    expect(entries.map((PlaylistSongEntry e) => e.position), <int>[0, 1, 2]);

    // Posisi di luar rentang dijepit ke ujung.
    await service.moveSongInPlaylist(id, 's3', 99);
    final List<PlaylistSongEntry> after = await service.playlistSongsPage(id);
    expect(after.last.song.id, 's3');

    // Lagu yang tidak ada di playlist diabaikan, bukan error.
    await service.moveSongInPlaylist(id, 'tidak-ada', 0);
    expect(
      (await service.playlistSongsPage(id)).map(
        (PlaylistSongEntry e) => e.song.id,
      ),
      <String>['s1', 's2', 's3'],
    );
  });

  test('hapus playlist ikut menghapus isinya, bukan lagunya', () async {
    await seedThreeSongs();
    final int id = await service.createPlaylist('P');
    await service.addSongsToPlaylist(id, <String>['s1', 's2']);
    await service.deletePlaylist(id);

    expect(await service.playlistSongsPage(id), isEmpty);
    expect(await service.songById('s1'), isNotNull);
    expect((await service.libraryCounts()).songs, 3);
  });

  test('playlist 60 lagu terbagi 50/10', () async {
    await seedSongs(service, 60);
    final int id = await service.createPlaylist('Besar');
    final List<String> ids = List<String>.generate(
      60,
      (int i) => 'song-${i.toString().padLeft(4, '0')}',
    );
    await service.addSongsToPlaylist(id, ids);

    final List<PlaylistSongEntry> page1 = await service.playlistSongsPage(id);
    final List<PlaylistSongEntry> page2 = await service.playlistSongsPage(
      id,
      after: page1.last,
    );
    expect(page1, hasLength(50));
    expect(page2, hasLength(10));
    expect(
      (await service.playlistsPage()).single.songCount,
      60,
    );
  });

  test('playlistSongsForPlayback mulai dari lagu yang diminta, dibatasi 200', () async {
    await seedSongs(service, 5);
    final int id = await service.createPlaylist('P');
    final List<String> ids = List<String>.generate(
      5,
      (int i) => 'song-${i.toString().padLeft(4, '0')}',
    );
    await service.addSongsToPlaylist(id, ids);

    final List<SongView> fromStart = await service.playlistSongsForPlayback(id);
    expect(fromStart, hasLength(5));
    final List<SongView> fromMiddle = await service.playlistSongsForPlayback(
      id,
      startSongId: 'song-0002',
    );
    expect(
      fromMiddle.map((SongView v) => v.id),
      <String>['song-0002', 'song-0003', 'song-0004'],
    );
    final List<SongView> limited = await service.playlistSongsForPlayback(
      id,
      limit: 2,
    );
    expect(limited, hasLength(2));
  });

  test('daftar playlist terurut terakhir diubah dulu', () async {
    final int first = await service.createPlaylist('Pertama');
    final int second = await service.createPlaylist('Kedua');
    List<PlaylistWithCount> page = await service.playlistsPage();
    expect(
      page.map((PlaylistWithCount p) => p.playlist.id),
      <int>[second, first],
    );

    // Mengubah playlist pertama menaikkannya ke atas. Jeda 1,1 detik
    // memastikan cap waktu ubah berbeda: drift menyimpan DateTime
    // sebagai DETIK Unix, jadi jeda di bawah 1 detik bisa berbagi detik
    // yang sama dengan pembuatan.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await service.renamePlaylist(first, 'Pertama (baru)');
    page = await service.playlistsPage();
    expect(
      page.map((PlaylistWithCount p) => p.playlist.id),
      <int>[first, second],
    );
  });
}
