/// Skema database Laras v1: 15 tabel (laporan A5 bagian 4).
///
/// Nama tabel dan kolom memakai konvensi drift (camelCase di Dart menjadi
/// snake_case di SQL). Semua timestamp disimpan sebagai INTEGER milidetik
/// sejak epoch lewat kolom `dateTime()` drift.
///
/// Penyimpangan dari desain A5, dengan alasan:
/// - `playlists.description` (TEXT nullable): PRD B4.1 menetapkan deskripsi
///   playlist maks 500 karakter. A5 tidak punya kolom ini.
/// - `liked` dan `in_library` memakai `boolean()` drift, bukan integer
///   mentah. Penyimpanan di SQLite tetap INTEGER 0/1 (ditambah CHECK),
///   tapi Dart mendapat type safety.
/// - Aksi foreign key ditulis eksplisit (A5 diam soal ini): hapus playlist
///   menghapus baris `playlist_songs`-nya, hapus lagu menghapus baris
///   pemetaannya, riwayat, format, lirik, dan job unduhannya; hapus album
///   hanya mengosongkan `songs.album_id`, bukan menghapus lagunya.
library;

import 'package:drift/drift.dart';

/// Status unduhan lagu (`songs.download_state`). Nilai integer-nya adalah
/// bagian dari skema dan tidak boleh diubah urutannya.
abstract final class DownloadState {
  static const int notDownloaded = 0;
  static const int downloading = 1;
  static const int downloaded = 2;
}

/// Status pekerjaan unduhan (`download_jobs.status`). Nilai integer-nya
/// adalah bagian dari skema dan tidak boleh diubah urutannya.
abstract final class DownloadJobStatus {
  static const int queued = 0;
  static const int running = 1;
  static const int paused = 2;
  static const int failed = 3;

  /// Selesai: file sudah di-rename dan lagu ditandai terunduh. Baris
  /// dipertahankan sampai pembersihan 7 hari (PRD B3.2) supaya tab
  /// Unduhan bisa menampilkan kelompok "Selesai".
  static const int completed = 4;
}

