/// Equalizer Android (P7): memakai `android.media.audiofx.Equalizer`
/// yang ditempel ke audio session id just_audio — tanpa dependensi baru.
///
/// Alur: Dart meminta session id dari port, lalu `attach(sessionId)`
/// memanggil platform (`init`): platform membuat Equalizer dan
/// mengembalikan daftar pita (frekuensi tengah dalam mHz), rentang level
/// (mB, 1 dB = 100 mB), dan preset bawaan perangkat. Pengaturan (aktif,
/// preset, level kustom) disimpan di SharedPreferences dan diterapkan
/// ulang tiap kali session id berubah.
///
/// Batasan yang jujur: equalizer hanya ada bila HP menyediakan efek
/// audio itu (sebagian HP tidak punya — `init` mengembalikan
/// `available: false` dan UI menampilkan pesan `noEqualizer`); session
/// id baru ada sesudah lagu dimuat, jadi sebelum itu UI menampilkan
/// pesan `equalizerNeedsSong`. Efek berlaku untuk output audio perangkat
/// (bukan per lagu) dan hanya di Android — di platform lain service ini
/// tidak pernah di-attach (port mengembalikan null).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Satu pita equalizer: frekuensi tengah + level saat ini.
class EqualizerBand {
  const EqualizerBand({
    required this.index,
    required this.centerFreqMilliHz,
    required this.levelMillibels,
  });

  final int index;

  /// Frekuensi tengah pita dalam mili-Hz (mis. 60000 = 60 Hz).
  final int centerFreqMilliHz;

  /// Level saat ini dalam mili-Bel (100 mB = 1 dB).
  final int levelMillibels;

  EqualizerBand copyWith({int? levelMillibels}) {
    return EqualizerBand(
      index: index,
      centerFreqMilliHz: centerFreqMilliHz,
      levelMillibels: levelMillibels ?? this.levelMillibels,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EqualizerBand &&
      other.index == index &&
      other.centerFreqMilliHz == centerFreqMilliHz &&
      other.levelMillibels == levelMillibels;

  @override
  int get hashCode =>
      Object.hash(index, centerFreqMilliHz, levelMillibels);
}

/// Info equalizer perangkat: pita, rentang level, preset.
class EqualizerInfo {
  const EqualizerInfo({
    required this.bands,
    required this.minLevelMillibels,
    required this.maxLevelMillibels,
    required this.presets,
    required this.currentPreset,
  });

  /// Pita, urut frekuensi menaik.
  final List<EqualizerBand> bands;

  /// Level terendah yang diizinkan perangkat (mB, biasanya negatif).
  final int minLevelMillibels;

  /// Level tertinggi yang diizinkan perangkat (mB).
  final int maxLevelMillibels;

  /// Nama preset bawaan perangkat (mis. "Normal", "Rock").
  final List<String> presets;

  /// Indeks preset yang aktif, atau -1 bila level diatur sendiri.
  final int currentPreset;

  EqualizerInfo copyWith({
    List<EqualizerBand>? bands,
    int? currentPreset,
  }) {
    return EqualizerInfo(
      bands: bands ?? this.bands,
      minLevelMillibels: minLevelMillibels,
      maxLevelMillibels: maxLevelMillibels,
      presets: presets,
      currentPreset: currentPreset ?? this.currentPreset,
    );
  }
}

/// Format frekuensi tengah pita untuk label slider: "60 Hz", "230 Hz",
/// "1 kHz", "3,6 kHz" (koma desimal, sesuai format angka app).
String formatEqualizerFrequency(int centerFreqMilliHz) {
  final double hz = centerFreqMilliHz / 1000;
  if (hz < 1000) return '${hz.round()} Hz';
  final double khz = hz / 1000;
  final String text = khz == khz.roundToDouble()
      ? khz.round().toString()
      : khz.toStringAsFixed(1).replaceAll('.', ',');
  return '$text kHz';
}

/// Service equalizer: jembatan Dart ke efek audio Android.
class EqualizerService {
  EqualizerService({MethodChannel? channel, SharedPreferences? prefs})
    : _channel = channel ?? const MethodChannel(_kChannel),
      _prefs = prefs; // ignore: prefer_initializing_formals

  static const String _kChannel = 'id.my.adipmusic.laras/equalizer';

  static const String enabledKey = 'laras.eq_enabled';
  static const String presetKey = 'laras.eq_preset';
  static const String levelsKey = 'laras.eq_levels';

  final MethodChannel _channel;
  final SharedPreferences? _prefs;

  /// Info equalizer terakhir; null bila belum attach / tidak tersedia.
  final ValueNotifier<EqualizerInfo?> info = ValueNotifier<EqualizerInfo?>(
    null,
  );

  /// Equalizer aktif atau tidak (tersimpan; default mati).
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  int? _sessionId;
  bool _disposed = false;

  /// Tempel equalizer ke audio session [sessionId].
  ///
  /// Null berarti lepas (tidak ada lagu yang dimuat). Id yang sama
  /// dengan sebelumnya adalah no-op. Pengaturan tersimpan diterapkan
  /// ulang sesudah init berhasil.
  Future<void> attach(int? sessionId) async {
    if (_disposed) return;
    if (sessionId == _sessionId) return;
    await _release();
    _sessionId = sessionId;
    info.value = null;
    if (sessionId == null) return;
    try {
      final Map<dynamic, dynamic>? result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('init', <String, Object>{
            'sessionId': sessionId,
          });
      if (result == null || result['available'] != true) return;
      final List<dynamic> freqs = result['centerFreqs'] as List<dynamic>? ??
          <dynamic>[];
      final List<dynamic> levels = result['levels'] as List<dynamic>? ??
          <dynamic>[];
      final List<dynamic> presetNames =
          result['presets'] as List<dynamic>? ?? <dynamic>[];
      final List<EqualizerBand> bands = <EqualizerBand>[
        for (int i = 0; i < freqs.length; i++)
          EqualizerBand(
            index: i,
            centerFreqMilliHz: (freqs[i] as num).toInt(),
            levelMillibels: i < levels.length
                ? (levels[i] as num).toInt()
                : 0,
          ),
      ];
      info.value = EqualizerInfo(
        bands: bands,
        minLevelMillibels: (result['minLevel'] as num?)?.toInt() ?? -1500,
        maxLevelMillibels: (result['maxLevel'] as num?)?.toInt() ?? 1500,
        presets: presetNames.map((Object? e) => e.toString()).toList(),
        currentPreset: (result['currentPreset'] as num?)?.toInt() ?? -1,
      );
      await _applySavedSettings();
    } on Object {
      // Platform tidak menjawab / tidak menyediakan EQ: info tetap null
      // dan UI menampilkan pesan jujur.
      info.value = null;
    }
  }

  /// Nyalakan/matikan efek (pengaturan tersimpan).
  Future<void> setEnabled(bool value) async {
    if (_disposed || info.value == null) return;
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'setEnabled',
        <String, Object>{'enabled': value},
      );
      if (ok != true) return;
    } on Object {
      return;
    }
    enabled.value = value;
    await _prefs?.setBool(enabledKey, value);
  }

