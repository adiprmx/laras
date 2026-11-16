/// Layanan salinan data (P8, PRD B7.2/B7.3/B10.3).
///
/// Satu pintu untuk ekspor dan impor file salinan:
/// - Ekspor: snapshot database + pengaturan -> JSON berversi -> tulis
///   file sementara di cache -> buka lembar berbagi Android.
/// - Impor: baca byte file -> cek ukuran -> parse + validasi + migrasi
///   -> merge SATU transaksi ([LibraryService.mergeBackupData]) ->
///   terapkan pengaturan (opsional, pilihan pengguna) -> [ImportReport].
///
/// Impor tidak pernah mengubah database bila file tidak lolos validasi:
/// validasi penuh (termasuk integritas referensi) berjalan SEBELUM
/// transaksi dibuka, dan transaksi membatalkan segalanya bila satu
/// langkah gagal (atomic, PRD B7.2).
///
/// Pengaturan yang ikut salinan (hanya buatan pengguna): 4 kunci
/// [AppSettings], kecepatan/nada/lewati-hening [PlaybackPrefs], sortir
/// daftar lagu, dan saklar + preset equalizer. Level EQ per pita tidak
/// ikut (mengikuti perangkat). Yang tidak ikut: status kanari, config
/// remote, status layanan, cap waktu Jelajah, flag first-run.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:laras/core/app_info.dart';
import 'package:laras/data/database.dart';
import 'package:laras/player/equalizer_service.dart';
import 'package:laras/player/playback_prefs.dart';
import 'package:laras/resilience/app_settings.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_file_channel.dart';
import 'import_report.dart';

/// Hasil ekspor + berbagi.
enum BackupExportOutcome {
  /// File ditulis dan lembar berbagi berhasil dibuka.
  shared,

  /// File tidak bisa ditulis / lembar berbagi gagal dibuka.
  failed,

  /// Salinan yang dihasilkan melebihi batas impor (tidak akan bisa
  /// dipulihkan) — ditolak dengan pesan jujur, bukan dibagikan.
  tooLarge,
}

/// Layanan ekspor/impor file salinan.
class BackupService {
  BackupService({
    required this.library,
    required this.settings,
    required this.prefs,
    required this.files,
    this.tempDirProvider,
    this.onSettingsApplied,
  });

  final LibraryService library;
  final AppSettings settings;
  final SharedPreferences prefs;
  final BackupFileChannel files;

  /// Penyedia direktori sementara (disuntik tes; produksi memakai
  /// `getTemporaryDirectory()` = cacheDir Android, satu-satunya yang
  /// diekspos FileProvider).
  final Future<Directory> Function()? tempDirProvider;

  /// Dipanggil sesudah pengaturan dari file diterapkan (dipakai main
  /// untuk menyegarkan layanan yang memegang nilai pengaturan di
  /// memori: kualitas unduhan bawaan + batas ruang lagu yang pernah
  /// diputar). Null berarti tidak ada yang perlu disegarkan.
  final ValueChanged<BackupSettings>? onSettingsApplied;