/// Satu lagu yang dikenal app, baik dari YouTube Music maupun file lokal.
///
/// `id` adalah videoId YouTube. Lagu masuk Library (`in_library`) saat
/// difavoritkan, ditambahkan ke playlist, atau diunduh; sekadar diputar
/// tidak memasukkan lagu ke Library.
@TableIndex(name: 'songs_title_idx', columns: {#title})
@TableIndex(name: 'songs_library_idx', columns: {#inLibrary, #dateAdded})
@TableIndex(name: 'songs_played_idx', columns: {#inLibrary, #totalPlayTimeMs})
/// Lagu.
///
/// Kolom `unplayable` (P6, B4.7): true bila lagu terbukti tidak bisa
/// diputar dari sumber online (dihapus/privat/dibatasi wilayah, dari
/// playabilityStatus). Lagu terunduh tidak pernah bertanda.
@TableIndex(name: 'songs_unplayable_idx', columns: {#unplayable})
class Songs extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  TextColumn get albumId =>
      text().nullable().references(Albums, #id, onDelete: KeyAction.setNull)();

  IntColumn get durationSeconds => integer().nullable()();

  TextColumn get thumbnailUrl => text().nullable()();

  BoolColumn get liked => boolean().withDefault(const Constant(false))();

  IntColumn get totalPlayTimeMs => integer().withDefault(const Constant(0))();

  BoolColumn get inLibrary => boolean().withDefault(const Constant(false))();

  DateTimeColumn get dateAdded => dateTime()();

  DateTimeColumn get dateModified => dateTime()();

  IntColumn get downloadState =>
      integer().withDefault(const Constant(DownloadState.notDownloaded))();

  /// Path RELATIF terhadap direktori unduhan, bukan path absolut.
  TextColumn get filePath => text().nullable()();

  IntColumn get fileSizeBytes => integer().nullable()();

  DateTimeColumn get downloadedAt => dateTime().nullable()();

  TextColumn get formatId =>
      text().nullable().references(Formats, #id, onDelete: KeyAction.setNull)();

  /// True bila lagu terbukti tidak bisa diputar (P6, B4.7). Default
  /// false; dibersihkan saat satu resolve berhasil.
  BoolColumn get unplayable => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Album YouTube Music.
@TableIndex(name: 'albums_title_idx', columns: {#title})
class Albums extends Table {
  /// browseId album YouTube Music.
  TextColumn get id => text()();

  TextColumn get title => text()();

  IntColumn get year => integer().nullable()();

  TextColumn get thumbnailUrl => text().nullable()();

  BoolColumn get liked => boolean().withDefault(const Constant(false))();

  DateTimeColumn get dateAdded => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Artis.
///
/// `id` adalah channelId YouTube Music bila diketahui. Lagu yang diputar
/// dari antrean hanya membawa nama artis, tanpa channelId; untuk kasus itu
/// service memakai id semu `local-<hash nama>` (lihat
/// `localArtistIdForName` di library_service.dart). P4 menggabungkan id
/// semu ke channelId asli saat data YTM tersedia
/// (`LibraryService.mergeArtistChannel`), dan lagu yang diputar dari
/// hasil pencarian/browse langsung memakai channelId
/// (`Track.artistChannelId`).
@TableIndex(name: 'artists_name_idx', columns: {#name})
class Artists extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get thumbnailUrl => text().nullable()();

  BoolColumn get liked => boolean().withDefault(const Constant(false))();

  DateTimeColumn get dateAdded => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pemetaan lagu ke artis (banyak-ke-banyak, dengan urutan).
@TableIndex(name: 'song_artists_artist_idx', columns: {#artistId})
class SongArtists extends Table {
  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  TextColumn get artistId =>
      text().references(Artists, #id, onDelete: KeyAction.cascade)();

  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {songId, artistId};
}

/// Pemetaan album ke artis (banyak-ke-banyak, dengan urutan).
@TableIndex(name: 'album_artists_artist_idx', columns: {#artistId})
class AlbumArtists extends Table {
  TextColumn get albumId =>
      text().references(Albums, #id, onDelete: KeyAction.cascade)();

  TextColumn get artistId =>
      text().references(Artists, #id, onDelete: KeyAction.cascade)();

  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {albumId, artistId};
}

/// Playlist buatan pengguna (atau playlist YTM yang disimpan, lewat
/// `browseId`).
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Nama playlist, maks 100 karakter (PRD B4.1, ditegakkan service).
  TextColumn get name => text()();

  /// Deskripsi playlist, maks 500 karakter (PRD B4.1, ditegakkan service).
  TextColumn get description => text().nullable()();

  /// browseId bila playlist berasal dari YouTube Music.
  TextColumn get browseId => text().nullable()();

  TextColumn get thumbnailUrl => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}

/// Pemetaan playlist ke lagu (banyak-ke-banyak, dengan urutan).
@TableIndex(name: 'playlist_songs_order_idx', columns: {#playlistId, #position})
class PlaylistSongs extends Table {
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();

  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  IntColumn get position => integer()();

  DateTimeColumn get dateAdded => dateTime()();

  @override
  Set<Column> get primaryKey => {playlistId, songId};
}

/// Format audio yang diketahui per lagu (acuan InnerTune FormatEntity).
@TableIndex(name: 'formats_song_idx', columns: {#songId})
class Formats extends Table {
  /// Gabungan videoId dan itag.
  TextColumn get id => text()();

  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  IntColumn get itag => integer()();

  TextColumn get mimeType => text()();

  TextColumn get codecs => text().nullable()();

  IntColumn get bitrate => integer().nullable()();

  RealColumn get loudnessDb => real().nullable()();

  IntColumn get contentLength => integer().nullable()();

  DateTimeColumn get lastModified => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Lirik lagu yang sudah diambil (P7 mengisi tabel ini).
class Lyrics extends Table {
  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  TextColumn get lyrics => text()();

  /// Lirik dengan timestamp (format LRC).
  TextColumn get syncedLyrics => text().nullable()();

  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {songId};
}

/// Riwayat putar: satu baris per sesi putar.
///
/// Baris dicatat bila lagu diputar 10 detik atau lebih, atau sampai selesai
/// (PRD B2.7). Jumlah entri dibatasi 10.000, entri tertua dihapus otomatis
/// oleh service (PRD B4.6).
@TableIndex(name: 'play_events_song_idx', columns: {#songId, #timestamp})
@TableIndex(name: 'play_events_recent_idx', columns: {#timestamp, #id})
class PlayEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get timestamp => dateTime()();

  IntColumn get playTimeMs => integer()();
}

/// Riwayat pencarian, dibatasi 100 query terbaru (PRD B4.6 / A5).
class SearchHistory extends Table {
  TextColumn get query => text()();

  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {query};
}

/// Antrean pemutar, disimpan sebagai tabel agar selamat dari restart.
///
/// P3 hanya menyediakan tabel dan metode service-nya. Penulisan otomatis
/// dari player dan pemulihan saat start adalah pekerjaan resume (P7),
/// karena butuh kolom posisi yang belum ada di skema v1 (PRD B2.7).
class QueueItems extends Table {
  IntColumn get position => integer()();

  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  /// Asal antrean (playlist, album, pencarian).
  TextColumn get source => text().nullable()();

  @override
  Set<Column> get primaryKey => {position};
}

/// File audio lokal di perangkat (acuan InnerTune LocalItem).
class LocalItems extends Table {
  TextColumn get path => text()();

  TextColumn get title => text().nullable()();

  TextColumn get artist => text().nullable()();

  TextColumn get album => text().nullable()();

  IntColumn get durationSeconds => integer().nullable()();

  DateTimeColumn get dateAdded => dateTime()();

  @override
  Set<Column> get primaryKey => {path};
}

/// Manifest cache streaming (bukan file JSON).
@TableIndex(name: 'cache_entries_lru_idx', columns: {#lastAccessed})
class CacheEntries extends Table {
  /// videoId + itag.
  TextColumn get key => text()();

  TextColumn get filePath => text()();

  IntColumn get sizeBytes => integer()();

  DateTimeColumn get lastAccessed => dateTime()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Pekerjaan unduhan yang sedang berjalan, agar bisa dilanjutkan setelah
/// restart (P5 mengisi tabel ini).
///
/// Kolom `quality`, `attempts`, dan `createdAt` ditambahkan di skema v2
/// (P5): PRD B3.2 menetapkan job membawa kualitas, jumlah percobaan, dan
/// waktu dibuat. Ketiganya nullable/ber-default supaya migrasi dari v1
/// tidak butuh nilai buatan untuk baris lama (job v1 tidak pernah dibuat
/// di perangkat nyata karena P5 belum ada saat v1 dirilis).
class DownloadJobs extends Table {
  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  /// Lihat [DownloadJobStatus].
  IntColumn get status => integer()();

  /// Kualitas unduhan sebagai itag yang dipilih
  /// (251 Terbaik, 140 Seimbang, 249/139 Hemat data; lihat
  /// `DownloadQuality` di lib/downloads). Null berarti kualitas tidak
  /// diketahui (job dari skema v1).
  IntColumn get quality => integer().nullable()();

  IntColumn get bytesDownloaded => integer().withDefault(const Constant(0))();

  IntColumn get totalBytes => integer().nullable()();

  /// Jumlah percobaan unduh yang sudah dipakai (maks 3, PRD B3.2).
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get errorMessage => text().nullable()();

  /// Waktu job dibuat: penentu urutan antrean FIFO. Null untuk job v1
  /// (diperlakukan sebagai yang paling tua).
  DateTimeColumn get createdAt => dateTime().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {songId};
}
