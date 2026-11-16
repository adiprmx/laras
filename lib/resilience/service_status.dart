/// Status layanan (P6, tugas 1/3/4).
///
/// Membungkus [CanaryChecker] + [RemoteConfigLoader]:
/// - cek kanari sekali sehari di latar ([checkIfDue]) — tidak pernah
///   melempar, tidak pernah mengubah status karena kegagalan jaringan;
/// - "Periksa pembaruan" ([checkForUpdates]) — paksa refresh config di
///   luar TTL lalu cek kanari ulang, hasilnya jujur
///   ([UpdateCheckResult]).
///
/// Status terakhir + waktu periksa disimpan di SharedPreferences supaya
/// banner beranda bisa tampil sebelum cek pertama selesai.
library;

// ignore_for_file: prefer_initializing_formals - konstruktor publik memakai
// parameter bernama publik + field privat; initializing formal akan
// membuat nama parameter menjadi privat dan tidak bisa dipakai pemanggil.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:laras/extractor/canary.dart';
import 'package:laras/extractor/client_definitions.dart';
import 'package:laras/extractor/remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kStatusKey = 'laras.service_status';
const String _kCheckedAtKey = 'laras.service_checked_at_ms';

/// Jeda minimum antar cek kanari otomatis: sekali sehari.
const Duration kServiceCheckInterval = Duration(hours: 24);

/// Hasil tombol "Periksa pembaruan".
enum UpdateCheckResult {
  /// Config sudah terbaru dan layanan baik.
  upToDateOk,

  /// Config baru dipakai dan layanan kembali baik.
  updatedOk,

  /// Layanan masih bermasalah (atau config gagal diambil).
  stillBroken,

  /// Semua probe gagal karena jaringan — tidak ada internet.
  noInternet,
}

/// Cuplikan status layanan untuk UI.
class ServiceStatusSnapshot {
  const ServiceStatusSnapshot({
    required this.status,
    this.checkedAt,
    this.checking = false,
  });

  final CanaryStatus status;
  final DateTime? checkedAt;
  final bool checking;

  ServiceStatusSnapshot copyWith({
    CanaryStatus? status,
    DateTime? checkedAt,
    bool? checking,
  }) {
    return ServiceStatusSnapshot(
      status: status ?? this.status,
      checkedAt: checkedAt ?? this.checkedAt,
      checking: checking ?? this.checking,
    );
  }
}

/// Layanan status: cek kanari berkala + "Periksa pembaruan".
class ServiceStatusService {
  ServiceStatusService({
    required CanaryChecker canary,
    required RemoteConfigLoader config,
    required SharedPreferences prefs,
    DateTime Function()? now,
  }) : _canary = canary,
       _config = config,
       _prefs = prefs,
       _now = now ?? DateTime.now,
       status = ValueNotifier<ServiceStatusSnapshot>(
         ServiceStatusSnapshot(
           status: _readStatus(prefs.getString(_kStatusKey)),
           checkedAt: _readCheckedAt(prefs.getInt(_kCheckedAtKey)),
         ),
       );

  final CanaryChecker _canary;
  final RemoteConfigLoader _config;
  final SharedPreferences _prefs;
  final DateTime Function() _now;

  /// Status saat ini (didengarkan banner beranda + layar status).
  final ValueNotifier<ServiceStatusSnapshot> status;

  /// Apakah layanan sedang dianggap rusak (ambang kanari tercapai).
  /// Dipakai penjaga penandaan lagu (kerusakan massal tidak menandai
  /// lagu satu per satu).
  bool get isBroken => status.value.status == CanaryStatus.broken;

  /// Info config aktif untuk kode diagnostik: versi client utama +
  /// apakah config berasal dari server (bukan bawaan app).
  ///
  /// Tidak pernah melempar: bila config tidak bisa dibaca, kembalikan
  /// versi kosong + `isRemote: false` (kode menjadi segmen `B`).
  Future<({String version, bool isRemote})> currentConfigInfo() async {
    try {
      final RemotePlayerConfig config = await _config.current();
      return (
        version: config.clients.isEmpty ? '' : config.clients.first.version,
        isRemote: config.isRemote,
      );
    } on Object {
      return (version: '', isRemote: false);
    }
  }

  bool _dailyRunning = false;
  Future<UpdateCheckResult>? _updateInFlight;

