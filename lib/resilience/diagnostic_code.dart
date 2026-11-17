/// Kode diagnostik singkat (P6, tambahan verdict owner 18:56 WIB).
///
/// Satu baris huruf-angka yang merangkum kegagalan terakhir, untuk
/// ditempel owner di chat atau dikirim lewat email laporan kerusakan.
/// Semua data lokal (tidak ada kirim apa pun, berfungsi offline).
///
/// FORMAT — legenda untuk tim:
///
///   `LRS1-JK-DDMMHHMM-KLIEN-APP-CFG-LAYANAN`
///
///   LRS1     = format kode diagnostik Laras v1.
///   J        = jenis gagal: N jaringan, T timeout (lambat), U tidak
///              bisa diputar, X tidak ada kegagalan tercatat.
///   K        = penyebab (2 huruf): FH ditolak (403), ER jawaban
///              kosong, PF bentuk respons berubah, SB format baru
///              (SABR), ST lama disiapkan, UH pemutar berubah,
///              XX tidak diketahui.
///   DDMMHHMM = waktu kegagalan terakhir, waktu lokal HP (8 digit,
///              tanpa tahun — kode ditempel segera setelah gagal).
///   KLIEN    = client yang dicoba pada putaran gagal terakhir,
///              inisial berurutan: W WEB_REMIX, M MWEB, V ANDROID_VR,
///              ? nama tidak dikenal; X bila tidak ada data.
///   APP      = versi app tanpa titik + build: 1.0.0+2 -> 1002.
///   CFG      = config: R + tanggal versi client utama (R20261110)
///              bila config jarak jauh, B bila config bawaan.
///   LAYANAN  = status kanari: O normal, D terganggu, B bermasalah,
///              ? belum pernah diperiksa.
///
/// Contoh: `LRS1-UPF-16191905-WMV-1002-R20261110-D`
///   = lagu tidak bisa diputar karena bentuk respons berubah,
///     16 Nov 19:05, ketiga client dicoba, app 1.0.0+2,
///     config remote 2026-11-10, layanan terganggu.
///
/// PRIVASI: kode TIDAK berisi judul lagu, videoId, URL, alamat IP,
/// email, cookie, token, atau isi database — hanya jenis + penyebab +
/// waktu + client + versi. Data kegagalan dibaca dari snapshot player
/// (`lastError`) + log resolve per client (`recentLog`, sudah berisi
/// penyebab terstruktur dari P0-2) + status kanari + versi config.
library;

import 'package:laras/extractor/canary.dart';
import 'package:laras/extractor/errors.dart';
import 'package:laras/extractor/models.dart';
import 'package:laras/player/player_state.dart';

/// Data mentah untuk satu kode diagnostik. Semua field opsional kecuali
/// versi app: bila tidak ada kegagalan tercatat, kode tetap dibuat
/// (jenis X, penyebab XX) supaya tim tahu "tidak ada yang tercatat".
class DiagnosticData {
  const DiagnosticData({
    this.kind,
    this.cause,
    this.failedAt,
    this.clientsTried = const <String>[],
    required this.appVersion,
    required this.appBuild,
    this.configVersion,
    this.configIsRemote = false,
    this.serviceStatus,
  });

  /// Jenis kegagalan terakhir (dari `PlaybackFailure.kind`).
  final PlaybackFailureKind? kind;

  /// Penyebab resolve terakhir (dari `PlaybackFailure.cause` atau log).
  final ResolveFailureCause? cause;

  /// Waktu kegagalan terakhir (dari entri log). Null bila tidak ada
  /// entri gagal di log — pemakaian waktu pembuatan kode saat itu.
  final DateTime? failedAt;

  /// Nama client yang dicoba pada putaran gagal terakhir, berurutan
  /// (mis. `['WEB_REMIX', 'MWEB', 'ANDROID_VR']`).
  final List<String> clientsTried;

  /// Versi app, mis. '1.0.0'.
  final String appVersion;

  /// Build app, mis. 2.
  final int appBuild;

  /// Versi client utama di config aktif, mis. '1.20261110.04.00'.
  final String? configVersion;

  /// Benar bila config berasal dari server (bukan bawaan app).
  final bool configIsRemote;

  /// Status layanan dari kanari. Null bila belum pernah diperiksa.
  final CanaryStatus? serviceStatus;
}

/// Rakit kode diagnostik dari [data].
///
/// Murni dan tidak pernah melempar: field yang hilang diganti huruf
/// "tidak diketahui" (X / XX / ? / B). [now] hanya untuk tes.
String buildDiagnosticCode(DiagnosticData data, {DateTime? now}) {
  final String kind = switch (data.kind) {
    PlaybackFailureKind.network => 'N',
    PlaybackFailureKind.timeout => 'T',
    PlaybackFailureKind.unplayable => 'U',
    null => 'X',
  };
  final String cause = switch (data.cause) {
    ResolveFailureCause.httpForbidden => 'FH',
    ResolveFailureCause.emptyResponse => 'ER',
    ResolveFailureCause.parseFailed => 'PF',
    ResolveFailureCause.sabrOnly => 'SB',
    ResolveFailureCause.solverTimeout => 'ST',
    ResolveFailureCause.unknownPlayerHash => 'UH',
    null => 'XX',
  };
  final DateTime at = data.failedAt ?? now ?? DateTime.now();
  final String time =
      '${_two(at.day)}${_two(at.month)}${_two(at.hour)}${_two(at.minute)}';
  final String clients = data.clientsTried.isEmpty
      ? 'X'
      : data.clientsTried.map(_clientInitial).join();
  final String app =
      '${data.appVersion.replaceAll(RegExp(r'[^0-9]'), '')}${data.appBuild}';
  final String config = _configSegment(data.configVersion, data.configIsRemote);
  final String service = switch (data.serviceStatus) {
    CanaryStatus.ok => 'O',
    CanaryStatus.degraded => 'D',
    CanaryStatus.broken => 'B',
    null => '?',
  };
  return 'LRS1-$kind$cause-$time-$clients-$app-$config-$service';
}

