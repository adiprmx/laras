/// Tes riwayat pencarian (PRD B1.3): batas 100, dedup tanpa membedakan
/// kapitalisasi, hapus per item dan hapus semua, saran awalan lokal.
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

  test('menyimpan 100 query terakhir, query lama terbuang', () async {
    for (int i = 0; i < 105; i++) {
      await service.addSearchQuery('query $i');
    }
    final List<String> recent = await service.recentSearches(limit: 200);
    expect(recent.length, 100);
    expect(recent.first, 'query 104');
    expect(recent.last, 'query 5');
    expect(recent, isNot(contains('query 4')));
  });

  test('query sama (beda kapital) tidak diduplikasi, naik ke atas', () async {
    await service.addSearchQuery('Queen');
    await service.addSearchQuery('noah');
    await service.addSearchQuery('queen');
    final List<String> recent = await service.recentSearches();
    expect(recent, <String>['queen', 'noah']);
  });

  test('query kosong atau spasi tidak disimpan', () async {
    await service.addSearchQuery('   ');
    await service.addSearchQuery('');
    expect(await service.recentSearches(), isEmpty);
  });

  test('hapus satu query, yang lain tetap ada', () async {
    await service.addSearchQuery('noah');
    await service.addSearchQuery('queen');
    await service.deleteSearchQuery('noah');
    expect(await service.recentSearches(), <String>['queen']);
  });

  test('hapus semua mengosongkan riwayat', () async {
    await service.addSearchQuery('noah');
    await service.addSearchQuery('queen');
    await service.clearSearchHistory();
    expect(await service.recentSearches(), isEmpty);
  });

  test('saran awalan lokal: cocok huruf awal, terbaru dulu', () async {
    await service.addSearchQuery('noah');
    await service.addSearchQuery('noah semua tentang kita');
    await service.addSearchQuery('queen');
    await service.addSearchQuery('nora');
    final List<String> matches = await service.searchHistoryMatching('No');
    expect(matches, <String>['nora', 'noah semua tentang kita', 'noah']);
  });

  test('karakter khusus LIKE dibaca harfiah, bukan wildcard', () async {
    await service.addSearchQuery('100%');
    await service.addSearchQuery('100x');
    final List<String> matches = await service.searchHistoryMatching('100%');
    expect(matches, <String>['100%']);
  });
}
