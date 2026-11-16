/// Tes migrasi skema.
///
/// - Skema v1 adalah skema pertama (P3): database yang dibuat dari nol
///   lewat `onCreate` harus PERSIS sama dengan skema yang diharapkan kode
///   hasil generate.
/// - Skema v2 (P5): `download_jobs` mendapat kolom `quality`, `attempts`,
///   dan `createdAt`. Tes memakai `SchemaVerifier` + `GeneratedHelper`
///   (pola standar drift): database v1 diisi data lewat SQL mentah, lalu
///   dibuka sebagai [LarasDatabase] sehingga `onUpgrade` ASLI berjalan,
///   dan datanya diverifikasi utuh sesudah migrasi.
/// - Skema v3 (P6): `songs` mendapat kolom `unplayable` (default false)
///   + indeks `songs_unplayable_idx`.
/// - Skema v4 (P7): tabel baru `playback_state` (satu baris, id 1) untuk
///   restore antrean + posisi (MUST #3). Tabel baru kosong; data lama
///   tidak tersentuh.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';

import '../schema.dart';

void main() {
  test('database baru sesuai dengan skema v4 yang diharapkan kode', () async {
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

  test('schemaVersion adalah 4', () async {
    final LarasDatabase db = LarasDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 4);
    await db.close();
  });

  test('migrasi v1 -> v2 mempertahankan data download_jobs', () async {
    final SchemaVerifier verifier = SchemaVerifier(GeneratedHelper());
    final InitializedSchema schema = await verifier.schemaAt(1);
    // Data v1 lewat SQL mentah (skema v1 tidak punya kolom quality,
    // attempts, createdAt). Timestamp drift adalah detik Unix.
    schema.rawDatabase.execute(
      'INSERT INTO songs (id, title, duration_seconds, liked, '
      'total_play_time_ms, in_library, date_added, date_modified, '
      "download_state) VALUES ('song-1', 'Lagu Satu', 180, 0, 0, 1, "
      '1792000000, 1792000000, 1)',
    );
    schema.rawDatabase.execute(
      'INSERT INTO download_jobs (song_id, status, bytes_downloaded, '
      "total_bytes, updated_at) VALUES ('song-1', 1, 12345, 4000000, "
      '1792000000)',
    );
    final LarasDatabase db = LarasDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 2);
      final DownloadJob job = await (db.select(
        db.downloadJobs,
      )..where((DownloadJobs j) => j.songId.equals('song-1'))).getSingle();
      expect(job.status, DownloadJobStatus.running);
      expect(job.bytesDownloaded, 12345);
      expect(job.totalBytes, 4000000);
      // Kolom baru: default/nilai kosong, bukan nilai karangan.
      expect(job.quality, null);
      expect(job.attempts, 0);
      expect(job.createdAt, null);
    } finally {
      await db.close();
    }
  });

  test('kolom baru download_jobs bisa ditulis sesudah migrasi', () async {
    final SchemaVerifier verifier = SchemaVerifier(GeneratedHelper());
    final DatabaseConnection connection = await verifier.startAt(1);
    final LarasDatabase db = LarasDatabase(connection);
    try {
      await verifier.migrateAndValidate(db, 2);
      final DateTime now = DateTime.now();
      await db
          .into(db.songs)
          .insert(
            SongsCompanion.insert(
              id: 'song-2',
              title: 'Lagu Dua',
              dateAdded: now,
              dateModified: now,
            ),
          );
      await db
          .into(db.downloadJobs)
          .insert(
            DownloadJobsCompanion.insert(
              songId: 'song-2',
              status: DownloadJobStatus.queued,
              quality: const Value<int?>(251),
              attempts: const Value<int>(1),
              createdAt: Value<DateTime?>(now),
              updatedAt: now,
            ),
          );
      final DownloadJob job = await (db.select(
        db.downloadJobs,
      )..where((DownloadJobs j) => j.songId.equals('song-2'))).getSingle();
      expect(job.quality, 251);
      expect(job.attempts, 1);
      expect(job.createdAt != null, isTrue);
    } finally {
      await db.close();
    }
  });

  test('migrasi v2 -> v3 mempertahankan lagu, unplayable default false',
      () async {
    final SchemaVerifier verifier = SchemaVerifier(GeneratedHelper());
    final InitializedSchema schema = await verifier.schemaAt(2);
    schema.rawDatabase.execute(
      'INSERT INTO songs (id, title, duration_seconds, liked, '
      'total_play_time_ms, in_library, date_added, date_modified, '
      "download_state) VALUES ('song-3', 'Lagu Tiga', 200, 0, 0, 1, "
      '1792000000, 1792000000, 0)',
    );
    final LarasDatabase db = LarasDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 3);
      final Song song = await (db.select(
        db.songs,
      )..where((Songs s) => s.id.equals('song-3'))).getSingle();
      expect(song.title, 'Lagu Tiga');
      expect(song.durationSeconds, 200);
      // Lagu lama dianggap bisa diputar sampai terbukti sebaliknya.
      expect(song.unplayable, isFalse);
      // Indeks v3 ada.
      final List<QueryRow> idx = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND "
            "name = 'songs_unplayable_idx'",
          )
          .get();
      expect(idx, hasLength(1));
    } finally {
      await db.close();
    }
  });

  test('kolom unplayable bisa ditulis sesudah migrasi v2 -> v3', () async {
    final SchemaVerifier verifier = SchemaVerifier(GeneratedHelper());
    final DatabaseConnection connection = await verifier.startAt(2);
    final LarasDatabase db = LarasDatabase(connection);
    try {
      await verifier.migrateAndValidate(db, 3);
      final DateTime now = DateTime.now();
      await db
          .into(db.songs)
          .insert(
            SongsCompanion.insert(
              id: 'song-4',
              title: 'Lagu Empat',
              dateAdded: now,
              dateModified: now,
              unplayable: const Value<bool>(true),
            ),
          );
      final Song song = await (db.select(
        db.songs,
      )..where((Songs s) => s.id.equals('song-4'))).getSingle();
      expect(song.unplayable, isTrue);
    } finally {
      await db.close();
    }
  });

  test('migrasi v1 -> v3 langsung (loncat versi) tetap benar', () async {
    final SchemaVerifier verifier = SchemaVerifier(GeneratedHelper());
    final InitializedSchema schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      'INSERT INTO songs (id, title, duration_seconds, liked, '
      'total_play_time_ms, in_library, date_added, date_modified, '
      "download_state) VALUES ('song-5', 'Lagu Lima', 150, 0, 0, 1, "
      '1792000000, 1792000000, 0)',
    );
    schema.rawDatabase.execute(
      'INSERT INTO download_jobs (song_id, status, bytes_downloaded, '
      "total_bytes, updated_at) VALUES ('song-5', 0, 0, 3000000, "
      '1792000000)',
    );
    final LarasDatabase db = LarasDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 3);
      final Song song = await (db.select(
        db.songs,
      )..where((Songs s) => s.id.equals('song-5'))).getSingle();
      expect(song.unplayable, isFalse);
      final DownloadJob job = await (db.select(
        db.downloadJobs,
      )..where((DownloadJobs j) => j.songId.equals('song-5'))).getSingle();
      expect(job.attempts, 0);
      expect(job.quality, null);
    } finally {
      await db.close();
    }
  });

  test('migrasi v3 -> v4 mempertahankan lagu + antrean, tabel baru kosong',
      () async {
    final SchemaVerifier verifier = SchemaVerifier(GeneratedHelper());
    final InitializedSchema schema = await verifier.schemaAt(3);
    schema.rawDatabase.execute(
      'INSERT INTO songs (id, title, duration_seconds, liked, '
      'total_play_time_ms, in_library, date_added, date_modified, '
      "download_state, unplayable) VALUES ('song-6', 'Lagu Enam', 200, "
      '0, 0, 1, 1792000000, 1792000000, 0, 0)',
    );
    schema.rawDatabase.execute(
      "INSERT INTO queue_items (position, song_id) VALUES (0, 'song-6')",
    );
    final LarasDatabase db = LarasDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 4);
      final Song song = await (db.select(
        db.songs,
      )..where((Songs s) => s.id.equals('song-6'))).getSingle();
      expect(song.title, 'Lagu Enam');
      final List<QueueItem> items = await db.select(db.queueItems).get();
      expect(items, hasLength(1));
      expect(items.single.songId, 'song-6');
      // Tabel baru ada dan kosong (belum ada status tersimpan).
      final List<PlaybackStateData> states = await db
          .select(db.playbackState)
          .get();
      expect(states, isEmpty);
    } finally {
      await db.close();
    }
  });

  test('tabel playback_state bisa ditulis sesudah migrasi v3 -> v4',
      () async {
    final SchemaVerifier verifier = SchemaVerifier(GeneratedHelper());
    final DatabaseConnection connection = await verifier.startAt(3);
    final LarasDatabase db = LarasDatabase(connection);
    try {
      await verifier.migrateAndValidate(db, 4);
      await db
          .into(db.playbackState)
          .insert(
            PlaybackStateCompanion.insert(
              id: const Value<int>(1),
              currentIndex: const Value<int>(2),
              positionMs: const Value<int>(45000),
              shuffleEnabled: const Value<bool>(true),
              repeatMode: const Value<int>(1),
              updatedAt: DateTime.now(),
            ),
          );
      final PlaybackStateData state = await (db.select(
        db.playbackState,
      )..where((PlaybackState t) => t.id.equals(1))).getSingle();
      expect(state.currentIndex, 2);
      expect(state.positionMs, 45000);
      expect(state.shuffleEnabled, isTrue);
      expect(state.repeatMode, 1);
    } finally {
      await db.close();
    }
  });

  test('migrasi v1 -> v4 langsung (loncat versi) tetap benar', () async {
    final SchemaVerifier verifier = SchemaVerifier(GeneratedHelper());
    final InitializedSchema schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      'INSERT INTO songs (id, title, duration_seconds, liked, '
      'total_play_time_ms, in_library, date_added, date_modified, '
      "download_state) VALUES ('song-7', 'Lagu Tujuh', 150, 0, 0, 1, "
      '1792000000, 1792000000, 0)',
    );
    schema.rawDatabase.execute(
      'INSERT INTO download_jobs (song_id, status, bytes_downloaded, '
      "total_bytes, updated_at) VALUES ('song-7', 0, 0, 3000000, "
      '1792000000)',
    );
    final LarasDatabase db = LarasDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 4);
      final Song song = await (db.select(
        db.songs,
      )..where((Songs s) => s.id.equals('song-7'))).getSingle();
      expect(song.unplayable, isFalse);
      final DownloadJob job = await (db.select(
        db.downloadJobs,
      )..where((DownloadJobs j) => j.songId.equals('song-7'))).getSingle();
      expect(job.attempts, 0);
      expect(job.quality, null);
      final List<QueryRow> tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND "
            "name = 'playback_state'",
          )
          .get();
      expect(tables, hasLength(1));
    } finally {
      await db.close();
    }
  });
}
