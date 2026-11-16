/// Format file salinan Laras (P8, PRD B7.2/B7.3).
///
/// Tinggal di lapisan data (bukan features/backup) karena
/// [LibraryService] memakai model ini untuk ekspor snapshot dan merge
/// impor; lapisan data tidak boleh mengimpor features.
///
/// Satu file JSON berversi yang berisi seluruh data pengguna yang bisa
/// dipindahkan antar HP: lagu (metadata saja), album, artis, playlist,
/// favorit, riwayat putar, riwayat pencarian, antrean, posisi pemutar,
/// dan pengaturan.
///
/// Yang SENGAJA tidak masuk file (dan kenapa):
/// - File audio unduhan: hanya status "pernah diunduh" yang tersimpan
///   (flag `downloaded` per lagu); lagu harus diunduh ulang di HP baru
///   (PRD B7.4). Tombol "Unduh ulang" sesudah impor memakai daftar itu.
/// - `formats` (metadata itag per lagu): bisa didapat lagi saat resolve.
/// - `lyrics`: bisa diambil lagi dari penyedia lirik; teks lirik besar.
/// - `cache_entries` / `download_jobs`: keadaan sementara sesi ini.
/// - `local_items`: pemutar file lokal adalah v1.1 (PRD B10.2), tabel
///   kosong di v1.
///
/// Aturan versi (PRD B7.3, berlaku selamanya): tiap file membawa
/// `backupVersion`; impor menjalankan migrator berurutan sampai versi
/// terbaru; file dari app yang LEBIH BARU ditolak (jangan ditebak
/// isinya); dukungan versi lama tidak boleh dicabut diam-diam.
///
/// Batas ukuran 10.000.000 byte (PRD B7.2: "10 MB" dengan hitungan
/// 10 juta byte / 200 byte per lagu = 50.000 lagu). Batas dicek dari
/// panjang byte SEBELUM parsing penuh, supaya file raksasa tidak
/// sempat menghabiskan memori (aturan anti-OOM arsitektur §4.6).
library;

import 'dart:convert';
import 'dart:typed_data';

/// Versi format salinan yang ditulis app ini sekarang.
const int kCurrentBackupVersion = 1;

/// Batas ukuran file salinan yang diterima impor, dalam byte.
const int kMaxBackupBytes = 10000000;

/// Batas antrean di file salinan (sama dengan batas antrean pemutar).
const int kMaxBackupQueueItems = 200;

/// Jenis kegagalan saat membaca file salinan. Pemetaan ke pesan bahasa
/// sehari-hari tinggal di UI (ARB), bukan di sini.
enum BackupErrorKind {
  /// File lebih besar dari [kMaxBackupBytes].
  tooLarge,

  /// Bukan JSON valid / bukan UTF-8 valid.
  invalidJson,

  /// JSON valid tapi bukan file salinan app ini (tidak ada
  /// `backupVersion` yang dikenali).
  notBackup,

  /// `backupVersion` lebih baru dari yang dikenal app ini.
  newerVersion,

  /// Struktur tidak sesuai skema (tipe salah, referensi lagu hilang).
  invalidStructure,
}

/// Kegagalan membaca file salinan.
class BackupException implements Exception {
  const BackupException(this.kind, [this.detail]);

  final BackupErrorKind kind;

  /// Detail teknis untuk debug (tidak tampil ke pengguna).
  final String? detail;

  @override
  String toString() => 'BackupException($kind${detail == null ? '' : ': $detail'})';
}