  /// Bangun isi file salinan dari database + pengaturan saat ini.
  ///
  /// Dipakai ekspor dan tes end-to-end (tanpa berbagi file).
  Future<BackupData> buildBackupData() async {
    final BackupSnapshot snap = await library.backupSnapshot();
    final PlaybackPrefs playback = PlaybackPrefs(prefs: prefs);
    final LibrarySortPrefs sortPrefs = LibrarySortPrefs(prefs: prefs);
    return BackupData(
      version: kCurrentBackupVersion,
      appVersion: kAppVersion,
      exportedAt: DateTime.now(),
      songs: snap.songs
          .map(
            (SongView view) {
              final Song song = view.song;
              return BackupSong(
                id: song.id,
                title: song.title,
                artists: snap.songArtists[song.id] ?? const <BackupArtistRef>[],
                albumId: song.albumId,
                durationSeconds: song.durationSeconds,
                thumbnailUrl: song.thumbnailUrl,
                liked: song.liked,
                inLibrary: song.inLibrary,
                totalPlayTimeMs: song.totalPlayTimeMs,
                dateAdded: song.dateAdded,
                downloaded:
                    song.downloadState == DownloadState.downloaded,
                unplayable: song.unplayable,
              );
            },
          )
          .toList(growable: false),
      albums: snap.albums
          .map(
            (Album a) => BackupAlbum(
              id: a.id,
              title: a.title,
              year: a.year,
              thumbnailUrl: a.thumbnailUrl,
              liked: a.liked,
              dateAdded: a.dateAdded,
            ),
          )
          .toList(growable: false),
      artists: snap.artists
          .map(
            (Artist a) => BackupArtist(
              id: a.id,
              name: a.name,
              thumbnailUrl: a.thumbnailUrl,
              liked: a.liked,
              dateAdded: a.dateAdded,
            ),
          )
          .toList(growable: false),
      playlists: snap.playlists
          .map(
            ((Playlist, List<String>) e) => BackupPlaylist(
              name: e.$1.name,
              description: e.$1.description,
              songIds: e.$2,
              createdAt: e.$1.createdAt,
            ),
          )
          .toList(growable: false),
      playEvents: snap.playEvents
          .map(
            (PlayEvent e) => BackupPlayEvent(
              songId: e.songId,
              timestamp: e.timestamp,
              playTimeMs: e.playTimeMs,
            ),
          )
          .toList(growable: false),
      searchHistory: snap.searchHistory
          .map(
            (SearchHistoryData q) =>
                BackupSearchQuery(query: q.query, timestamp: q.timestamp),
          )
          .toList(growable: false),
      queue: snap.queueItems
          .map(
            (QueueItem q) =>
                BackupQueueItem(songId: q.songId, source: q.source),
          )
          .toList(growable: false),
      playbackState: snap.playbackState == null
          ? null
          : BackupPlaybackState(
              currentIndex: snap.playbackState!.currentIndex,
              positionMs: snap.playbackState!.positionMs,
              shuffleEnabled: snap.playbackState!.shuffleEnabled,
              repeatMode: snap.playbackState!.repeatMode,
            ),
      settings: BackupSettings(
        dataSaver: settings.dataSaver.value,
        defaultQuality: settings.defaultQuality.value,
        wifiOnly: settings.wifiOnly.value,
        cacheLimitBytes: settings.cacheLimitBytes.value,
        playbackSpeed: playback.speed,
        playbackPitch: playback.pitch,
        skipSilence: playback.skipSilence,
        sortSongs: sortPrefs.songSort.name,
        eqEnabled: prefs.getBool(EqualizerService.enabledKey),
        eqPreset: prefs.getInt(EqualizerService.presetKey),
      ),
    );
  }

  /// Ekspor salinan lalu buka lembar berbagi Android.
  ///
  /// File ditulis ke direktori sementara dengan nama
  /// `backup-musik-YYYYMMDD-HHmmss.json`, dibagikan, lalu dihapus
  /// (best-effort; direktori sementara memang untuk file sekali pakai).
  /// Mengembalikan [BackupExportOutcome] — pemanggil (termasuk alur
  /// "Simpan salinan dulu" di hapus data) memutuskan langkah berikut
  /// dari hasil ini; penghapusan TIDAK PERNAH lanjut otomatis dari
  /// sini.
  Future<BackupExportOutcome> exportAndShare() async {
    final BackupData data = await buildBackupData();
    final Uint8List bytes = Uint8List.fromList(utf8.encode(data.encode()));
    if (bytes.length > kMaxBackupBytes) {
      // Salinan yang tidak bisa dipulihkan tidak boleh dibagikan:
      // pengguna akan mengira datanya aman padahal file-nya ditolak
      // saat impor. Batas ini praktis tidak tercapai (10.000 lagu
      // ~2-3 MB), tapi kejujurannya ditegakkan.
      return BackupExportOutcome.tooLarge;
    }
    final String fileName = backupFileName(data.exportedAt);
    final Directory dir = tempDirProvider == null
        ? await getTemporaryDirectory()
        : await tempDirProvider!();
    final File file = File('${dir.path}/$fileName');
    // I/O file SENGAJA sinkron (alasan yang sama dengan DataWipeService):
    // I/O file async tidak pernah kembali di bawah FakeAsync tes widget.
    // Operasi ini satu kali; blokir singkat di thread UI dapat diterima
    // (file ≤10 MB, indikator proses sudah tampil).
    try {
      file.writeAsBytesSync(bytes, flush: true);
    } on Object {
      return BackupExportOutcome.failed;
    }
    final bool shared = await files.shareFile(
      path: file.path,
      fileName: fileName,
    );
    try {
      if (file.existsSync()) file.deleteSync();
    } on Object {
      // File sementara tertinggal tidak masalah: direktori sementara
      // dibersihkan sistem / hapus data.
    }
    return shared ? BackupExportOutcome.shared : BackupExportOutcome.failed;
  }

