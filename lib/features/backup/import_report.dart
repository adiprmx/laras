/// Laporan hasil impor (P8, PRD B10.4): pola bersama impor backup dan
/// impor Spotify.
///
/// Laporan menampilkan tiga angka (berhasil / sudah ada / gagal) plus
/// alasan per lagu yang gagal, dalam bahasa sehari-hari (pemetaan alasan
/// ke string tinggal di UI, ARB). Laporan TIDAK disimpan permanen:
/// sesudah ditutup, laporan hilang; datanya tetap tersimpan.
library;

/// Alasan satu lagu gagal masuk saat impor.
enum ImportFailureReason {
  /// Tidak ada padanan di YouTube Music (impor Spotify).
  notFound,

  /// Pengguna melewati lagu ini di layar kandidat (cadangan untuk
  /// pemilih kandidat pasca-P8; P8 tidak menghasilkannya).
  skipped,

  /// Pengguna membatalkan di tengah jalan.
  cancelled,

  /// Antrean sudah penuh (200 item) sehingga sisanya tidak masuk.
  queueFull,

  /// Pencarian lagu ini gagal (bukan karena jaringan).
  searchFailed,

  /// Jaringan putus di tengah pencocokan.
  network,
}

/// Satu lagu yang gagal masuk, beserta alasannya.
class ImportFailure {
  const ImportFailure({required this.label, required this.reason});

  /// Label tampil: "Artis - Judul" atau judul saja.
  final String label;

  final ImportFailureReason reason;
}

/// Ringkasan hasil satu impor.
class ImportReport {
  const ImportReport({
    required this.succeeded,
    required this.alreadyExisted,
    this.failures = const <ImportFailure>[],
    this.playlistId,
    this.playlistName,
    this.downloadedSongIds = const <String>[],
    this.exportedAt,
    this.appVersion,
  });

  /// Jumlah item baru yang masuk (lagu, entri playlist, riwayat,
  /// antrean — tergantung jalur impor).
  final int succeeded;

  /// Jumlah item yang dilewati karena sudah ada.
  final int alreadyExisted;

  /// Lagu yang gagal, masing-masing dengan alasannya.
  final List<ImportFailure> failures;

  /// Playlist hasil impor Spotify (null untuk impor backup, dan null
  /// bila tidak ada satu pun lagu yang cocok — playlist kosong tidak
  /// dibuat, PRD B10.4).
  final int? playlistId;

  /// Nama playlist hasil impor Spotify.
  final String? playlistName;

  /// Id lagu yang dulu terunduh (menurut file salinan) tapi belum
  /// terunduh di HP ini — penggerak tombol "Unduh ulang" (PRD B7.5).
  final List<String> downloadedSongIds;

  /// Tanggal file salinan dibuat (hanya impor backup).
  final DateTime? exportedAt;

  /// Versi app yang membuat file salinan (hanya impor backup).
  final String? appVersion;

  int get failed => failures.length;

  bool get hasFailures => failures.isNotEmpty;

  /// Total item yang diproses.
  int get total => succeeded + alreadyExisted + failed;
}
