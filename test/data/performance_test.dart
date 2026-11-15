/// Tes performa: waktu impor 1.000 lagu + query halaman pertama + cari.
///
/// Angka yang dicetak adalah hasil ukur nyata di mesin yang menjalankan
/// tes (database in-memory), bukan estimasi. Batas assert longgar
/// (detik, bukan milidetik): tes ini alat ukur, bukan patokan keras.
library;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
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

  test(
    'impor 1.000 lagu + query halaman pertama + pencarian FTS5',
    () async {
      final List<SongImport> items = List<SongImport>.generate(1000, (int i) {
        return SongImport(
          song: SongsCompanion(
            id: Value<String>('perf-${i.toString().padLeft(4, '0')}'),
            title: Value<String>(
              'Lagu Performa ${i.toString().padLeft(4, '0')}',
            ),
            durationSeconds: const Value<int?>(200),
          ),
          artistNames: <String>['Artis ${i % 50}'],
        );
      });

      final Stopwatch importWatch = Stopwatch()..start();
      await service.importSongs(items);
      importWatch.stop();
      debugPrint(
        'PERF impor 1.000 lagu: ${importWatch.elapsedMilliseconds} ms',
      );
      expect((await service.libraryCounts()).songs, 1000);

      final Stopwatch pageWatch = Stopwatch()..start();
      final List<SongView> page = await service.songsPage();
      pageWatch.stop();
      debugPrint(
        'PERF query halaman pertama (50 lagu): '
        '${pageWatch.elapsedMilliseconds} ms',
      );
      expect(page, hasLength(50));

      final Stopwatch ftsWatch = Stopwatch()..start();
      final LocalSearchResults results = await service.searchLocal('performa 0420');
      ftsWatch.stop();
      debugPrint(
        'PERF pencarian FTS5: ${ftsWatch.elapsedMilliseconds} ms, '
        '${results.songs.length} lagu ditemukan',
      );
      expect(results.songs.map((SongView v) => v.id), <String>['perf-0420']);

      // Batas kewarasan yang longgar: impor massal tidak boleh lebih
      // dari satu menit, query halaman dan pencarian di bawah 5 detik.
      expect(importWatch.elapsed, lessThan(const Duration(seconds: 60)));
      expect(pageWatch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(ftsWatch.elapsed, lessThan(const Duration(seconds: 5)));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
