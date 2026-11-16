/// Pengaturan pengguna (P6).
///
/// Semua pengaturan disimpan di SharedPreferences dengan kunci berawalan
/// `laras.`. Nilai dibaca sinkron dari memori setelah [AppSettings.create]
/// selesai; setiap setter memperbarui notifier dulu (UI langsung merespons)
/// lalu menyimpan ke disk.
///
/// Kualitas unduhan disimpan sebagai string ('best' | 'balanced' |
/// 'data_saver') supaya file ini tidak bergantung pada
/// `DownloadService` (menghindari impor melingkar resilience<->downloads);
/// konversi ke enum [DownloadQuality] dilakukan di layar Pengaturan dan
/// di main.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Batas ruang lagu yang pernah diputar yang bisa dipilih pengguna (B8.3).
const List<int> kCacheLimitOptions = <int>[
  250 * 1024 * 1024,
  500 * 1024 * 1024,
  1024 * 1024 * 1024,
  2 * 1024 * 1024 * 1024,
];

/// Batas bawaan: 500 MB.
const int kDefaultCacheLimitBytes = 500 * 1024 * 1024;

/// Nilai kualitas unduhan yang disimpan di preferensi.
const String kQualityBest = 'best';
const String kQualityBalanced = 'balanced';
const String kQualityDataSaver = 'data_saver';

const String _kDataSaverKey = 'laras.data_saver';
const String _kDefaultQualityKey = 'laras.default_download_quality';
const String _kWifiOnlyKey = 'laras.wifi_only_downloads';
const String _kCacheLimitKey = 'laras.cache_limit_bytes';

/// Pengaturan pengguna yang tersimpan di SharedPreferences.
class AppSettings {
  AppSettings._(this._prefs)
    : dataSaver = ValueNotifier<bool>(_prefs.getBool(_kDataSaverKey) ?? false),
      defaultQuality = ValueNotifier<String>(
        _prefs.getString(_kDefaultQualityKey) ?? kQualityBest,
      ),
      wifiOnly = ValueNotifier<bool>(_prefs.getBool(_kWifiOnlyKey) ?? false),
      cacheLimitBytes = ValueNotifier<int>(
        _sanitizeLimit(_prefs.getInt(_kCacheLimitKey)),
      );

  /// Muat pengaturan dari SharedPreferences ([prefs] disuntik bila
  /// pemanggil sudah punya instance-nya, mis. main()).
  static Future<AppSettings> create({SharedPreferences? prefs}) async {
    prefs ??= await SharedPreferences.getInstance();
    return AppSettings._(prefs);
  }

  /// Konstruktor untuk tes (SharedPreferences tiruan).
  @visibleForTesting
  factory AppSettings.forTest(SharedPreferences prefs) = AppSettings._;

  final SharedPreferences _prefs;

  /// Saklar "Hemat data" untuk streaming (B8.1). Bawaan: mati.
  final ValueNotifier<bool> dataSaver;

  /// Kualitas unduhan bawaan ('best' | 'balanced' | 'data_saver').
  /// Bawaan: 'best'.
  final ValueNotifier<String> defaultQuality;

  /// Saklar "Unduh saat WiFi saja" (B8.4). Bawaan: mati.
  final ValueNotifier<bool> wifiOnly;

  /// Batas ruang lagu yang pernah diputar (B8.3). Bawaan: 500 MB.
  final ValueNotifier<int> cacheLimitBytes;

  Future<void> setDataSaver(bool value) async {
    dataSaver.value = value;
    await _prefs.setBool(_kDataSaverKey, value);
  }

  Future<void> setDefaultQuality(String value) async {
    if (value != kQualityBest &&
        value != kQualityBalanced &&
        value != kQualityDataSaver) {
      return;
    }
    defaultQuality.value = value;
    await _prefs.setString(_kDefaultQualityKey, value);
  }

  Future<void> setWifiOnly(bool value) async {
    wifiOnly.value = value;
    await _prefs.setBool(_kWifiOnlyKey, value);
  }

  /// Ubah batas ruang; nilai di luar daftar pilihan dijepit ke pilihan
  /// terdekat supaya nilai tersimpan selalu valid.
  Future<void> setCacheLimitBytes(int value) async {
    final int sanitized = _sanitizeLimit(value);
    cacheLimitBytes.value = sanitized;
    await _prefs.setInt(_kCacheLimitKey, sanitized);
  }

  /// Bebaskan notifier. Dipanggil saat app dibongkar (praktisnya tidak
  /// pernah di produksi; dipakai tes widget).
  void dispose() {
    dataSaver.dispose();
    defaultQuality.dispose();
    wifiOnly.dispose();
    cacheLimitBytes.dispose();
  }

  static int _sanitizeLimit(int? value) {
    if (value == null) return kDefaultCacheLimitBytes;
    int best = kCacheLimitOptions.first;
    for (final int option in kCacheLimitOptions) {
      if ((option - value).abs() < (best - value).abs()) best = option;
    }
    return best;
  }
}
