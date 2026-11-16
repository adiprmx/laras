/// Tes regresi R2-L3: `SongView.toTrack` tidak pernah memakai nama file
/// dari database mentah — bentuk yang tidak cocok berarti data rusak
/// dan track menjadi streaming (tanpa localPath), bukan membangun path
/// di luar direktori unduhan.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/player/track.dart';

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

  Future<Track> trackForDownloaded(String filePath) async {
    await library.upsertSong(testSong('aaa11111111'), addToLibrary: true);
    await library.markDownloaded(
      songId: 'aaa11111111',
      filePath: filePath,
      fileSizeBytes: 100,
    );
    final SongView? view = await library.songById('aaa11111111');
    return view!.toTrack(downloadsDir: '/tmp/dl');
  }

  group('SongView.toTrack (R2-L3)', () {
    test('filePath sah -> localPath ke file unduhan', () async {
      final Track track = await trackForDownloaded('aaa11111111.opus');
      expect(track.localPath, '/tmp/dl/aaa11111111.opus');
      expect(track.isLocal, isTrue);
    });

    test('filePath traversal -> streaming (tanpa localPath)', () async {
      final Track track = await trackForDownloaded(
        '../../databases/laras.sqlite',
      );
      expect(track.localPath, isNull);
      expect(track.isLocal, isFalse);
    });

    test('filePath dengan slash atau tanpa titik -> streaming', () async {
      final Track slash = await trackForDownloaded('a/b.opus');
      expect(slash.localPath, isNull);
      final Track noDot = await trackForDownloaded('lagu');
      expect(noDot.localPath, isNull);
    });

    test('lagu belum terunduh -> streaming walau filePath terisi', () async {
      await library.upsertSong(testSong('aaa11111111'), addToLibrary: true);
      final SongView? view = await library.songById('aaa11111111');
      final Track track = view!.toTrack(downloadsDir: '/tmp/dl');
      expect(track.localPath, isNull);
    });
  });
}
