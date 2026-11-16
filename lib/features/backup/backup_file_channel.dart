/// Berbagi file + memilih file lewat platform Android (P8).
///
/// Disalurkan lewat MethodChannel ke MainActivity (pola yang sama dengan
/// `ExternalLinks` P6), TANPA dependensi share_plus / file_picker:
/// keduanya tidak ada di pub cache lokal dan egress VM tidak stabil,
/// sementara kebutuhan P8 hanya dua aksi native sederhana (chooser
/// berbagi + pemilih dokumen SAF). F-Droid: nol dependensi baru.
///
/// Channel `id.my.adipmusic.laras/backup_files`:
/// - `shareFile {path, fileName, mimeType}` -> bool (chooser tampil).
///   File harus sudah ada di direktori cache app (FileProvider hanya
///   mengekspos cache-path). Berbagi TIDAK melaporkan pembatalan:
///   ACTION_SEND tidak mengembalikan hasil; `true` berarti lembar
///   berbagi berhasil dibuka.
/// - `pickFile` -> null (pengguna batal) atau
///   `{bytes: Uint8List, name: String?}`. Native membaca isi file
///   lewat ContentResolver dengan batas [kMaxBackupBytes]+1 byte dan
///   mengembalikan error `TOO_LARGE` bila lewat (file tidak pernah
///   dibaca utuh tanpa batas ke memori).
library;

import 'package:flutter/services.dart';
import 'package:laras/data/backup_format.dart';

/// Kegagalan memilih/membaca file (bukan pembatalan pengguna).
class BackupFileException implements Exception {
  const BackupFileException(this.message);

  final String message;

  @override
  String toString() => 'BackupFileException($message)';
}

/// Satu file yang dipilih pengguna lewat pemilih dokumen.
class PickedFile {
  const PickedFile({required this.bytes, this.name});

  /// Isi file (sudah dibatasi native ke [kMaxBackupBytes]+1; pemanggil
  /// tetap wajib cek [BackupData.parseBytes] yang menegakkan batas).
  final Uint8List bytes;

  /// Nama tampil file (dari SAF), atau null bila tidak diketahui.
  /// Dipakai deteksi format impor Spotify + nama playlist bawaan.
  final String? name;
}

/// Akses berbagi + pemilih file lewat platform channel.
class BackupFileChannel {
  BackupFileChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_kChannel);

  static const String _kChannel = 'id.my.adipmusic.laras/backup_files';

  final MethodChannel _channel;

  /// Buka lembar berbagi Android untuk file di [path].
  ///
  /// Mengembalikan true bila lembar berbagi berhasil dibuka. False bila
  /// platform gagal (mis. file tidak ada / FileProvider bermasalah).
  /// Pembatalan oleh pengguna TIDAK terdeteksi (keterbatasan ACTION_SEND)
  /// dan dihitung sebagai berhasil dibuka.
  Future<bool> shareFile({
    required String path,
    required String fileName,
  }) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('shareFile', <
        String,
        Object
      >{
        'path': path,
        'fileName': fileName,
        'mimeType': 'application/json',
      });
      return result ?? false;
    } on Object {
      return false;
    }
  }

  /// Buka pemilih dokumen sistem (SAF) untuk memilih satu file.
  ///
  /// Mengembalikan null bila pengguna membatalkan. Melempar
  /// [BackupException] jenis [BackupErrorKind.tooLarge] bila file
  /// melebihi batas, dan [BackupFileException] bila file tidak bisa
  /// dibaca.
  Future<PickedFile?> pickFile() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('pickFile');
      if (result == null) return null;
      final Object? bytes = result['bytes'];
      if (bytes is! Uint8List) {
        throw const BackupFileException('isi file tidak terbaca');
      }
      final Object? name = result['name'];
      return PickedFile(
        bytes: bytes,
        name: name is String ? name : null,
      );
    } on BackupException {
      rethrow;
    } on BackupFileException {
      rethrow;
    } on PlatformException catch (e) {
      if (e.code == 'TOO_LARGE') {
        throw const BackupException(
          BackupErrorKind.tooLarge,
          'file melebihi batas (native)',
        );
      }
      if (e.code == 'BUSY') {
        throw const BackupFileException('pemilih file sedang dipakai');
      }
      throw BackupFileException(e.message ?? 'file tidak bisa dibaca');
    } on Object catch (e) {
      throw BackupFileException(e.toString());
    }
  }
}