/// Satu artis di dalam lagu salinan (id + nama, sesuai urutan).
class BackupArtistRef {
  const BackupArtistRef({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
  };

  static BackupArtistRef? tryParse(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? id = raw['id'];
    final Object? name = raw['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.isEmpty) return null;
    return BackupArtistRef(id: id, name: name);
  }
}

/// Satu lagu di file salinan (metadata saja, tanpa file audio).
class BackupSong {
  const BackupSong({
    required this.id,
    required this.title,
    this.artists = const <BackupArtistRef>[],
    this.albumId,
    this.durationSeconds,
    this.thumbnailUrl,
    this.liked = false,
    this.inLibrary = false,
    this.totalPlayTimeMs = 0,
    this.dateAdded,
    this.downloaded = false,
    this.unplayable = false,
  });

  final String id;
  final String title;
  final List<BackupArtistRef> artists;

  /// browseId album, atau null bila lagu tidak punya album.
  final String? albumId;
  final int? durationSeconds;
  final String? thumbnailUrl;
  final bool liked;
  final bool inLibrary;
  final int totalPlayTimeMs;
  final DateTime? dateAdded;

  /// True bila lagu ini berstatus terunduh saat salinan dibuat. File
  /// audionya TIDAK ikut; flag ini menggerakkan tombol "Unduh ulang"
  /// sesudah impor.
  final bool downloaded;

  /// True bila lagu terbukti tidak bisa diputar (P6, B4.7).
  final bool unplayable;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'artists': artists.map((BackupArtistRef a) => a.toJson()).toList(),
    'albumId': albumId,
    'durationSeconds': durationSeconds,
    'thumbnailUrl': thumbnailUrl,
    'liked': liked,
    'inLibrary': inLibrary,
    'totalPlayTimeMs': totalPlayTimeMs,
    'dateAdded': dateAdded?.millisecondsSinceEpoch,
    'downloaded': downloaded,
    'unplayable': unplayable,
  };

  static BackupSong? tryParse(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? id = raw['id'];
    final Object? title = raw['title'];
    if (id is! String || id.isEmpty) return null;
    if (title is! String || title.isEmpty) return null;
    final List<BackupArtistRef> artists = <BackupArtistRef>[];
    final Object? rawArtists = raw['artists'];
    if (rawArtists is List) {
      for (final Object? item in rawArtists) {
        final BackupArtistRef? ref = BackupArtistRef.tryParse(item);
        if (ref == null) return null;
        artists.add(ref);
      }
    } else if (rawArtists != null) {
      return null;
    }
    final Object? albumId = raw['albumId'];
    final Object? durationSeconds = raw['durationSeconds'];
    final Object? thumbnailUrl = raw['thumbnailUrl'];
    final Object? liked = raw['liked'];
    final Object? inLibrary = raw['inLibrary'];
    final Object? totalPlayTimeMs = raw['totalPlayTimeMs'];
    final Object? dateAdded = raw['dateAdded'];
    final Object? downloaded = raw['downloaded'];
    final Object? unplayable = raw['unplayable'];
    if (albumId != null && albumId is! String) return null;
    if (durationSeconds != null && durationSeconds is! int) return null;
    if (thumbnailUrl != null && thumbnailUrl is! String) return null;
    if (liked != null && liked is! bool) return null;
    if (inLibrary != null && inLibrary is! bool) return null;
    if (totalPlayTimeMs != null && totalPlayTimeMs is! int) return null;
    if (dateAdded != null && dateAdded is! int) return null;
    if (downloaded != null && downloaded is! bool) return null;
    if (unplayable != null && unplayable is! bool) return null;
    return BackupSong(
      id: id,
      title: title,
      artists: artists,
      albumId: albumId as String?,
      durationSeconds: durationSeconds as int?,
      thumbnailUrl: thumbnailUrl as String?,
      liked: liked as bool? ?? false,
      inLibrary: inLibrary as bool? ?? false,
      totalPlayTimeMs: totalPlayTimeMs as int? ?? 0,
      dateAdded: dateAdded == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(dateAdded as int),
      downloaded: downloaded as bool? ?? false,
      unplayable: unplayable as bool? ?? false,
    );
  }
}

/// Satu album di file salinan.
class BackupAlbum {
  const BackupAlbum({
    required this.id,
    required this.title,
    this.year,
    this.thumbnailUrl,
    this.liked = false,
    this.dateAdded,
  });

  final String id;
  final String title;
  final int? year;
  final String? thumbnailUrl;
  final bool liked;
  final DateTime? dateAdded;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'year': year,
    'thumbnailUrl': thumbnailUrl,
    'liked': liked,
    'dateAdded': dateAdded?.millisecondsSinceEpoch,
  };

  static BackupAlbum? tryParse(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? id = raw['id'];
    final Object? title = raw['title'];
    if (id is! String || id.isEmpty) return null;
    if (title is! String || title.isEmpty) return null;
    final Object? year = raw['year'];
    final Object? thumbnailUrl = raw['thumbnailUrl'];
    final Object? liked = raw['liked'];
    final Object? dateAdded = raw['dateAdded'];
    if (year != null && year is! int) return null;
    if (thumbnailUrl != null && thumbnailUrl is! String) return null;
    if (liked != null && liked is! bool) return null;
    if (dateAdded != null && dateAdded is! int) return null;
    return BackupAlbum(
      id: id,
      title: title,
      year: year as int?,
      thumbnailUrl: thumbnailUrl as String?,
      liked: liked as bool? ?? false,
      dateAdded: dateAdded == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(dateAdded as int),
    );
  }
}

