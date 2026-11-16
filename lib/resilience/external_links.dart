/// Tautan keluar app (P6): email laporan kerusakan, tautan repo, dan
/// info perangkat untuk laporan.
///
/// Disalurkan lewat MethodChannel ke MainActivity (pola yang sama dengan
/// `free_space.dart`), tanpa dependensi url_launcher / package_info_plus.
///
/// Daftar izin tautan diberlakukan di sisi Dart: hanya `https://` ke
/// `github.com` yang boleh dibuka (repo Laras). Permintaan lain ditolak
/// diam-diam (mengembalikan false) supaya tidak ada tautan sembarangan
/// yang lolos dari string lokal.
library;

import 'dart:async';

import 'package:flutter/services.dart';

/// Akses keluar app lewat platform channel.
class ExternalLinks {
  ExternalLinks({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_kChannel);

  static const String _kChannel = 'id.my.adipmusic.laras/external';

  /// Host yang diizinkan untuk [openLink].
  static const List<String> allowedHosts = <String>['github.com'];

  final MethodChannel _channel;

  /// Buka aplikasi email dengan alamat, subjek, dan isi terisi.
  ///
  /// Mengembalikan false bila tidak ada aplikasi email di HP (pemanggil
  /// menampilkan pesan + menyalin alamat ke clipboard).
  Future<bool> openMail({
    required String to,
    required String subject,
    required String body,
  }) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'openMail',
        <String, Object>{'to': to, 'subject': subject, 'body': body},
      );
      return result ?? false;
    } on Object {
      return false;
    }
  }

  /// Buka tautan di browser. Hanya https ke host yang diizinkan.
  Future<bool> openLink(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        !allowedHosts.contains(uri.host)) {
      return false;
    }
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'openLink',
        <String, Object>{'url': url},
      );
      return result ?? false;
    } on Object {
      return false;
    }
  }

  /// Info perangkat untuk email laporan kerusakan.
  ///
  /// Mengembalikan `('model', 'versi Android')`; bila platform tidak
  /// menjawab, kedua nilai berisi 'Tidak diketahui'.
  Future<(String model, String androidVersion)> deviceInfo() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('deviceInfo');
      final String model = result?['model'] as String? ?? 'Tidak diketahui';
      final String version =
          result?['androidVersion'] as String? ?? 'Tidak diketahui';
      return (model, version);
    } on Object {
      return ('Tidak diketahui', 'Tidak diketahui');
    }
  }
}
