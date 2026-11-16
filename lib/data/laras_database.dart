/// Database Laras: drift di atas SQLite, skema v3.
///
/// Riwayat skema:
/// - v1 (P3): 15 tabel + FTS5.
/// - v2 (P5): `download_jobs` mendapat kolom `quality` (nullable),
///   `attempts` (default 0), dan `createdAt` (nullable) — PRD B3.2.
/// - v3 (P6): `songs` mendapat kolom `unplayable` (default false) +
///   indeks `songs_unplayable_idx` — PRD B4.7.
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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2 && to >= 2) {
        // v1 -> v2 (P5): kolom baru download_jobs. Ketiganya aman
        // ditambahkan ke tabel berisi data: quality dan createdAt
        // nullable, attempts punya default 0.
        await m.addColumn(downloadJobs, downloadJobs.quality);
        await m.addColumn(downloadJobs, downloadJobs.attempts);
        await m.addColumn(downloadJobs, downloadJobs.createdAt);
      }
      if (from < 3 && to >= 3) {
        // v2 -> v3 (P6): flag "tidak bisa diputar" di songs. Aman
        // ditambahkan ke tabel berisi data (default false = semua lagu
        // lama dianggap bisa diputar sampai terbukti sebaliknya).
        await m.addColumn(songs, songs.unplayable);
        await m.createIndex(songsUnplayableIdx);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
}