/// Satu artis di file salinan (daftar lengkap, termasuk artis yang
/// lagunya tidak ikut tersimpan).
class BackupArtist {
  const BackupArtist({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    this.liked = false,
    this.dateAdded,
  });

  final String id;
  final String name;
  final String? thumbnailUrl;
  final bool liked;
  final DateTime? dateAdded;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'thumbnailUrl': thumbnailUrl,
    'liked': liked,
    'dateAdded': dateAdded?.millisecondsSinceEpoch,
  };

  static BackupArtist? tryParse(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? id = raw['id'];
    final Object? name = raw['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.isEmpty) return null;
    final Object? thumbnailUrl = raw['thumbnailUrl'];
    final Object? liked = raw['liked'];
    final Object? dateAdded = raw['dateAdded'];
    if (thumbnailUrl != null && thumbnailUrl is! String) return null;
    if (liked != null && liked is! bool) return null;
    if (dateAdded != null && dateAdded is! int) return null;
    return BackupArtist(
      id: id,
      name: name,
      thumbnailUrl: thumbnailUrl as String?,
      liked: liked as bool? ?? false,
      dateAdded: dateAdded == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(dateAdded as int),
    );
  }
}

/// Satu playlist di file salinan. Lagu disimpan sebagai daftar id
/// berurutan (id playlist di database TIDAK ikut: auto-increment
/// berbeda di tiap HP, dan merge mencocokkan berdasarkan nama).
class BackupPlaylist {
  const BackupPlaylist({
    required this.name,
    this.description,
    this.songIds = const <String>[],
    this.createdAt,
  });

  final String name;
  final String? description;
  final List<String> songIds;
  final DateTime? createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'description': description,
    'songIds': songIds,
    'createdAt': createdAt?.millisecondsSinceEpoch,
  };

  static BackupPlaylist? tryParse(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? name = raw['name'];
    if (name is! String || name.isEmpty) return null;
    final Object? description = raw['description'];
    final Object? songIds = raw['songIds'];
    final Object? createdAt = raw['createdAt'];
    if (description != null && description is! String) return null;
    if (createdAt != null && createdAt is! int) return null;
    final List<String> ids = <String>[];
    if (songIds is List) {
      for (final Object? item in songIds) {
        if (item is! String || item.isEmpty) return null;
        ids.add(item);
      }
    } else if (songIds != null) {
      return null;
    }
    return BackupPlaylist(
      name: name,
      description: description as String?,
      songIds: ids,
      createdAt: createdAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(createdAt as int),
    );
  }
}

/// Satu entri riwayat putar di file salinan.
class BackupPlayEvent {
  const BackupPlayEvent({
    required this.songId,
    required this.timestamp,
    required this.playTimeMs,
  });

  final String songId;
  final DateTime timestamp;
  final int playTimeMs;

  Map<String, Object?> toJson() => <String, Object?>{
    'songId': songId,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'playTimeMs': playTimeMs,
  };

  static BackupPlayEvent? tryParse(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? songId = raw['songId'];
    final Object? timestamp = raw['timestamp'];
    final Object? playTimeMs = raw['playTimeMs'];
    if (songId is! String || songId.isEmpty) return null;
    if (timestamp is! int || timestamp < 0) return null;
    if (playTimeMs is! int || playTimeMs < 0) return null;
    return BackupPlayEvent(
      songId: songId,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      playTimeMs: playTimeMs,
    );
  }
}

/// Satu query riwayat pencarian di file salinan.
class BackupSearchQuery {
  const BackupSearchQuery({required this.query, required this.timestamp});

  final String query;
  final DateTime timestamp;

