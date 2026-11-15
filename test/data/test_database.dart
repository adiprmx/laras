/// Helper tes lapisan data: database drift in-memory + [LibraryService].
///
/// Setiap tes memakai database baru (ditutup di `tearDown` pemanggil)
/// supaya tidak ada state bocor antar tes. Database in-memory memakai
/// SQLite asli lewat FFI, jadi perilaku SQL-nya (termasuk FTS5 dan
/// foreign key) sama dengan di perangkat.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:laras/data/database.dart';

/// Buat database in-memory baru beserta service-nya.
///
/// Mengembalikan record `(db, service)`; pemanggil wajib menutup `db`
/// sesudah tes selesai.
(LarasDatabase, LibraryService) createTestLibrary() {
  final LarasDatabase db = LarasDatabase(NativeDatabase.memory());
  return (db, LibraryService(db));
}

/// Companion lagu uji dengan id [id] dan judul [title].
///
/// Memakai konstruktor default (bukan `.insert`): tanggal tambah/ubah
/// diisi [LibraryService.upsertSong], sama seperti jalur produksi.
SongsCompanion testSong(
  String id, {
  String? title,
  int? durationSeconds,
}) {
  return SongsCompanion(
    id: Value<String>(id),
    title: Value<String>(title ?? 'Lagu $id'),
    durationSeconds: Value<int?>(durationSeconds ?? 180),
  );
}

/// Simpan [count] lagu uji ke library (`in_library = 1`), judul
/// `Lagu 000`, `Lagu 001`, ... — dipakai tes pagination dan performa.
/// Mengembalikan daftar id dalam urutan dibuat.
Future<List<String>> seedSongs(
  LibraryService service,
  int count, {
  String prefix = 'song',
}) async {
  final List<String> ids = <String>[];
  final List<SongImport> items = <SongImport>[];
  for (int i = 0; i < count; i++) {
    final String id = '$prefix-${i.toString().padLeft(4, '0')}';
    ids.add(id);
    items.add(
      SongImport(
        song: SongsCompanion(
          id: Value<String>(id),
          title: Value<String>('Lagu ${i.toString().padLeft(3, '0')}'),
          durationSeconds: const Value<int?>(180),
        ),
        artistNames: <String>['Artis ${i % 10}'],
      ),
    );
  }
  await service.importSongs(items);
  return ids;
}