  /// Cek kanari bila sudah waktunya (terakhir cek > 24 jam lalu).
  ///
  /// Tidak pernah melempar. Tidak mengubah status bila semua probe
  /// gagal karena jaringan. Dilewati bila ada cek lain yang berjalan.
  Future<void> checkIfDue() async {
    if (_dailyRunning || _updateInFlight != null) return;
    final DateTime? last = status.value.checkedAt;
    if (last != null && _now().difference(last) < kServiceCheckInterval) {
      return;
    }
    _dailyRunning = true;
    try {
      await _runCanary();
    } finally {
      _dailyRunning = false;
    }
  }

  /// "Periksa pembaruan": paksa refresh config lalu cek kanari ulang.
  ///
  /// Pemanggilan bersamaan digabung (satu cek, hasil yang sama).
  /// Tidak pernah melempar: kegagalan tak terduga dilaporkan sebagai
  /// [UpdateCheckResult.stillBroken].
  Future<UpdateCheckResult> checkForUpdates() {
    final Future<UpdateCheckResult>? inFlight = _updateInFlight;
    if (inFlight != null) return inFlight;
    final Future<UpdateCheckResult> job = _checkForUpdates();
    _updateInFlight = job;
    return job.whenComplete(() {
      _updateInFlight = null;
    });
  }

  Future<UpdateCheckResult> _checkForUpdates() async {
    _setChecking(true);
    try {
      final RemotePlayerConfig before = await _config.current();
      final RemotePlayerConfig after = await _config.refresh(force: true);
      // Bandingkan ISI config, bukan fetchedAt: refresh selalu menulis
      // fetchedAt baru walau isinya sama persis.
      final bool changed = _fingerprint(after) != _fingerprint(before);
      final CanaryCheckResult? result = await _runCanary();
      if (result == null) return UpdateCheckResult.noInternet;
      if (result.status == CanaryStatus.ok) {
        return changed
            ? UpdateCheckResult.updatedOk
            : UpdateCheckResult.upToDateOk;
      }
      return UpdateCheckResult.stillBroken;
    } on Object {
      return UpdateCheckResult.stillBroken;
    } finally {
      _setChecking(false);
    }
  }

  /// Jalankan satu cek kanari dan simpan hasilnya.
  ///
  /// Mengembalikan null bila semua probe gagal karena jaringan (status
  /// tidak diubah, waktu periksa tidak dimajukan — cek berikutnya
  /// mencoba lagi) atau bila cek gagal total.
  Future<CanaryCheckResult?> _runCanary() async {
    _setChecking(true);
    try {
      final CanaryCheckResult result = await _canary.check();
      if (result.succeeded == 0 &&
          result.failed == 0 &&
          result.networkFailures > 0) {
        return null;
      }
      final DateTime checkedAt = _now();
      status.value = ServiceStatusSnapshot(
        status: result.status,
        checkedAt: checkedAt,
        checking: status.value.checking,
      );
      await _prefs.setString(_kStatusKey, result.status.name);
      await _prefs.setInt(_kCheckedAtKey, checkedAt.millisecondsSinceEpoch);
      return result;
    } on Object {
      return null;
    } finally {
      _setChecking(false);
    }
  }

  void _setChecking(bool checking) {
    final ServiceStatusSnapshot current = status.value;
    if (current.checking == checking) return;
    status.value = current.copyWith(checking: checking);
  }

  /// Sidik jari isi config (tanpa fetchedAt): urutan client, hash
  /// player, dan daftar kanari. Dua config dengan sidik jari sama
  /// dianggap tidak berubah.
  static String _fingerprint(RemotePlayerConfig config) {
    final String clients = config.clients
        .map(
          (ClientDefinition d) =>
              '${d.name}|${d.version}|${d.clientId}|${d.userAgent}',
        )
        .join(',');
    final List<MapEntry<String, int>> hashes = config.playerHashes.entries
        .toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            a.key.compareTo(b.key),
      );
    final String hashPart = hashes
        .map((MapEntry<String, int> e) => '${e.key}=${e.value}')
        .join(',');
    return '$clients#$hashPart#${config.canaryVideoIds.join(',')}';
  }

  static CanaryStatus _readStatus(String? raw) {
    switch (raw) {
      case 'degraded':
        return CanaryStatus.degraded;
      case 'broken':
        return CanaryStatus.broken;
      case 'ok':
      default:
        return CanaryStatus.ok;
    }
  }

  static DateTime? _readCheckedAt(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);

  void dispose() {
    status.dispose();
  }
}