  Map<String, Object?> toJson() => <String, Object?>{
    'query': query,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  static BackupSearchQuery? tryParse(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? query = raw['query'];
    final Object? timestamp = raw['timestamp'];
    if (query is! String || query.isEmpty) return null;
    if (timestamp is! int || timestamp < 0) return null;
    return BackupSearchQuery(
      query: query,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }
}

/// Satu item antrean di file salinan. Urutan = urutan di daftar;
/// posisi tidak disimpan terpisah.
class BackupQueueItem {
  const BackupQueueItem({required this.songId, this.source});

  final String songId;
  final String? source;

  Map<String, Object?> toJson() => <String, Object?>{
    'songId': songId,
    'source': source,
  };

  static BackupQueueItem? tryParse(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? songId = raw['songId'];
    final Object? source = raw['source'];
    if (songId is! String || songId.isEmpty) return null;
    if (source != null && source is! String) return null;
    return BackupQueueItem(songId: songId, source: source as String?);
  }
}

/// Posisi pemutar saat salinan dibuat (P7, MUST #3). Dipulihkan hanya
/// bila antrean HP tujuan kosong saat impor (supaya posisi lagu yang
/// sedang diputar tidak tertimpa).
class BackupPlaybackState {
  const BackupPlaybackState({
    required this.currentIndex,
    required this.positionMs,
    required this.shuffleEnabled,
    required this.repeatMode,
  });

  final int currentIndex;
  final int positionMs;
  final bool shuffleEnabled;
  final int repeatMode;

  Map<String, Object?> toJson() => <String, Object?>{
    'currentIndex': currentIndex,
    'positionMs': positionMs,
    'shuffleEnabled': shuffleEnabled,
    'repeatMode': repeatMode,
  };

  static BackupPlaybackState? tryParse(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? currentIndex = raw['currentIndex'];
    final Object? positionMs = raw['positionMs'];
    final Object? shuffleEnabled = raw['shuffleEnabled'];
    final Object? repeatMode = raw['repeatMode'];
    if (currentIndex is! int || currentIndex < 0) return null;
    if (positionMs is! int || positionMs < 0) return null;
    if (shuffleEnabled is! bool) return null;
    if (repeatMode is! int || repeatMode < 0 || repeatMode > 2) return null;
    return BackupPlaybackState(
      currentIndex: currentIndex,
      positionMs: positionMs,
      shuffleEnabled: shuffleEnabled,
      repeatMode: repeatMode,
    );
  }
}

/// Pengaturan pengguna di file salinan.
///
/// Hanya pengaturan BUATAN PENGGUNA yang ikut. Yang tidak ikut (bukan
/// pengaturan, melainkan keadaan layanan): status kanari, config remote
/// + cap waktunya, status layanan, cap waktu muat Jelajah, dan flag
/// first-run (onboarding/lembar kejujuran). Nilai yang salah tipe
/// diabaikan saat parse (bukan menolak file): pengaturan adalah bagian
/// yang paling mungkin berbeda antar versi, dan satu nilai rusak tidak
/// boleh menggagalkan seluruh impor data.
///
/// Level equalizer per pita TIDAK ikut: jumlah pita mengikuti perangkat
/// (PRD B10.3: pita yang tidak ada di HP ini diabaikan). Preset + saklar
/// equalizer ikut (preset adalah indeks ke daftar preset perangkat;
/// di HP lain indeks yang sama bisa berarti preset berbeda — keterbatasan
/// yang dicatat, bukan disembunyikan).
class BackupSettings {
  const BackupSettings({
    this.dataSaver,
    this.defaultQuality,
    this.wifiOnly,
    this.cacheLimitBytes,
    this.playbackSpeed,
    this.playbackPitch,
    this.skipSilence,
    this.sortSongs,
    this.eqEnabled,
    this.eqPreset,
  });

  final bool? dataSaver;

  /// 'best' | 'balanced' | 'data_saver'.
  final String? defaultQuality;
  final bool? wifiOnly;
  final int? cacheLimitBytes;
  final double? playbackSpeed;
  final double? playbackPitch;
  final bool? skipSilence;

  /// Nama enum SongSort ('newest' | 'byName' | 'mostPlayed').
  final String? sortSongs;
  final bool? eqEnabled;

  /// Indeks preset equalizer perangkat (-1 = tanpa preset).
  final int? eqPreset;

  Map<String, Object?> toJson() => <String, Object?>{
    'dataSaver': dataSaver,
    'defaultQuality': defaultQuality,
    'wifiOnly': wifiOnly,
    'cacheLimitBytes': cacheLimitBytes,
    'playbackSpeed': playbackSpeed,
    'playbackPitch': playbackPitch,
    'skipSilence': skipSilence,
    'sortSongs': sortSongs,
    'eqEnabled': eqEnabled,
    'eqPreset': eqPreset,
  };

  static BackupSettings? tryParse(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map<String, Object?>) return null;
    final Object? dataSaver = raw['dataSaver'];
    final Object? defaultQuality = raw['defaultQuality'];
    final Object? wifiOnly = raw['wifiOnly'];
    final Object? cacheLimitBytes = raw['cacheLimitBytes'];
    final Object? playbackSpeed = raw['playbackSpeed'];
    final Object? playbackPitch = raw['playbackPitch'];
    final Object? skipSilence = raw['skipSilence'];
    final Object? sortSongs = raw['sortSongs'];
    final Object? eqEnabled = raw['eqEnabled'];
    final Object? eqPreset = raw['eqPreset'];
    return BackupSettings(
      dataSaver: dataSaver is bool ? dataSaver : null,
      defaultQuality: defaultQuality is String ? defaultQuality : null,
      wifiOnly: wifiOnly is bool ? wifiOnly : null,
      cacheLimitBytes: cacheLimitBytes is int ? cacheLimitBytes : null,
      playbackSpeed: playbackSpeed is num ? playbackSpeed.toDouble() : null,
      playbackPitch: playbackPitch is num ? playbackPitch.toDouble() : null,
      skipSilence: skipSilence is bool ? skipSilence : null,
      sortSongs: sortSongs is String ? sortSongs : null,
      eqEnabled: eqEnabled is bool ? eqEnabled : null,
      eqPreset: eqPreset is int ? eqPreset : null,
    );
  }
}

/// Seluruh isi satu file salinan, sudah tervalidasi dan sudah
/// dimigrasikan ke versi terbaru.
class BackupData {
  const BackupData({
    required this.version,
    required this.appVersion,
    required this.exportedAt,
    this.songs = const <BackupSong>[],
    this.albums = const <BackupAlbum>[],
    this.artists = const <BackupArtist>[],
    this.playlists = const <BackupPlaylist>[],
    this.playEvents = const <BackupPlayEvent>[],
    this.searchHistory = const <BackupSearchQuery>[],
    this.queue = const <BackupQueueItem>[],
    this.playbackState,
    this.settings,
  });

