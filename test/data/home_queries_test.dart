/// Tes kueri beranda P4: lagu yang baru diputar (tanpa duplikat,
/// diurutkan putaran terakhir terbaru dulu).
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

  Future<void> seedAndPlay() async {
    await service.upsertSong(testSong('vid1', title: 'Satu'));
    await service.upsertSong(testSong('vid2', title: 'Dua'));
    await service.upsertSong(testSong('vid3', title: 'Tiga'));
    // Cap waktu detik berbeda supaya urutan deterministik (drift
    // menyimpan DateTime sebagai detik Unix).
    await service.recordPlay(
      songId: 'vid1',
      timestamp: DateTime(2026, 11, 16, 10, 0, 1),
      playTimeMs: 60000,
    );
    await service.recordPlay(
      songId: 'vid2',
      timestamp: DateTime(2026, 11, 16, 10, 0, 2),
      playTimeMs: 60000,
    );
    await service.recordPlay(
      songId: 'vid1',
      timestamp: DateTime(2026, 11, 16, 10, 0, 3),
      playTimeMs: 60000,
    );
  }

  test('kosong bila belum ada riwayat putar', () async {
    await service.upsertSong(testSong('vid1', title: 'Satu'));
    expect(await service.recentPlayedSongs(), isEmpty);
  });

  test('tiap lagu tampil sekali, di posisi putaran terakhirnya', () async {
    await seedAndPlay();
    final List<SongView> recent = await service.recentPlayedSongs();
    expect(recent.map((SongView v) => v.id).toList(), <String>['vid1', 'vid2']);
  });

  test('batas limit dipatuhi', () async {
    await seedAndPlay();
    final List<SongView> recent = await service.recentPlayedSongs(limit: 1);
    expect(recent.map((SongView v) => v.id).toList(), <String>['vid1']);
  });
}