  /// Pakai preset bawaan perangkat ke-[index]. Level pita ikut berubah
  /// mengikuti preset (diambil dari platform sesudahnya).
  Future<void> setPreset(int index) async {
    final EqualizerInfo? current = info.value;
    if (_disposed || current == null) return;
    if (index < 0 || index >= current.presets.length) return;
    try {
      final List<dynamic>? levels = await _channel
          .invokeMethod<List<dynamic>>('setPreset', <String, Object>{
            'preset': index,
          });
      if (levels == null) return;
      info.value = current.copyWith(
        bands: <EqualizerBand>[
          for (int i = 0; i < current.bands.length; i++)
            current.bands[i].copyWith(
              levelMillibels: i < levels.length
                  ? (levels[i] as num).toInt()
                  : current.bands[i].levelMillibels,
            ),
        ],
        currentPreset: index,
      );
      await _prefs?.setInt(presetKey, index);
    } on Object {
      return;
    }
  }

  /// Atur level satu pita (mB). Mengubah preset aktif menjadi kustom
  /// (-1) dan menyimpan level kustom.
  Future<void> setBandLevel(int band, int levelMillibels) async {
    final EqualizerInfo? current = info.value;
    if (_disposed || current == null) return;
    if (band < 0 || band >= current.bands.length) return;
    final int clamped = levelMillibels.clamp(
      current.minLevelMillibels,
      current.maxLevelMillibels,
    );
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'setBandLevel',
        <String, Object>{'band': band, 'level': clamped},
      );
      if (ok != true) return;
    } on Object {
      return;
    }
    final List<EqualizerBand> bands = List<EqualizerBand>.of(current.bands);
    bands[band] = bands[band].copyWith(levelMillibels: clamped);
    info.value = current.copyWith(bands: bands, currentPreset: -1);
    await _prefs?.setInt(presetKey, -1);
    await _prefs?.setStringList(
      levelsKey,
      bands.map((EqualizerBand b) => b.levelMillibels.toString()).toList(),
    );
  }

  Future<void> _applySavedSettings() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final bool wasEnabled = prefs.getBool(enabledKey) ?? false;
    enabled.value = wasEnabled;
    final int preset = prefs.getInt(presetKey) ?? -1;
    if (preset >= 0) {
      await setPreset(preset);
    } else {
      final List<String>? saved = prefs.getStringList(levelsKey);
      if (saved != null && saved.isNotEmpty) {
        for (int i = 0; i < saved.length; i++) {
          final int? level = int.tryParse(saved[i]);
          if (level != null) await setBandLevel(i, level);
        }
      }
    }
    if (wasEnabled) {
      // setEnabled membaca info.value (sudah ada) — aktifkan efeknya.
      await setEnabled(true);
    }
  }

  Future<void> _release() async {
    if (_sessionId == null) return;
    _sessionId = null;
    try {
      await _channel.invokeMethod<void>('release');
    } on Object {
      // Lepas yang gagal tidak masalah: platform membersihkan sendiri
      // saat session berikutnya di-init.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _release();
    info.dispose();
    enabled.dispose();
  }
}