  /// Versi format sesudah migrasi (selalu [kCurrentBackupVersion]).
  final int version;

  /// Versi app yang membuat file (string, mis. "0.9.0").
  final String appVersion;

  final DateTime exportedAt;
  final List<BackupSong> songs;
  final List<BackupAlbum> albums;
  final List<BackupArtist> artists;
  final List<BackupPlaylist> playlists;
  final List<BackupPlayEvent> playEvents;
  final List<BackupSearchQuery> searchHistory;
  final List<BackupQueueItem> queue;
  final BackupPlaybackState? playbackState;
  final BackupSettings? settings;

  /// Id lagu yang berstatus terunduh saat salinan dibuat (untuk tombol
  /// "Unduh ulang" sesudah impor).
  List<String> get downloadedSongIds =>
      songs.where((BackupSong s) => s.downloaded).map((BackupSong s) => s.id).toList();

  /// Jumlah lagu favorit di file ini.
  int get favoriteCount => songs.where((BackupSong s) => s.liked).length;

  Map<String, Object?> toJson() => <String, Object?>{
    'backupVersion': version,
    'appVersion': appVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'songs': songs.map((BackupSong s) => s.toJson()).toList(),
    'albums': albums.map((BackupAlbum a) => a.toJson()).toList(),
    'artists': artists.map((BackupArtist a) => a.toJson()).toList(),
    'playlists': playlists.map((BackupPlaylist p) => p.toJson()).toList(),
    'playEvents': playEvents.map((BackupPlayEvent e) => e.toJson()).toList(),
    'searchHistory': searchHistory.map((BackupSearchQuery q) => q.toJson()).toList(),
    'queue': queue.map((BackupQueueItem q) => q.toJson()).toList(),
    'playbackState': playbackState?.toJson(),
    'settings': settings?.toJson(),
  };

  /// Encode ke teks JSON.
  String encode() => jsonEncode(toJson());

