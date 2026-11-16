/// Preferensi pemutar yang tersimpan (P7, sisa P2): kecepatan, nada,
/// dan lewati-bagian-hening.
///
/// Disimpan di SharedPreferences (nilai primitif kecil), dipulihkan saat
/// start oleh [PlayerService] dan ditulis ulang tiap kali nilainya
/// berubah (lewat langganan stateStream port). Nilai yang tersimpan
/// selalu disanitasi ke rentang port (kecepatan 0.25-3.0, nada 0.5-2.0);
/// nilai rusak (null/NaN/di luar rentang) jatuh ke default 1.0/false.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi kecepatan/nada/lewati-hening yang tersimpan.
class PlaybackPrefs {
  PlaybackPrefs({required SharedPreferences prefs})
    : _prefs = prefs; // ignore: prefer_initializing_formals

  static const String speedKey = 'laras.playback_speed';
  static const String pitchKey = 'laras.playback_pitch';
  static const String skipSilenceKey = 'laras.playback_skip_silence';

  /// Rentang kecepatan port (lihat AudioPlayerPort.setSpeed).
  static const double minSpeed = 0.25;

  /// Rentang kecepatan port (lihat AudioPlayerPort.setSpeed).
  static const double maxSpeed = 3.0;

  /// Rentang nada port (lihat AudioPlayerPort.setPitch).
  static const double minPitch = 0.5;

  /// Rentang nada port (lihat AudioPlayerPort.setPitch).
  static const double maxPitch = 2.0;

  final SharedPreferences _prefs;

  double get speed => _sanitized(speedKey, minSpeed, maxSpeed);

  double get pitch => _sanitized(pitchKey, minPitch, maxPitch);

  bool get skipSilence => _prefs.getBool(skipSilenceKey) ?? false;

  double _sanitized(String key, double min, double max) {
    final double? value = _prefs.getDouble(key);
    if (value == null || value.isNaN || value.isInfinite) return 1.0;
    return value.clamp(min, max);
  }

  Future<void> setSpeed(double value) =>
      _prefs.setDouble(speedKey, value.clamp(minSpeed, maxSpeed));

  Future<void> setPitch(double value) =>
      _prefs.setDouble(pitchKey, value.clamp(minPitch, maxPitch));

  Future<void> setSkipSilence(bool value) =>
      _prefs.setBool(skipSilenceKey, value);

  /// Simpan ketiganya sekaligus (dipakai langganan stateStream).
  Future<void> saveAll({
    required double speed,
    required double pitch,
    required bool skipSilence,
  }) async {
    await setSpeed(speed);
    await setPitch(pitch);
    await setSkipSilence(skipSilence);
  }
}
