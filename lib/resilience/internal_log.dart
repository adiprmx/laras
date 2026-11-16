/// Log internal (P6, tugas 10).
///
/// File lokal saja (`laras-internal.log` di direktori dokumen app):
/// tidak pernah ditampilkan ke pengguna dan tidak pernah berisi URL
/// stream (semua URL http(s) disensor sebelum ditulis).
///
/// Batas ukuran 1 MiB: saat file melewati batas, separuh terlama
/// dibuang (rotasi potong-separuh dalam satu file, tanpa file kedua).
/// Pemotongan dilakukan di batas baris supaya tidak ada baris setengah.
///
/// Penulisan diserialkan lewat rantai future supaya dua penulis tidak
/// saling menimpa. Kegagalan tulis tidak pernah melempar ke pemanggil
/// (log adalah alat bantu, bukan fitur yang boleh merusak app).
library;

// ignore_for_file: prefer_initializing_formals - konstruktor publik memakai
// parameter bernama publik + field privat; initializing formal akan
// membuat nama parameter menjadi privat dan tidak bisa dipakai pemanggil.

import 'dart:async';
import 'dart:io';

/// Batas ukuran log internal: 1 MiB (PRD).
const int kInternalLogMaxBytes = 1024 * 1024;

/// Nama file log internal di direktori dokumen.
const String kInternalLogFileName = 'laras-internal.log';

/// Pola URL yang disensor dari setiap baris log.
final RegExp _urlPattern = RegExp(r'https?://\S+');

/// Log internal berotasi.
class InternalLog {
  /// [directory] adalah direktori dokumen app (disuntik supaya tes bisa
  /// memakai direktori sementara). [maxBytes] bisa diperkecil di tes.
  InternalLog({
    required Directory directory,
    int maxBytes = kInternalLogMaxBytes,
  }) : _file = File('${directory.path}/$kInternalLogFileName'),
       _maxBytes = maxBytes;

  final File _file;
  final int _maxBytes;

  /// Rantai penulisan: setiap write menunggu write sebelumnya selesai.
  Future<void> _queue = Future<void>.value();

  /// Tulis satu baris `[waktu] [tag] pesan` (URL disensor).
  ///
  /// Tidak pernah melempar.
  Future<void> write(String tag, String message) {
    final Completer<void> done = Completer<void>();
    _queue = _queue
        .then((_) => _writeNow(tag, message))
        .then((_) {
          if (!done.isCompleted) done.complete();
        })
        .catchError((Object _) {
          // Kegagalan log tidak boleh merusak pemanggil.
          if (!done.isCompleted) done.complete();
        });
    return done.future;
  }

  /// Jalur file log (untuk penghapusan saat "Hapus semua data").
  String get filePath => _file.path;

  Future<void> _writeNow(String tag, String message) async {
    final String safe = _redact(message);
    final String line = '[${DateTime.now().toIso8601String()}] [$tag] $safe\n';
    try {
      await _file.parent.create(recursive: true);
      if (await _file.exists()) {
        final int size = await _file.length();
        if (size + line.length > _maxBytes) {
          await _rotate();
        }
      }
      await _file.writeAsString(line, mode: FileMode.append);
    } on Object {
      // Diam: log tidak boleh melempar.
    }
  }

  /// Buang separuh terlama file, dimulai dari batas baris terdekat.
  Future<void> _rotate() async {
    try {
      final List<int> bytes = await _file.readAsBytes();
      if (bytes.length <= _maxBytes) return;
      final int half = bytes.length ~/ 2;
      int cut = half;
      // Cari baris baru pertama setelah titik tengah.
      while (cut < bytes.length && bytes[cut] != 10) {
        cut++;
      }
      if (cut >= bytes.length) {
        // Tidak ada baris baru: buang seluruh isi lama.
        await _file.writeAsBytes(<int>[]);
        return;
      }
      await _file.writeAsBytes(bytes.sublist(cut + 1));
    } on Object {
      // Rotasi gagal: biarkan file apa adanya; write berikutnya mencoba lagi.
    }
  }

  /// Sensor semua URL dari [message].
  static String _redact(String message) =>
      message.replaceAll(_urlPattern, '[tautan]');
}