  /// Parse + validasi + migrasi dari byte file.
  ///
  /// Urutan: cek ukuran dulu ([kMaxBackupBytes]), lalu decode UTF-8,
  /// lalu parse JSON, lalu cek versi, lalu migrasi, lalu validasi
  /// struktur + referensi. Melempar [BackupException] dengan jenis
  /// yang tepat di tiap langkah; tidak pernah melempar error mentah
  /// (FormatException dsb.) ke pemanggil.
  static BackupData parseBytes(Uint8List bytes) {
    if (bytes.length > kMaxBackupBytes) {
      throw const BackupException(
        BackupErrorKind.tooLarge,
        'ukuran file melebihi batas',
      );
    }
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException catch (e) {
      throw BackupException(BackupErrorKind.invalidJson, e.message);
    }
    return parseText(text);
  }

  /// Parse + validasi + migrasi dari teks JSON.
  static BackupData parseText(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw BackupException(BackupErrorKind.invalidJson, e.message);
    }
    if (decoded is! Map<String, Object?>) {
      throw const BackupException(
        BackupErrorKind.notBackup,
        'akar JSON bukan objek',
      );
    }
    final Object? versionRaw = decoded['backupVersion'];
    if (versionRaw is! int) {
      throw const BackupException(
        BackupErrorKind.notBackup,
        'backupVersion hilang atau bukan angka',
      );
    }
    if (versionRaw > kCurrentBackupVersion) {
      throw BackupException(
        BackupErrorKind.newerVersion,
        'backupVersion $versionRaw > $kCurrentBackupVersion',
      );
    }
    if (versionRaw < 1) {
      throw const BackupException(
        BackupErrorKind.notBackup,
        'backupVersion < 1',
      );
    }
    // Migrasi berurutan sampai versi terbaru. v1 adalah versi pertama,
    // jadi belum ada migrator nyata — dispatch ini yang menjamin file
    // lama tetap bisa dibaca saat v2 lahir (PRD B7.3).
    Map<String, Object?> migrated = decoded;
    for (int v = versionRaw; v < kCurrentBackupVersion; v++) {
      migrated = _migrateOneStep(migrated, fromVersion: v);
    }
    return _fromJsonV1(migrated);
  }

  /// Satu langkah migrasi v -> v+1. Dipanggil berurutan oleh [parseText].
  /// Menambah versi baru = menambah satu cabang di sini (dan hanya di
  /// sini), tanpa mengubah parser v1.
  static Map<String, Object?> _migrateOneStep(
    Map<String, Object?> json, {
    required int fromVersion,
  }) {
    switch (fromVersion) {
      default:
        // Belum ada migrator: v1 adalah versi pertama. Cabang ini
        // tidak pernah tercapai selama kCurrentBackupVersion == 1.
        throw BackupException(
          BackupErrorKind.invalidStructure,
          'tidak ada migrator dari versi $fromVersion',
        );
    }
  }

