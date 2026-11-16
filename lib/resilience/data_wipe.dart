/// "Hapus semua data" (B7.3/L7, P6).
///
/// Urutan penghapusan (dipanggil SETELAH konfirmasi kedua — tidak ada
/// jalan kembali):
/// 1. hentikan unduhan ([onStopDownloads]);
/// 2. tutup database ([onCloseDatabase]);
/// 3. hapus file database (`laras.sqlite`, `-wal`, `-shm`);
/// 4. hapus direktori unduhan dan ruang lagu yang pernah diputar
///    (rekursif);
/// 5. hapus isi direktori temp + file log internal;
/// 6. hapus SELURUH preferensi ([SharedPreferences.clear]).
///
/// CATATAN P8: tombol "Simpan salinan dulu" di dialog konfirmasi pertama
/// adalah tugas P8 (backup belum ada di P6; tombol mati dilarang).
/// P8 menambahkan tombol itu di `wipe_flow.dart` + memanggil ekspor
/// sebelum layanan ini dijalankan.
///
/// Setiap langkah dibungkus try/catch sendiri: satu kegagalan (mis.
/// file sudah hilang) tidak menggagalkan langkah lain. Hasil berisi
/// hitungan jujur ([WipeResult]) — UI menampilkannya apa adanya.
library;

// ignore_for_file: prefer_initializing_formals - konstruktor publik memakai
// parameter bernama publik + field privat; initializing formal akan
// membuat nama parameter menjadi privat dan tidak bisa dipakai pemanggil.

import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Hasil penghapusan data.
class WipeResult {
  const WipeResult({
    required this.deletedFiles,
    required this.deletedDirectories,
    required this.preferencesCleared,
    required this.errors,
  });

  /// Jumlah file yang berhasil dihapus (termasuk file di dalam direktori
  /// yang dihapus rekursif — dihitung sebelum penghapusan).
  final int deletedFiles;

  /// Jumlah direktori yang berhasil dihapus.
  final int deletedDirectories;

  /// Apakah seluruh preferensi berhasil dihapus.
  final bool preferencesCleared;

  /// Pesan kegagalan per langkah (kosong bila semua beres).
  final List<String> errors;

  /// Apakah semua langkah berhasil tanpa satu pun kegagalan.
  bool get fullySucceeded => errors.isEmpty && preferencesCleared;
}

/// Layanan penghapusan seluruh data app.
class DataWipeService {
  DataWipeService({
    required SharedPreferences prefs,
    required Directory documentsDir,
    required Directory tempDir,
    required String databaseFileName,
    required Directory downloadsDir,
    required Directory cacheDir,
    required String internalLogFileName,
    Future<void> Function()? onStopDownloads,
    Future<void> Function()? onCloseDatabase,
  }) : _prefs = prefs,
       _documentsDir = documentsDir,
       _tempDir = tempDir,
       _databaseFileName = databaseFileName,
       _downloadsDir = downloadsDir,
       _cacheDir = cacheDir,
       _internalLogFileName = internalLogFileName,
       _onStopDownloads = onStopDownloads,
       _onCloseDatabase = onCloseDatabase;

  final SharedPreferences _prefs;
  final Directory _documentsDir;
  final Directory _tempDir;
  final String _databaseFileName;
  final Directory _downloadsDir;
  final Directory _cacheDir;
  final String _internalLogFileName;
  final Future<void> Function()? _onStopDownloads;
  final Future<void> Function()? _onCloseDatabase;

  /// Hapus semua data. Tidak pernah melempar; kegagalan dicatat di
  /// [WipeResult.errors].
  ///
  /// I/O file di sini SENGAJA sinkron (existsSync/deleteSync/listSync):
  /// penghapusan dipanggil dari handler widget, dan I/O file async tidak
  /// pernah kembali di bawah FakeAsync tes widget (pelajaran 16 Nov 2026,
  /// preseden yang sama dipakai DownloadService/StreamCacheService).
  /// Operasi ini satu kali dan destruktif; blokir singkat di thread UI
  /// dapat diterima (dialog progres sudah tampil).
  Future<WipeResult> wipeAll() async {
    final List<String> errors = <String>[];
    int deletedFiles = 0;
    int deletedDirectories = 0;

    Future<void> step(String name, Future<void> Function() run) async {
      try {
        await run();
      } on Object catch (e) {
        errors.add('$name: $e');
      }
    }

    await step('menghentikan unduhan', () async {
      await _onStopDownloads?.call();
    });
    await step('menutup database', () async {
      await _onCloseDatabase?.call();
    });

    // File database + journal (wal/shm).
    for (final String suffix in <String>['', '-wal', '-shm']) {
      final File file = File('${_documentsDir.path}/$_databaseFileName$suffix');
      await step('menghapus ${file.path}', () async {
        if (file.existsSync()) {
          file.deleteSync();
          deletedFiles++;
        }
      });
    }

    // Direktori unduhan + ruang lagu yang pernah diputar (rekursif).
    for (final Directory dir in <Directory>[_downloadsDir, _cacheDir]) {
      await step('menghapus ${dir.path}', () async {
        if (dir.existsSync()) {
          deletedFiles += _countFiles(dir);
          dir.deleteSync(recursive: true);
          deletedDirectories++;
        }
      });
    }

    // Isi direktori temp (file log internal ikut terhapus bila di sana).
    await step('membersihkan direktori sementara', () async {
      if (_tempDir.existsSync()) {
        for (final FileSystemEntity entity in _tempDir.listSync()) {
          if (entity is File) {
            entity.deleteSync();
            deletedFiles++;
          } else if (entity is Directory) {
            deletedFiles += _countFiles(entity);
            entity.deleteSync(recursive: true);
            deletedDirectories++;
          }
        }
      }
    });

    // File log internal di direktori dokumen.
    final File logFile = File('${_documentsDir.path}/$_internalLogFileName');
    await step('menghapus log internal', () async {
      if (logFile.existsSync()) {
        logFile.deleteSync();
        deletedFiles++;
      }
    });

    bool prefsCleared = false;
    await step('menghapus preferensi', () async {
      prefsCleared = await _prefs.clear();
      if (!prefsCleared) {
        errors.add('menghapus preferensi: gagal');
      }
    });

    return WipeResult(
      deletedFiles: deletedFiles,
      deletedDirectories: deletedDirectories,
      preferencesCleared: prefsCleared,
      errors: errors,
    );
  }

  static int _countFiles(Directory dir) {
    int count = 0;
    try {
      for (final FileSystemEntity entity in dir.listSync(recursive: true)) {
        if (entity is File) count++;
      }
    } on Object {
      // Hitungan gagal: kembalikan yang sudah terhitung.
    }
    return count;
  }
}
