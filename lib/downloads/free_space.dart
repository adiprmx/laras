/// Sisa ruang penyimpanan HP.
///
/// Dart tidak punya API sisa ruang disk, jadi angka ini dibaca lewat
/// MethodChannel ke kode native (`StatFs` di MainActivity). Bila channel
/// tidak tersedia (tes, atau native belum terpasang), hasilnya null dan
/// pemanggil memperlakukan ruang sebagai "tidak diketahui": pra-periksa
/// ruang dilewati dan perlindungan terakhir adalah penanganan kehabisan
/// ruang di tengah unduhan (error ENOSPC ditangkap jujur di
/// [DownloadService]).
library;

import 'package:flutter/services.dart';

/// Pembaca sisa ruang penyimpanan (byte), atau null bila tidak diketahui.
abstract class FreeSpaceProvider {
  /// Sisa ruang di penyimpanan yang menampung [path], dalam byte.
  Future<int?> freeBytes(String path);
}

/// Implementasi lewat MethodChannel ke MainActivity (StatFs).
class PlatformFreeSpaceProvider implements FreeSpaceProvider {
  PlatformFreeSpaceProvider({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('id.my.adipmusic.laras/storage');

  final MethodChannel _channel;

  @override
  Future<int?> freeBytes(String path) async {
    try {
      final Object? result = await _channel.invokeMethod<Object>(
        'freeBytes',
        <String, Object>{'path': path},
      );
      if (result is int) return result;
      return null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