  static BackupData _fromJsonV1(Map<String, Object?> json) {
    final Object? appVersion = json['appVersion'];
    final Object? exportedAt = json['exportedAt'];
    if (appVersion is! String || appVersion.isEmpty) {
      throw const BackupException(
        BackupErrorKind.invalidStructure,
        'appVersion hilang atau bukan string',
      );
    }
    DateTime? exported;
    if (exportedAt is String) {
      exported = DateTime.tryParse(exportedAt);
    }
    if (exported == null) {
      throw const BackupException(
        BackupErrorKind.invalidStructure,
        'exportedAt hilang atau bukan tanggal ISO',
      );
    }
    final List<BackupSong> songs = _parseList(
      json['songs'],
      BackupSong.tryParse,
      'songs',
    );
    final List<BackupAlbum> albums = _parseList(
      json['albums'],
      BackupAlbum.tryParse,
      'albums',
    );
    final List<BackupArtist> artists = _parseList(
      json['artists'],
      BackupArtist.tryParse,
      'artists',
    );
    final List<BackupPlaylist> playlists = _parseList(
      json['playlists'],
      BackupPlaylist.tryParse,
      'playlists',
    );
    final List<BackupPlayEvent> playEvents = _parseList(
      json['playEvents'],
      BackupPlayEvent.tryParse,
      'playEvents',
    );
    final List<BackupSearchQuery> searchHistory = _parseList(
      json['searchHistory'],
      BackupSearchQuery.tryParse,
      'searchHistory',
    );
    final List<BackupQueueItem> queue = _parseList(
      json['queue'],
      BackupQueueItem.tryParse,
      'queue',
    );
    // Id lagu wajib unik (duplikat = file rusak, bukan merge diam-diam).
    final Set<String> songIds = <String>{};
    for (final BackupSong song in songs) {
      if (!songIds.add(song.id)) {
        throw BackupException(
          BackupErrorKind.invalidStructure,
          'id lagu ganda: ${song.id}',
        );
      }
    }
    final Set<String> albumIds = albums.map((BackupAlbum a) => a.id).toSet();
    // Integritas referensi: semua penunjuk lagu/album harus ada di file.
    // Tanpa cek ini, impor bisa gagal di tengah transaksi karena
    // foreign key — lebih baik ditolak utuh di depan.
    for (final BackupSong song in songs) {
      final String? albumId = song.albumId;
      if (albumId != null && !albumIds.contains(albumId)) {
        throw BackupException(
          BackupErrorKind.invalidStructure,
          'lagu ${song.id} menunjuk album yang tidak ada: $albumId',
        );
      }
    }
    for (final BackupPlaylist playlist in playlists) {
      for (final String songId in playlist.songIds) {
        if (!songIds.contains(songId)) {
          throw BackupException(
            BackupErrorKind.invalidStructure,
            'playlist "${playlist.name}" menunjuk lagu yang tidak ada: $songId',
          );
        }
      }
    }
    for (final BackupPlayEvent event in playEvents) {
      if (!songIds.contains(event.songId)) {
        throw BackupException(
          BackupErrorKind.invalidStructure,
          'riwayat menunjuk lagu yang tidak ada: ${event.songId}',
        );
      }
    }
    for (final BackupQueueItem item in queue) {
      if (!songIds.contains(item.songId)) {
        throw BackupException(
          BackupErrorKind.invalidStructure,
          'antrean menunjuk lagu yang tidak ada: ${item.songId}',
        );
      }
    }
    if (queue.length > kMaxBackupQueueItems) {
      throw const BackupException(
        BackupErrorKind.invalidStructure,
        'antrean di file melebihi 200 item',
      );
    }
    final BackupPlaybackState? playbackState =
        json['playbackState'] == null
        ? null
        : BackupPlaybackState.tryParse(json['playbackState']);
    if (json['playbackState'] != null && playbackState == null) {
      throw const BackupException(
        BackupErrorKind.invalidStructure,
        'playbackState rusak',
      );
    }
    final BackupSettings? settings = BackupSettings.tryParse(
      json['settings'],
    );
    return BackupData(
      version: kCurrentBackupVersion,
      appVersion: appVersion,
      exportedAt: exported,
      songs: songs,
      albums: albums,
      artists: artists,
      playlists: playlists,
      playEvents: playEvents,
      searchHistory: searchHistory,
      queue: queue,
      playbackState: playbackState,
      settings: settings,
    );
  }

  static List<T> _parseList<T>(
    Object? raw,
    T? Function(Object? item) parse,
    String section,
  ) {
    if (raw == null) return <T>[];
    if (raw is! List) {
      throw BackupException(
        BackupErrorKind.invalidStructure,
        'bagian "$section" bukan daftar',
      );
    }
    final List<T> out = <T>[];
    for (final Object? item in raw) {
      final T? parsed = parse(item);
      if (parsed == null) {
        throw BackupException(
          BackupErrorKind.invalidStructure,
          'item rusak di bagian "$section"',
        );
      }
      out.add(parsed);
    }
    return out;
  }
}

/// Nama file salinan: `backup-musik-YYYYMMDD-HHmmss.json` (PRD B7.2,
/// waktu lokal HP supaya nama file bisa dibaca pengguna).
String backupFileName([DateTime? when]) {
  final DateTime at = when ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'backup-musik-${at.year}${two(at.month)}${two(at.day)}-'
      '${two(at.hour)}${two(at.minute)}${two(at.second)}.json';
}

/// Tanggal untuk ringkasan impor, mis. "17 Nov 2026, 04.38".
/// Format manual (tanpa paket intl): bulan singkatan Indonesia.
String formatBackupDate(DateTime when) {
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${when.day} ${months[when.month - 1]} ${when.year}, '
      '${two(when.hour)}.${two(when.minute)}';
}