  /// Buka pemilih dokumen sistem untuk memilih satu file salinan.
  /// Mengembalikan null bila pengguna membatalkan.
  Future<PickedFile?> pickFile() => files.pickFile();

  /// Baca + validasi file salinan TANPA mengubah database.
  ///
  /// Dipakai layar impor untuk menampilkan ringkasan sebelum pengguna
  /// menekan "Pulihkan". Melempar [BackupException] bila file tidak
  /// bisa dipakai.
  BackupData previewImport(Uint8List bytes) => BackupData.parseBytes(bytes);

  /// Impor file salinan yang sudah lolos [previewImport].
  ///
  /// Merge database berjalan dalam satu transaksi; pengaturan dari
  /// file diterapkan sesudah transaksi berhasil bila [applySettings]
  /// true. Mengembalikan [ImportReport] (angka berhasil/sudah ada/
  /// gagal + daftar lagu yang dulu terunduh untuk tombol "Unduh ulang").
  Future<ImportReport> importBackup(
    BackupData data, {
    required bool applySettings,
  }) async {
    final BackupMergeResult merged = await library.mergeBackupData(data);
    if (applySettings && data.settings != null) {
      await _applySettings(data.settings!);
    }
    final List<ImportFailure> failures = <ImportFailure>[];
    if (merged.queueSkippedSongIds.isNotEmpty) {
      final Map<String, BackupSong> songsById = <String, BackupSong>{
        for (final BackupSong s in data.songs) s.id: s,
      };
      for (final String songId in merged.queueSkippedSongIds) {
        final BackupSong? song = songsById[songId];
        final String label = song == null
            ? songId
            : song.artists.isEmpty
            ? song.title
            : '${song.artists.first.name} - ${song.title}';
        failures.add(
          ImportFailure(label: label, reason: ImportFailureReason.queueFull),
        );
      }
    }
    return ImportReport(
      succeeded: merged.totalAdded,
      alreadyExisted: merged.totalExisted,
      failures: failures,
      downloadedSongIds: merged.downloadedSongIds,
      exportedAt: data.exportedAt,
      appVersion: data.appVersion,
    );
  }

  /// Terapkan pengaturan dari file. Setiap setter sudah men-sanitasi
  /// nilainya sendiri (kualitas tak dikenal diabaikan, batas ruang
  /// dijepit ke pilihan terdekat, kecepatan/nada di-clamp).
  Future<void> _applySettings(BackupSettings s) async {
    if (s.dataSaver != null) await settings.setDataSaver(s.dataSaver!);
    if (s.defaultQuality != null) {
      await settings.setDefaultQuality(s.defaultQuality!);
    }
    if (s.wifiOnly != null) await settings.setWifiOnly(s.wifiOnly!);
    if (s.cacheLimitBytes != null) {
      await settings.setCacheLimitBytes(s.cacheLimitBytes!);
    }
    final PlaybackPrefs playback = PlaybackPrefs(prefs: prefs);
    if (s.playbackSpeed != null) await playback.setSpeed(s.playbackSpeed!);
    if (s.playbackPitch != null) await playback.setPitch(s.playbackPitch!);
    if (s.skipSilence != null) {
      await playback.setSkipSilence(s.skipSilence!);
    }
    if (s.sortSongs != null) {
      for (final SongSort sort in SongSort.values) {
        if (sort.name == s.sortSongs) {
          LibrarySortPrefs(prefs: prefs).songSort = sort;
          break;
        }
      }
    }
    if (s.eqEnabled != null) {
      await prefs.setBool(EqualizerService.enabledKey, s.eqEnabled!);
    }
    if (s.eqPreset != null) {
      await prefs.setInt(EqualizerService.presetKey, s.eqPreset!);
    }
    onSettingsApplied?.call(s);
  }
}
