/// Klasifikasi kegagalan resolve ke 6 penyebab (PRD 5.1, arsitektur 3.5).
///
/// Enam penyebab ini yang membedakan "YouTube berubah" dari "jaringan
/// pengguna putus". Deteksi kanari memakai klasifikasi ini untuk ambang
/// rusak: 3 resolve kanari gagal berturut-turut dengan penyebab yang sama.
/// Pesan ke pengguna tidak pernah memakai nama penyebab ini mentah-mentah;
/// layar memetakan penyebab ke string bahasa sehari-hari di ARB.
library;

/// Enam penyebab kegagalan resolve.
enum ResolveFailureCause {
  /// Server mengembalikan HTTP 403 (format diblokir, token ditolak).
  httpForbidden,

  /// Respons kosong atau jaringan gagal total (tidak ada respons yang bisa
  /// dibaca). Kegagalan transport (DNS, koneksi putus, timeout koneksi)
  /// masuk ke sini; [ExtractorException.isNetworkError] membedakan
  /// "tidak ada jaringan" dari "server menjawab kosong".
  emptyResponse,

  /// Respons ada tapi strukturnya tidak bisa di-parse (YouTube mengubah
  /// bentuk respons).
  parseFailed,

  /// Semua format yang dikembalikan adalah SABR; tidak ada URL audio
  /// konvensional.
  sabrOnly,

  /// Solver QuickJS kehabisan waktu (batas 10 detik) atau kehabisan memori.
  solverTimeout,

  /// Hash player di respons tidak dikenal tabel config remote dan ekstraksi
  /// nama fungsi dari base.js gagal.
  unknownPlayerHash,
}

/// Kegagalan resolve satu lagu (atau satu client di dalam resolve).
class ExtractorException implements Exception {
  const ExtractorException(
    this.cause, {
    this.clientName,
    this.isNetworkError = false,
    this.isTimeout = false,
    this.detail,
  });

  final ResolveFailureCause cause;

  /// Client yang gagal, bila kegagalan terjadi pada satu client tertentu.
  final String? clientName;

  /// Benar bila penyebabnya adalah jaringan perangkat (tidak ada internet,
  /// DNS gagal, koneksi putus), bukan server. Deteksi kanari mengabaikan
  /// kegagalan jaringan saat menghitung ambang rusak: jaringan pengguna
  /// yang putus bukan bukti YouTube berubah.
  final bool isNetworkError;

  /// Benar bila penyebabnya adalah timeout: jaringan hidup tapi request
  /// tidak selesai sebelum batas waktu. Selalu dibarengi [isNetworkError].
  /// Dipakai pemutar untuk membedakan pesan "internet lambat, coba lagi"
  /// dari "tidak ada internet". Timeout solver QuickJS (komputasi lokal,
  /// bukan jaringan) TIDAK memakai flag ini.
  final bool isTimeout;

  /// Detail teknis untuk log internal. Tidak pernah berisi URL stream.
  final String? detail;

  @override
  String toString() {
    final buffer = StringBuffer('ExtractorException($cause');
    if (clientName != null) buffer.write(', client: $clientName');
    if (isNetworkError) buffer.write(', network');
    if (isTimeout) buffer.write(', timeout');
    if (detail != null) buffer.write(', $detail');
    buffer.write(')');
    return buffer.toString();
  }
}
