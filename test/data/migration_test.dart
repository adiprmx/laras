/// Tes migrasi skema v1.
///
/// Skema v1 adalah skema pertama: tidak ada langkah migrasi antar versi
/// (file `test/generated_migrations.dart` memang kosong). Yang diuji di
/// sini adalah janji migrasi yang paling penting: database yang dibuat
/// dari nol lewat `onCreate` harus PERSIS sama dengan skema yang
/// diharapkan kode hasil generate (tabel, kolom, batasan, indeks,
/// termasuk tabel virtual FTS5). Bila ada yang meleset, tes ini gagal
/// dengan [SchemaMismatch] sebelum bug menyentuh perangkat.
///
/// Saat skema v2 tiba, tes ini diperluas dengan `SchemaVerifier` +
/// `GeneratedHelper` (pola standar drift) untuk menguji langkah
/// naik versi beserta datanya.
library;

import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';

void main() {
  test('database baru sesuai dengan skema v1 yang diharapkan kode', () async {
    final LarasDatabase db = LarasDatabase(NativeDatabase.memory());
    try {
      // Memicu onCreate (membuat semua tabel + FTS5 + indeks).
      await db.customSelect('SELECT 1').get();
      // Validasi penuh: tabel, kolom, batasan, indeks, tabel virtual.
      await db.validateDatabaseSchema();
    } finally {
      await db.close();
    }
  });

  test('schemaVersion adalah 1', () async {
    final LarasDatabase db = LarasDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 1);
    await db.close();
  });
}
