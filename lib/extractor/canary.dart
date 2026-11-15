/// Deteksi kanari: resolve 5 lagu kanari saat start dingin untuk menilai
/// kesehatan layanan.
///
/// Ambang rusak (arsitektur 3.5):
/// - 3 resolve kanari gagal berturut-turut dengan penyebab yang sama, atau
/// - lebih dari 50% resolve kanari gagal dalam 1 jam.
///
/// Kegagalan jaringan (tidak ada internet) DIABAIKAN saat menghitung
/// ambang: jaringan pengguna yang putus bukan bukti YouTube berubah.
/// Riwayat kegagalan disimpan di SharedPreferences supaya ambang
/// "berturut-turut" bertahan antar start app.
library;

// ignore_for_file: prefer_initializing_formals - konstruktor publik memakai
// parameter bernama publik + field privat; initializing formal akan
// membuat nama parameter menjadi privat dan tidak bisa dipakai pemanggil.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'errors.dart';
import 'fallback_orchestrator.dart';

/// Status layanan dari cek kanari.
enum CanaryStatus {
  /// Semua lagu kanari bisa di-resolve (atau hanya gagal karena jaringan).
  ok,

  /// Sebagian lagu kanari gagal (1-2 dari 5) dengan penyebab non-jaringan.
  degraded,

  /// Ambang rusak tercapai: layanan dianggap bermasalah.
  broken,
}

/// Hasil satu cek kanari.
class CanaryCheckResult {
  const CanaryCheckResult({
    required this.status,
    required this.checkedAt,
    required this.succeeded,
    required this.failed,
    required this.networkFailures,
    this.dominantCause,
  });

  final CanaryStatus status;
  final DateTime checkedAt;

  /// Jumlah lagu kanari yang berhasil di-resolve.
  final int succeeded;

  /// Jumlah yang gagal karena penyebab non-jaringan.
  final int failed;

  /// Jumlah yang gagal karena jaringan (diabaikan di ambang).
  final int networkFailures;

  /// Penyebab non-jaringan yang paling sering muncul, bila ada.
  final ResolveFailureCause? dominantCause;
}

const String _kCanaryHistoryKey = 'laras.canary_history';
const String _kCanaryStreakKey = 'laras.canary_streak';

/// Pemeriksa kanari.
class CanaryChecker {
  CanaryChecker({
    required StreamResolver resolver,
    required SharedPreferences prefs,
    required List<String> videoIds,
  }) : _resolver = resolver,
       _prefs = prefs,
       _videoIds = videoIds;

  final StreamResolver _resolver;
  final SharedPreferences _prefs;
  final List<String> _videoIds;

  /// Jalankan cek kanari (resolve semua lagu kanari, tanpa memutar).
  Future<CanaryCheckResult> check() async {
    int succeeded = 0;
    int failed = 0;
    int networkFailures = 0;
    final Map<ResolveFailureCause, int> causes = <ResolveFailureCause, int>{};
    for (final String videoId in _videoIds) {
      try {
        await _resolver
            .resolve(videoId)
            .timeout(const Duration(seconds: 90));
        succeeded++;
      } on ExtractorException catch (e) {
        if (e.isNetworkError) {
          networkFailures++;
        } else {
          failed++;
          causes[e.cause] = (causes[e.cause] ?? 0) + 1;
        }
      } on Object {
        // Timeout atau error tak terduga dihitung sebagai gagal parse
        // (bukan jaringan) supaya tidak lolos diam-diam.
        failed++;
        causes[ResolveFailureCause.parseFailed] =
            (causes[ResolveFailureCause.parseFailed] ?? 0) + 1;
      }
    }
    ResolveFailureCause? dominant;
    int dominantCount = 0;
    for (final MapEntry<ResolveFailureCause, int> e in causes.entries) {
      if (e.value > dominantCount) {
        dominant = e.key;
        dominantCount = e.value;
      }
    }
    final DateTime now = DateTime.now();
    final CanaryStatus status = _evaluate(
      now: now,
      failed: failed,
      total: _videoIds.length,
      dominantCause: dominant,
    );
    return CanaryCheckResult(
      status: status,
      checkedAt: now,
      succeeded: succeeded,
      failed: failed,
      networkFailures: networkFailures,
      dominantCause: dominant,
    );
  }

  CanaryStatus _evaluate({
    required DateTime now,
    required int failed,
    required int total,
    required ResolveFailureCause? dominantCause,
  }) {
    // Perbarui riwayat per-video (untuk ambang >50% dalam 1 jam).
    final List<Map<String, dynamic>> history = _readHistory();
    history.add(<String, dynamic>{
      't': now.toIso8601String(),
      'failed': failed,
      'total': total,
    });
    // Hanya simpan 1 jam terakhir + batasi 50 entri.
    final DateTime hourAgo = now.subtract(const Duration(hours: 1));
    history.removeWhere((e) {
      final DateTime? t = DateTime.tryParse(e['t'] as String? ?? '');
      return t == null || t.isBefore(hourAgo);
    });
    while (history.length > 50) {
      history.removeAt(0);
    }
    _prefs.setString(_kCanaryHistoryKey, jsonEncode(history));

    // Ambang 1: >50% gagal dalam 1 jam.
    int failedInHour = 0;
    int totalInHour = 0;
    for (final Map<String, dynamic> e in history) {
      failedInHour += e['failed'] as int? ?? 0;
      totalInHour += e['total'] as int? ?? 0;
    }
    if (totalInHour >= 5 && failedInHour * 2 > totalInHour) {
      return CanaryStatus.broken;
    }

    // Ambang 2: 3 cek berturut-turut dengan penyebab dominan yang sama.
    if (dominantCause != null && failed > 0) {
      final Map<String, dynamic> streak = _readStreak();
      final String causeName = dominantCause.name;
      if (streak['cause'] == causeName) {
        final int count = (streak['count'] as int? ?? 0) + 1;
        _prefs.setString(
          _kCanaryStreakKey,
          jsonEncode(<String, dynamic>{'cause': causeName, 'count': count}),
        );
        if (count >= 3) return CanaryStatus.broken;
      } else {
        _prefs.setString(
          _kCanaryStreakKey,
          jsonEncode(<String, dynamic>{'cause': causeName, 'count': 1}),
        );
      }
    } else if (failed == 0) {
      // Cek bersih: reset streak.
      _prefs.remove(_kCanaryStreakKey);
    }

    if (failed > 0) return CanaryStatus.degraded;
    return CanaryStatus.ok;
  }

  List<Map<String, dynamic>> _readHistory() {
    try {
      final String? raw = _prefs.getString(_kCanaryHistoryKey);
      if (raw == null) return <Map<String, dynamic>>[];
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .toList(growable: true);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic> _readStreak() {
    try {
      final String? raw = _prefs.getString(_kCanaryStreakKey);
      if (raw == null) return <String, dynamic>{};
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
