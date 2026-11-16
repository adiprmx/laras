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
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';

import '../schema.dart';

void main() {
  test('database baru sesuai dengan skema v2 yang diharapkan kode', () async {
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

  test('schemaVersion adalah 2', () async {
    final LarasDatabase db = LarasDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 2);
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
}
