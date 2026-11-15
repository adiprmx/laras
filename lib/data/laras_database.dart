/// Database Laras: drift di atas SQLite, skema v1.
///
/// File ini murni Dart (tanpa import Flutter) supaya `drift_dev schema
/// dump` bisa menjalankannya di VM polos. Pembukaan koneksi produksi
/// (path file + background isolate) tinggal di database_connection.dart;
/// tes memakai `LarasDatabase(NativeDatabase.memory())`.
///
/// Foreign key aktif lewat `PRAGMA foreign_keys = ON` di [beforeOpen].
/// Jurnal WAL dipakai di file nyata supaya baca dari UI tidak mengunci
/// tulis dari isolate latar (di database in-memory, WAL tidak berlaku
/// dan pragma-nya diabaikan SQLite).
library;

import 'package:drift/drift.dart';

import 'tables.dart';

part 'laras_database.g.dart';

@DriftDatabase(
  tables: <Type>[
    Songs,
    Albums,
    Artists,
    SongArtists,
    AlbumArtists,
    Playlists,
    PlaylistSongs,
    Formats,
    Lyrics,
    PlayEvents,
    SearchHistory,
    QueueItems,
    LocalItems,
    CacheEntries,
    DownloadJobs,
  ],
  include: <String>{'schema.drift'},
)
class LarasDatabase extends _$LarasDatabase {
  LarasDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
}