String _two(int value) => value.toString().padLeft(2, '0');

String _clientInitial(String name) {
  switch (name) {
    case 'WEB_REMIX':
      return 'W';
    case 'MWEB':
      return 'M';
    case 'ANDROID_VR':
      return 'V';
    default:
      return '?';
  }
}

/// Segmen config: `R<tanggal>` bila remote dan versinya mengandung
/// tanggal 8 digit (mis. 1.20261110.04.00 -> R20261110), `R` bila
/// remote tapi versinya tidak mengandung tanggal, `B` bila bawaan.
String _configSegment(String? version, bool isRemote) {
  if (!isRemote) return 'B';
  if (version == null || version.isEmpty) return 'R';
  for (final String part in version.split('.')) {
    if (part.length == 8 &&
        part.startsWith('20') &&
        int.tryParse(part) != null) {
      return 'R$part';
    }
  }
  return 'R';
}

/// Kumpulkan [DiagnosticData] dari sumber yang sudah ada.
///
/// - Jenis + penyebab: dari [lastFailure] bila ada; bila log punya
///   entri gagal yang lebih baru, penyebab diambil dari log.
/// - Waktu gagal + client yang dicoba: dari [recentLog] — entri gagal
///   terbaru (penyebab terisi, atau gagal jaringan/timeout) ditambah
///   semua upaya untuk videoId yang sama dalam putaran yang sama.
///   Putaran dirangkai mundur dari entri gagal: upaya termasuk selama
///   jeda ke upaya berikutnya <= 60 detik (rantai, bukan jendela kaku
///   — satu resolve lambat bisa makan waktu > 60 detik total).
///   Upaya yang dilewati (skipped) tidak dihitung: client itu tidak
///   benar-benar dicoba. Entri `SCRIPT` (langkah muat script player,
///   bukan client) tidak dihitung sebagai client, tapi penyebab +
///   waktunya tetap dipakai bila itu entri gagal terbaru.
/// - Versi config + status layanan diteruskan apa adanya.
///
/// Murni (tidak membaca service apa pun): pemanggil yang mengambil
/// snapshot player, log resolver, status kanari, dan versi config.
DiagnosticData collectDiagnosticData({
  PlaybackFailure? lastFailure,
  List<ResolveLogEntry> recentLog = const <ResolveLogEntry>[],
  CanaryStatus? serviceStatus,
  String? configVersion,
  bool configIsRemote = false,
  required String appVersion,
  required int appBuild,
}) {
  ResolveLogEntry? latestFailure;
  int latestFailureIndex = -1;
  for (int i = recentLog.length - 1; i >= 0; i--) {
    final ResolveLogEntry entry = recentLog[i];
    if (entry.skipped) continue;
    if (entry.cause != null || entry.isNetworkError || entry.isTimeout) {
      latestFailure = entry;
      latestFailureIndex = i;
      break;
    }
  }

  List<String> clients = const <String>[];
  DateTime? failedAt;
  ResolveFailureCause? cause = lastFailure?.cause;
  PlaybackFailureKind? kind = lastFailure?.kind;

  if (latestFailure != null) {
    failedAt = latestFailure.timestamp;
    cause ??= latestFailure.cause;
    kind ??= latestFailure.isNetworkError
        ? PlaybackFailureKind.network
        : latestFailure.isTimeout
        ? PlaybackFailureKind.timeout
        : PlaybackFailureKind.unplayable;
    // Satu putaran dirangkai mundur dari entri gagal: jalan ke belakang
    // dalam log (log terurut kronologis), sertakan upaya dengan videoId
    // sama selama jeda ke upaya yang sudah termasuk <= 60 detik. Rantai
    // putus pada jeda pertama yang lebih lama (putaran lebih lama).
    // Entri videoId lain dilewati tanpa memutus rantai (putaran lagu
    // lain bisa terselip di tengah). SCRIPT + skipped bukan client.
    final List<String> tried = <String>[];
    DateTime chainAt = latestFailure.timestamp;
    for (int i = latestFailureIndex; i >= 0; i--) {
      final ResolveLogEntry entry = recentLog[i];
      if (entry.videoId != latestFailure.videoId) continue;
      if (chainAt.difference(entry.timestamp) >
          const Duration(seconds: 60)) {
        break;
      }
      chainAt = entry.timestamp;
      if (entry.skipped || entry.clientName == 'SCRIPT') continue;
      if (!tried.contains(entry.clientName)) {
        tried.insert(0, entry.clientName);
      }
    }
    clients = tried;
  }

  return DiagnosticData(
    kind: kind,
    cause: cause,
    failedAt: failedAt,
    clientsTried: clients,
    appVersion: appVersion,
    appBuild: appBuild,
    configVersion: configVersion,
    configIsRemote: configIsRemote,
    serviceStatus: serviceStatus,
  );
}
