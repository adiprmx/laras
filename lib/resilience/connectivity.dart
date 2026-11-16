/// Deteksi konektivitas untuk saklar "Unduh saat WiFi saja" (B8.4).
///
/// Disalurkan lewat MethodChannel/EventChannel ke MainActivity (pola yang
/// sama dengan `free_space.dart`), tanpa dependensi connectivity_plus.
///
/// Aturan fail-open: bila status WiFi tidak bisa diketahui (channel
/// hilang, platform tidak menjawab), unduhan DIIZINKAN. Memblokir semua
/// unduhan karena hiccup channel lebih buruk daripada memakai data
/// seluler sekali.
library;

// ignore_for_file: prefer_initializing_formals - konstruktor publik memakai
// parameter bernama publik + field privat; initializing formal akan
// membuat nama parameter menjadi privat dan tidak bisa dipakai pemanggil.

import 'dart:async';

import 'package:flutter/services.dart';

/// Monitor konektivitas WiFi lewat platform channel.
class ConnectivityMonitor {
  ConnectivityMonitor({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _method = methodChannel ?? const MethodChannel(_kChannel),
       _events = eventChannel ?? const EventChannel(_kEventsChannel);

  static const String _kChannel = 'id.my.adipmusic.laras/connectivity';
  static const String _kEventsChannel =
      'id.my.adipmusic.laras/connectivity_events';

  final MethodChannel _method;
  final EventChannel _events;

  /// Apakah HP saat ini tersambung WiFi.
  ///
  /// Mengembalikan null bila tidak bisa diketahui (fail-open di pemanggil).
  Future<bool?> isWifi() async {
    try {
      final bool? result = await _method.invokeMethod<bool>('isWifi');
      return result;
    } on Object {
      return null;
    }
  }

  /// Aliran perubahan status WiFi (true = tersambung WiFi).
  Stream<bool> get wifiChanged {
    return _events.receiveBroadcastStream().map(
      (dynamic event) => event is bool ? event : false,
    );
  }
}

/// Gerbang unduhan berdasarkan saklar WiFi saja.
///
/// [wifiOnly] dibaca lewat fungsi supaya perubahan pengaturan langsung
/// berlaku tanpa membangun ulang gerbang. [isWifiConnected] mengembalikan
/// null bila tidak diketahui -> unduhan diizinkan (fail-open).
class WifiGate {
  WifiGate({
    required bool Function() wifiOnly,
    required Future<bool?> Function() isWifiConnected,
    Stream<bool>? wifiChanged,
  }) : _wifiOnly = wifiOnly,
       _isWifiConnected = isWifiConnected,
       _wifiChanged = wifiChanged;

  final bool Function() _wifiOnly;
  final Future<bool?> Function() _isWifiConnected;
  final Stream<bool>? _wifiChanged;

  /// Aliran perubahan WiFi (null bila monitor tidak tersedia).
  Stream<bool>? get wifiChanged => _wifiChanged;

  /// Apakah saklar WiFi saja sedang aktif.
  bool get wifiOnly => _wifiOnly();

  /// Apakah unduhan boleh berjalan sekarang.
  ///
  /// Bila saklar mati: selalu boleh. Bila saklar hidup: boleh hanya saat
  /// tersambung WiFi; status yang tidak diketahui dianggap boleh
  /// (fail-open).
  Future<bool> get mayDownload async {
    if (!_wifiOnly()) return true;
    final bool? wifi = await _isWifiConnected();
    if (wifi == null) return true;
    return wifi;
  }
}
