/// Layanan unduhan: antrean serial, resume Range, retry 3 kali.
///
/// Aturan yang mengikat (PRD B3.2, rencana P5):
///
/// * SERIAL satu file dalam satu waktu (satu unduhan aktif). Antrean
///   FIFO dari tabel `download_jobs`, jadi tahan restart app.
/// * Resume via header `Range` dari ukuran file `.part`; server yang
///   tidak mendukung Range (balas 200, bukan 206) memicu unduh ulang
///   dari awal. File ditulis `.part` lalu di-rename setelah ukuran
///   cocok, supaya file setengah jadi tidak pernah dianggap utuh.
/// * Retry otomatis maks 3 percobaan dengan backoff 1 detik lalu 2
///   detik (+ jitter sampai 500 ms); sesudah itu job berstatus gagal
///   sampai pengguna menekan "Coba lagi" (percobaan manual mereset
///   anggaran percobaan).
/// * Dedup job memakai videoId: satu lagu hanya punya satu job.
/// * Sebelum unduh, app memeriksa ruang kosong: kurang dari perkiraan
///   ditambah buffer 100 MB berarti unduhan ditolak dengan pesan jelas
///   (bila ruang tidak bisa dibaca, pra-periksa dilewati dan
///   perlindungan terakhir adalah penanganan ENOSPC di tengah unduhan).
/// * Ruang habis di tengah unduhan (ENOSPC): job gagal jujur dengan
///   alasan "ruang penuh", file `.part` dipertahankan supaya bisa
///   dilanjutkan manual lewat resume setelah pengguna mengosongkan ruang.
/// * App ditutup di tengah unduhan: unduhan TIDAK lanjut di latar pada
///   v1 (tanpa foreground service `dataSync` — diputuskan P5, lihat
///   catatan batasan di bawah). Job kembali ke antrean saat start
///   berikutnya dan dilanjutkan otomatis dari `.part` yang tertinggal.
///
/// Batasan v1 yang dicatat jujur:
/// * Tanpa foreground service unduhan: menutup app menghentikan unduhan
///   yang sedang berjalan (job kembali ke antrean dan dilanjutkan
///   otomatis saat app dibuka lagi). Notifikasi progress unduhan ikut
///   P6 (butuh `dataSync` service + izin notifikasi).
/// * Tanpa pemantau konektivitas: job gagal karena jaringan tidak
///   dimulai ulang otomatis saat internet kembali (perlu plugin
///   connectivity atau pemantau jaringan; P6). Job tertunda dimulai
///   otomatis saat app dibuka; job gagal menunggu "Coba lagi" manual.
///
/// Penghapusan file memakai API SINKRON (`deleteSync`/`existsSync`):
/// hapus file adalah operasi metadata sub-detik, dan API async-nya tidak
/// pernah kembali bila dipanggil dari handler widget di tes widget (zona
/// FakeAsync — terbukti menggantung, 16 Nov 2026). Penulisan unduhan
/// (stream besar) tetap async.
library;

// ignore_for_file: prefer_initializing_formals - konstruktor publik memakai
// parameter bernama publik + field privat; initializing formal akan
// membuat nama parameter menjadi privat dan tidak bisa dipakai pemanggil.


import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/player/track.dart';
import 'package:laras/resilience/connectivity.dart';

import 'download_paths.dart';
import 'download_quality.dart';
import 'download_url_resolver.dart';
import 'free_space.dart';
import 'reconciler.dart';
import 'stream_cache.dart';

/// Maks percobaan unduh per job (PRD B3.2).
const int kMaxDownloadAttempts = 3;

/// Buffer ruang kosong yang wajib tersisa sesudah unduhan (PRD B3.3,
/// usulan 100 MB).
const int kFreeSpaceBufferBytes = 100 * 1024 * 1024;

/// Kode alasan gagal yang disimpan di `download_jobs.error_message`
/// (bukan teks tampil; UI memetakan ke string ARB).
abstract final class DownloadFailure {
  /// Jaringan gagal / timeout / server error.
  static const String network = 'network';

  /// Ruang HP penuh (pra-periksa atau ENOSPC di tengah unduhan).
  static const String storageFull = 'storage_full';

  /// Lagu tidak bisa diunduh (tidak tersedia, parse gagal, ukuran
  /// tidak cocok berulang).
  static const String unplayable = 'unplayable';
}

/// Satu pekerjaan unduhan beserta lagunya, siap tampil.
class DownloadJobView {
  const DownloadJobView({required this.job, required this.song});

  final DownloadJob job;
  final SongView song;

  /// Progress 0.0-1.0, atau null bila total belum diketahui.
  double? get progress {
    final int? total = job.totalBytes;
    if (total == null || total <= 0) return null;
    return (job.bytesDownloaded / total).clamp(0.0, 1.0);
  }

  bool get isActive => job.status == DownloadJobStatus.running;
}

/// Snapshot tab Unduhan: semua job + lagu terunduh + hitungan ruang.
class DownloadsSnapshot {
  const DownloadsSnapshot({
    required this.jobs,
    required this.downloaded,
    required this.stats,
  });

  const DownloadsSnapshot.empty()
    : jobs = const <DownloadJobView>[],
      downloaded = const <SongView>[],
      stats = const StorageStats.empty();

  final List<DownloadJobView> jobs;
  final List<SongView> downloaded;
  final StorageStats stats;
}

/// Layanan unduhan.
class DownloadService {
  DownloadService({
    required LibraryService library,
    required DownloadPaths paths,
    required DownloadUrlSource urlSource,
    StreamCacheService? streamCache,
    Dio? dio,
    FreeSpaceProvider? freeSpace,
    this.defaultQuality = DownloadQuality.best,
    Duration Function(int attempt)? backoffFor,
  }) : _library = library,
       _paths = paths,
       _urlSource = urlSource,
       _streamCache = streamCache,
       _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 30))),
       _freeSpace = freeSpace ?? PlatformFreeSpaceProvider(),
       _backoffFor = backoffFor ?? _defaultBackoff;

  static Duration _defaultBackoff(int attempt) {
    // Percobaan 1 gagal -> tunggu 1 dtk; percobaan 2 gagal -> 2 dtk.
    // Jitter sampai 500 ms supaya banyak perangkat tidak retry serentak.
    final int millis = attempt * 1000 + Random().nextInt(500);
    return Duration(milliseconds: millis);
  }

  final LibraryService _library;
  final DownloadPaths _paths;
  final DownloadUrlSource _urlSource;
  final StreamCacheService? _streamCache;
  final Dio _dio;
  final FreeSpaceProvider _freeSpace;

  /// Kualitas default unduhan baru (diubah P6 lewat Pengaturan).
  /// Field publik seperti [onQueueIdle]: Pengaturan menulis langsung.
  DownloadQuality defaultQuality;
  final Duration Function(int) _backoffFor;

  /// Callback saat antrean kosong (dipakai cache untuk menjalankan
  /// fetch tertunda). Di-wire main.dart.
  void Function()? onQueueIdle;

  /// Hasil rekonsiliasi terakhir (untuk snackbar satu kali di tab
  /// Unduhan). Null sebelum rekonsiliasi pertama berjalan.
  ReconcileResult? lastReconcile;

  /// Benar bila snackbar rekonsiliasi sudah ditampilkan sekali.
  bool reconcileNotified = false;

  final StreamController<DownloadsSnapshot> _stateController =
      StreamController<DownloadsSnapshot>.broadcast();

  /// Snapshot tab Unduhan (job + lagu terunduh + hitungan ruang).
  ///
  /// Stream ini broadcast: snapshot yang dikirim SEBELUM sebuah widget
  /// berlangganan HILANG untuk widget itu. Karena itu layanan menyimpan
  /// snapshot terakhir di [currentSnapshot] dan setiap StreamBuilder
  /// pemakai WAJIB memasangnya sebagai `initialData` — tanpa itu, tab
  /// Unduhan yang dibuka sesudah `start()` mengirim snapshot pertamanya
  /// akan menampilkan skeleton selamanya (bug ketahuan tes "kosong",
  /// 16 Nov 2026).
  Stream<DownloadsSnapshot> get stateStream => _stateController.stream;

  /// Snapshot terakhir yang dikirim (null sebelum emisi pertama).
  DownloadsSnapshot? _latestSnapshot;

  /// Snapshot terakhir yang dikirim, untuk `initialData` StreamBuilder.
  DownloadsSnapshot? get currentSnapshot => _latestSnapshot;

  final StreamController<String> _completedController =
      StreamController<String>.broadcast();

  /// videoId lagu yang baru selesai diunduh (untuk snackbar).
  Stream<String> get completedStream => _completedController.stream;

  final StreamController<String> _failedController =
      StreamController<String>.broadcast();

  /// videoId lagu yang unduhannya gagal total (untuk snackbar).
  Stream<String> get failedStream => _failedController.stream;

  /// Direktori unduhan (untuk membangun localPath Track).
  DownloadPaths get paths => _paths;

  /// Path direktori unduhan.
  String get downloadsDir => _paths.downloadsDir.path;

  /// Gerbang WiFi (P6, B8.4): bila saklar "Unduh saat WiFi saja" aktif,
  /// unduhan hanya berjalan saat tersambung WiFi. Dipasang lewat setter
  /// karena gerbang dibuat sesudah layanan di main().
  WifiGate? _wifiGate;
  StreamSubscription<bool>? _wifiSub;

  /// Gerbang WiFi (P6). Lihat [_wifiGate].
  set wifiGate(WifiGate? gate) {
    _wifiSub?.cancel();
    _wifiSub = null;
    _wifiGate = gate;
    if (gate == null) return;
    final WifiGate active = gate;
    final Stream<bool>? events = active.wifiChanged;
    if (events == null) return;
    _wifiSub = events.listen((bool isWifi) {
      if (_disposed) return;
      if (isWifi) {
        // WiFi kembali: lanjutkan antrean yang tertunda (B3.2: koneksi
        // kembali memulai job tertunda otomatis).
        start();
      } else if (active.wifiOnly && _activeSongId != null) {
        // WiFi hilang saat saklar aktif: jeda job aktif (`.part`
        // dipertahankan, dilanjutkan saat WiFi kembali).
        unawaited(pause(_activeSongId!));
      }
    });
  }

  /// Periksa ulang gerbang WiFi sekarang (dipanggil saat saklar WiFi
  /// saja diubah di Pengaturan): jeda job aktif bila tidak boleh jalan,
  /// atau mulai antrean bila boleh.
  Future<void> recheckWifiGate() async {
    final WifiGate? gate = _wifiGate;
    if (gate == null || _disposed) return;
    if (await gate.mayDownload) {
      start();
    } else if (_activeSongId != null) {
      await pause(_activeSongId!);
    }
  }

  /// Benar bila ada unduhan yang sedang berjalan.
  bool get hasActiveJob => _activeSongId != null;

  /// videoId unduhan yang sedang berjalan, atau null.
  String? get activeSongId => _activeSongId;

  String? _activeSongId;
  CancelToken? _activeCancelToken;

  /// Timer watchdog stall percobaan yang sedang berjalan (cermin dari
  /// variabel lokal di [_downloadAttempt]): dibatalkan eksplisit di
  /// [dispose] supaya tidak ada timer yang tertinggal pending sesudah
  /// layanan dibuang (tes widget gagal "Timer is still pending" bila
  /// timer ini tertinggal).
  Timer? _activeStallTimer;
  bool _pumping = false;
  bool _disposed = false;

  /// Progress live (byte) yang belum tentu tertulis ke database.
  final Map<String, int> _liveBytes = <String, int>{};
  DateTime _lastSnapshotEmit = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastProgressWrite = DateTime.fromMillisecondsSinceEpoch(0);

  /// Job yang diminta batal (dicek di titik-titik aman dalam loop).
  final Set<String> _cancelRequested = <String>{};

  /// Job yang diminta jeda (hanya job aktif).
  final Set<String> _pauseRequested = <String>{};

  // ------------------------------------------------------------------
  // Antrean
  // ------------------------------------------------------------------

  /// Mulai memproses antrean (dipanggil sekali sesudah rekonsiliasi
  /// di main). Aman dipanggil berulang (no-op bila sudah berjalan).
  void start() {
    if (_disposed) return;
    unawaited(_pump());
    unawaited(_emitSnapshot());
  }

  /// Tambahkan lagu ke antrean unduhan.
  ///
  /// Mengembalikan false bila lagu sudah terunduh atau sudah punya job
  /// aktif (dedup videoId). Job gagal yang di-enqueue ulang dilanjutkan
  /// (anggaran percobaan direset).
  Future<bool> enqueue(Track track, {DownloadQuality? quality}) async {
    final DownloadQuality chosen = quality ?? defaultQuality;
    final SongView? existing = await _library.songById(track.videoId);
    if (existing != null &&
        existing.song.downloadState == DownloadState.downloaded) {
      return false;
    }
    final DownloadJob? job = await _library.downloadJobBySongId(track.videoId);
    if (job != null) {
      switch (job.status) {
        case DownloadJobStatus.queued:
        case DownloadJobStatus.running:
        case DownloadJobStatus.paused:
          return false;
        case DownloadJobStatus.failed:
          await _library.updateDownloadJob(
            track.videoId,
            DownloadJobsCompanion(
              status: const Value<int>(DownloadJobStatus.queued),
              quality: Value<int?>(chosen.primaryItag),
              attempts: const Value<int>(0),
              errorMessage: const Value<String?>(null),
              updatedAt: Value<DateTime>(DateTime.now()),
            ),
          );
          unawaited(_pump());
          unawaited(_emitSnapshot());
          return true;
        case DownloadJobStatus.completed:
          return false;
      }
    }
    await _library.upsertSong(
      track.toSongsCompanion(),
      artistNames: track.artistNames,
      artistChannelIds: track.artistChannelIds,
      album: track.albumCompanion,
      addToLibrary: true,
    );
    await _library.setDownloadState(track.videoId, DownloadState.downloading);
    final DateTime now = DateTime.now();
    await _library.upsertDownloadJob(
      DownloadJobsCompanion.insert(
        songId: track.videoId,
        status: DownloadJobStatus.queued,
        quality: Value<int?>(chosen.primaryItag),
        // Total awal = perkiraan dari durasi: progress bar langsung
        // determinate (0%) begitu job dibuat, bukan spinner tak tentu
        // sampai resolve selesai. Angka pastinya ditulis _runJob
        // sesudah resolve (contentLength server). Durasi null berarti
        // total tidak diketahui (progress tak tentu sampai resolve).
        totalBytes: Value<int?>(
          track.duration == null
              ? null
              : chosen.estimateBytes(track.duration!),
        ),
        createdAt: Value<DateTime?>(now),
        updatedAt: now,
      ),
    );
    unawaited(_pump());
    unawaited(_emitSnapshot());
    return true;
  }

  /// Tambahkan beberapa lagu sekaligus (unduh album/playlist; UI-nya
  /// menyusul P6+). Mengembalikan jumlah yang benar-benar ditambahkan.
  Future<int> enqueueMany(
    List<Track> tracks, {
    DownloadQuality? quality,
  }) async {
    int added = 0;
    for (final Track track in tracks) {
      if (await enqueue(track, quality: quality)) added++;
    }
    return added;
  }

  /// Batalkan job: hapus job + file `.part`, kembalikan status lagu ke
  /// belum diunduh. Job aktif dibatalkan dulu (token cancel), lalu
  /// dibersihkan oleh loop unduhan.
  Future<void> cancel(String songId) async {
    if (_activeSongId == songId) {
      _cancelRequested.add(songId);
      _activeCancelToken?.cancel('dibatalkan pengguna');
      return;
    }
    await _deleteJobAndFiles(songId);
    unawaited(_emitSnapshot());
  }

  /// Jeda job aktif: unduhan berhenti, `.part` dipertahankan, job
  /// berstatus dijeda dan bisa dilanjutkan lewat [resumeJob].
  Future<void> pause(String songId) async {
    if (_activeSongId != songId) return;
    _pauseRequested.add(songId);
    _activeCancelToken?.cancel('dijeda pengguna');
  }

  /// Lanjutkan job yang dijeda atau gagal (anggaran percobaan direset).
  Future<void> resumeJob(String songId) async {
    final DownloadJob? job = await _library.downloadJobBySongId(songId);
    if (job == null) return;
    if (job.status != DownloadJobStatus.paused &&
        job.status != DownloadJobStatus.failed) {
      return;
    }
    await _library.updateDownloadJob(
      songId,
      DownloadJobsCompanion(
        status: const Value<int>(DownloadJobStatus.queued),
        attempts: const Value<int>(0),
        errorMessage: const Value<String?>(null),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
    unawaited(_pump());
    unawaited(_emitSnapshot());
  }

  /// Hapus unduhan yang sudah selesai: file dihapus, status lagu
  /// dikosongkan (lagu tetap di Library), job ikut dihapus.
  Future<void> deleteDownload(String songId) async {
    if (_activeSongId == songId) {
      await cancel(songId);
      return;
    }
    final SongView? song = await _library.songById(songId);
    final String? relative = song?.song.filePath;
    if (relative != null) {
      final File? file = _paths.downloadFileFromRelative(relative);
      if (file != null) {
        try {
          if (file.existsSync()) file.deleteSync();
        } on FileSystemException {
          // File tidak bisa dihapus: status tetap dibersihkan supaya
          // rekonsiliasi tidak menandainya hilang berulang-ulang.
        }
      }
    }
    await _deleteJobAndFiles(songId);
    unawaited(_emitSnapshot());
  }

  /// Hapus SEMUA unduhan (file + status). Lagu tetap di Library.
  Future<void> deleteAllDownloads() async {
    if (_activeSongId != null) {
      _cancelRequested.add(_activeSongId!);
      _activeCancelToken?.cancel('semua unduhan dihapus');
      // Tunggu loop unduhan selesai membersihkan job aktif (maks 5 dtk).
      for (int i = 0; i < 50 && _activeSongId != null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    final List<DownloadedFileInfo> files = await _library.downloadedFiles();
    for (final DownloadedFileInfo info in files) {
      final String? relative = info.filePath;
      if (relative != null) {
        final File? file = _paths.downloadFileFromRelative(relative);
        if (file != null) {
          try {
            if (file.existsSync()) file.deleteSync();
          } on FileSystemException {
            // Lanjut ke file berikutnya.
          }
        }
      }
      await _library.clearDownloadState(info.songId);
    }
    final List<DownloadJob> jobs = await _library.downloadJobs();
    for (final DownloadJob job in jobs) {
      await _deleteJobAndFiles(job.songId);
    }
    unawaited(_emitSnapshot());
  }

  /// Bangun [Track] dari lagu database: lagu terunduh membawa
  /// `localPath` supaya pemutar memutar file lokal tanpa jaringan
  /// (pagar P0: track lokal tidak pernah memanggil resolver).
  Track trackFor(SongView view) {
    return view.toTrack(downloadsDir: _paths.downloadsDir.path);
  }

  /// Hitungan penyimpanan (unduhan + cache) dari database.
  Future<StorageStats> storageStats() => _library.storageStats();

  /// Sisa ruang HP (byte), atau null bila tidak bisa dibaca.
  Future<int?> freeSpaceBytes() =>
      _freeSpace.freeBytes(_paths.downloadsDir.path);

  // ------------------------------------------------------------------
  // Pompa serial
  // ------------------------------------------------------------------

  Future<void> _pump() async {
    if (_pumping || _disposed) return;
    _pumping = true;
    try {
      while (!_disposed) {
        final DownloadJob? next = await _nextQueuedJob();
        if (next == null) {
          onQueueIdle?.call();
          return;
        }
        // P6 (B8.4): saklar WiFi saja aktif dan HP tidak di WiFi — job
        // dibiarkan mengantre, pompa berhenti TANPA memanggil
        // onQueueIdle (supaya cache juga tidak jalan di data seluler).
        // WiFi kembali memicu start() lewat langganan wifiChanged.
        final WifiGate? gate = _wifiGate;
        if (gate != null && !await gate.mayDownload) return;
        try {
          await _runJob(next);
        } on Object catch (_) {
          // Satu job yang meledak tidak boleh mematikan pompa serial:
          // gagalkan job itu dan lanjut ke antrean berikutnya.
          await _failJob(next.songId, DownloadFailure.network);
        }
      }
    } finally {
      _pumping = false;
    }
  }

  Future<DownloadJob?> _nextQueuedJob() async {
    final List<DownloadJob> jobs = await _library.downloadJobs();
    for (final DownloadJob job in jobs) {
      if (job.status == DownloadJobStatus.queued) return job;
    }
    return null;
  }

  Future<void> _runJob(DownloadJob job) async {
    final String songId = job.songId;
    final SongView? song = await _library.songById(songId);
    if (song == null) {
      // Lagu terhapus dari database: job yatim, hapus saja.
      await _library.deleteDownloadJob(songId);
      return;
    }
    final DownloadQuality quality =
        DownloadQuality.fromPrimaryItag(job.quality ?? -1) ?? defaultQuality;
    _activeSongId = songId;
    _activeCancelToken = CancelToken();
    await _library.updateDownloadJob(
      songId,
      DownloadJobsCompanion(
        status: const Value<int>(DownloadJobStatus.running),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
    unawaited(_emitSnapshot());
    try {
      int attempts = job.attempts;
      while (attempts < kMaxDownloadAttempts) {
        attempts++;
        await _library.updateDownloadJob(
          songId,
          DownloadJobsCompanion(
            attempts: Value<int>(attempts),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
        if (_cancelRequested.contains(songId)) {
          await _deleteJobAndFiles(songId);
          return;
        }
        // Resolve URL segar di tiap percobaan (URL kedaluwarsa).
        final DownloadUrl resolved;
        try {
          resolved = await _urlSource.resolve(songId, quality);
        } on ExtractorException catch (e) {
          if (_cancelRequested.contains(songId)) {
            await _deleteJobAndFiles(songId);
            return;
          }
          if (e.isNetworkError && attempts < kMaxDownloadAttempts) {
            await Future<void>.delayed(_backoffFor(attempts));
            continue;
          }
          await _failJob(
            songId,
            e.isNetworkError
                ? DownloadFailure.network
                : DownloadFailure.unplayable,
          );
          return;
        }
        if (_cancelRequested.contains(songId)) {
          await _deleteJobAndFiles(songId);
          return;
        }
        // Total pasti dari server menggantikan perkiraan enqueue
        // (progress bar memakai angka nyata mulai percobaan ini).
        final int? contentLength = resolved.contentLength;
        if (contentLength != null && contentLength > 0) {
          await _library.updateDownloadJob(
            songId,
            DownloadJobsCompanion(
              totalBytes: Value<int?>(contentLength),
              updatedAt: Value<DateTime>(DateTime.now()),
            ),
          );
        }
        // Pra-periksa ruang (hanya percobaan pertama; ruang tidak
        // berubah antar percobaan dalam hitungan detik).
        if (attempts == 1) {
          final bool ok = await _checkFreeSpace(song, quality, resolved);
          if (!ok) {
            await _failJob(songId, DownloadFailure.storageFull);
            return;
          }
        }
        final _AttemptOutcome outcome;
        try {
          outcome = await _downloadAttempt(song, resolved);
        } on Object catch (_) {
          // Error tak terduga di tengah percobaan (mis. stream rusak):
          // perlakukan sebagai gagal sementara, bukan gagal permanen.
          if (attempts < kMaxDownloadAttempts) {
            await Future<void>.delayed(_backoffFor(attempts));
            continue;
          }
          await _failJob(songId, DownloadFailure.network);
          return;
        }
        switch (outcome) {
          case _AttemptOutcome.done:
            await _finishJob(song, resolved);
            return;
          case _AttemptOutcome.cancelled:
            await _deleteJobAndFiles(songId);
            return;
          case _AttemptOutcome.paused:
            await _library.updateDownloadJob(
              songId,
              DownloadJobsCompanion(
                status: const Value<int>(DownloadJobStatus.paused),
                updatedAt: Value<DateTime>(DateTime.now()),
              ),
            );
            unawaited(_emitSnapshot());
            return;
          case _AttemptOutcome.storageFull:
            await _failJob(songId, DownloadFailure.storageFull);
            return;
          case _AttemptOutcome.retryable:
            if (attempts < kMaxDownloadAttempts) {
              await Future<void>.delayed(_backoffFor(attempts));
              continue;
            }
            await _failJob(songId, DownloadFailure.network);
            return;
          case _AttemptOutcome.unplayable:
            await _failJob(songId, DownloadFailure.unplayable);
            return;
        }
      }
    } finally {
      _liveBytes.remove(songId);
      _activeSongId = null;
      _activeCancelToken = null;
      _cancelRequested.remove(songId);
      _pauseRequested.remove(songId);
    }
  }

  /// Pra-periksa ruang: perkiraan ukuran + buffer 100 MB harus muat.
  /// Perkiraan memakai contentLength server bila ada, kalau tidak
  /// memakai rumus bitrate x durasi. Bila ruang tidak bisa dibaca,
  /// anggap cukup (perlindungan terakhir adalah ENOSPC).
  Future<bool> _checkFreeSpace(
    SongView song,
    DownloadQuality quality,
    DownloadUrl resolved,
  ) async {
    final int? free = await _freeSpace.freeBytes(_paths.downloadsDir.path);
    if (free == null) return true;
    final int estimate =
        resolved.contentLength ??
        (song.song.durationSeconds == null
            ? 0
            : quality.estimateBytes(
                Duration(seconds: song.song.durationSeconds!),
              ));
    return free >= estimate + kFreeSpaceBufferBytes;
  }

  /// Satu percobaan unduh file (resolve sudah dilakukan pemanggil).
  Future<_AttemptOutcome> _downloadAttempt(
    SongView song,
    DownloadUrl resolved,
  ) async {
    final String songId = song.id;
    final String extension = extensionForMimeType(resolved.mimeType);
    final File partFile = _paths.downloadPartFile(songId, extension);
    int downloaded = 0;
    try {
      if (await partFile.exists()) downloaded = await partFile.length();
    } on FileSystemException {
      downloaded = 0;
    }
    // Total dari database (percobaan sebelumnya) atau server.
    final DownloadJob? job = await _library.downloadJobBySongId(songId);
    int? total = job?.totalBytes ?? resolved.contentLength;
    if (total != null && downloaded >= total && total > 0) {
      // .part sudah lengkap (app mati tepat sebelum rename): verifikasi
      // lalu selesaikan tanpa jaringan.
      return _AttemptOutcome.done;
    }
    final CancelToken token = _activeCancelToken ?? CancelToken();
    Timer? stallTimer;
    DateTime lastChunkAt = DateTime.now();
    try {
      // Timeout 30 detik untuk header respons: tanpa ini, server yang
      // menerima koneksi tapi tidak pernah membalas menggantung pompa
      // selamanya (receiveTimeout sengaja tidak dipakai untuk stream
      // karena unduhan besar di koneksi lambat butuh waktu lama;
      // stall sesudah header ditangani watchdog di bawah).
      final Response<ResponseBody> response = await _dio
          .get<ResponseBody>(
            resolved.url,
            options: Options(
              responseType: ResponseType.stream,
              headers: downloaded > 0
                  ? <String, String>{'Range': 'bytes=$downloaded-'}
                  : null,
              sendTimeout: const Duration(seconds: 30),
              // 416 diterima sebagai respons (bukan exception): artinya
              // file sudah lengkap di sisi server.
              validateStatus: (int? s) => s == 200 || s == 206 || s == 416,
            ),
            cancelToken: token,
          )
          .timeout(const Duration(seconds: 30));
      final int? status = response.statusCode;
      if (status == 416) {
        // Server bilang range di luar jangkauan: .part sudah lengkap.
        return _AttemptOutcome.done;
      }
      final bool resumed = status == 206;
      if (!resumed) {
        // Server mengabaikan Range (200): mulai dari awal.
        downloaded = 0;
      }
      total = _totalFromResponse(response, resumed, downloaded) ?? total;
      await _library.updateDownloadJob(
        songId,
        DownloadJobsCompanion(
          totalBytes: Value<int?>(total),
          bytesDownloaded: Value<int>(downloaded),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
      // Pengawas stall: tidak ada chunk selama 60 detik berarti koneksi
      // menggantung (bukan gagal) — batalkan supaya retry bisa jalan.
      // Tanpa ini, satu unduhan yang stall menggantung antrean selamanya.
      stallTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (DateTime.now().difference(lastChunkAt) >
            const Duration(seconds: 60)) {
          token.cancel('stall 60 detik tanpa data');
        }
      });
      _activeStallTimer = stallTimer;
      final IOSink sink = partFile.openWrite(
        mode: resumed ? FileMode.append : FileMode.write,
      );
      int received = downloaded;
      try {
        await for (final List<int> chunk in response.data!.stream) {
          lastChunkAt = DateTime.now();
          sink.add(chunk);
          // Flush per chunk: IOSink menahan data di buffer memori dan
          // ukuran .part di disk tetap 0 sampai flush/close — tanpa ini,
          // app yang mati di tengah unduhan kehilangan SEMUA progress
          // (resume tidak punya apa-apa untuk dilanjutkan) dan tes
          // batal/jeda tidak pernah melihat .part berisi (terbukti
          // 16 Nov 2026: len=0 selama 5 dtk unduhan). Flush hanya
          // mendorong ke OS (bukan fsync), murah untuk file audio.
          await sink.flush();
          received += chunk.length;
          _onProgress(songId, received, total);
        }
        await sink.close();
      } on Object catch (_) {
        try {
          await sink.close();
        } on Object catch (_) {}
        rethrow;
      }
      if (total != null && received != total) {
        return _AttemptOutcome.retryable;
      }
      // Pindahkan .part ke final di sini? Tidak: rename dilakukan
      // _finishJob supaya satu tempat yang menulis status lagu.
      return _AttemptOutcome.done;
    } on DioException catch (e) {
      if (_cancelRequested.contains(songId)) {
        return _AttemptOutcome.cancelled;
      }
      if (_pauseRequested.contains(songId)) {
        return _AttemptOutcome.paused;
      }
      if (CancelToken.isCancel(e)) {
        // Cancel tanpa permintaan pengguna = stall watchdog.
        return _AttemptOutcome.retryable;
      }
      return _AttemptOutcome.retryable;
    } on TimeoutException {
      // Header tidak kunjung tiba: coba lagi (resolve ulang URL segar).
      return _AttemptOutcome.retryable;
    } on FileSystemException catch (e) {
      // errno 28 = ENOSPC (ruang habis) di Linux/Android.
      if (e.osError?.errorCode == 28) return _AttemptOutcome.storageFull;
      return _AttemptOutcome.retryable;
    } finally {
      stallTimer?.cancel();
      if (_activeStallTimer == stallTimer) _activeStallTimer = null;
    }
  }

  int? _totalFromResponse(
    Response<ResponseBody> response,
    bool resumed,
    int downloaded,
  ) {
    if (resumed) {
      final String? range = response.headers.value('content-range');
      if (range != null) {
        final List<String> parts = range.split('/');
        if (parts.length == 2) return int.tryParse(parts[1]);
      }
      final String? length = response.headers.value(
        HttpHeaders.contentLengthHeader,
      );
      final int? remaining = length == null ? null : int.tryParse(length);
      return remaining == null ? null : remaining + downloaded;
    }
    final String? length = response.headers.value(
      HttpHeaders.contentLengthHeader,
    );
    return length == null ? null : int.tryParse(length);
  }

  /// Selesaikan job: rename `.part` -> final, catat format, tandai lagu
  /// terunduh, hapus entri cache lagu itu (unduhan menggantikan cache).
  Future<void> _finishJob(SongView song, DownloadUrl resolved) async {
    final String songId = song.id;
    final String extension = extensionForMimeType(resolved.mimeType);
    final File partFile = _paths.downloadPartFile(songId, extension);
    final File finalFile = _paths.downloadFile(songId, extension);
    final bool partExists = await partFile.exists();
    if (!partExists) {
      // Tidak ada .part (mis. 416 dengan .part yang sudah di-rename
      // percobaan sebelumnya?): cek file final.
      if (!await finalFile.exists()) {
        await _failJob(songId, DownloadFailure.unplayable);
        return;
      }
    } else {
      await partFile.rename(finalFile.path);
    }
    final int size = await finalFile.length();
    final DownloadJob? job = await _library.downloadJobBySongId(songId);
    if (job?.totalBytes != null && size != job!.totalBytes) {
      // Ukuran tidak cocok: file rusak, hapus dan gagalkan.
      try {
        finalFile.deleteSync();
      } on FileSystemException {
        // Rekonsiliasi membersihkan sisanya.
      }
      await _failJob(songId, DownloadFailure.unplayable);
      return;
    }
    final String formatId = '${songId}_${resolved.itag}';
    await _library.upsertFormat(
      FormatsCompanion.insert(
        id: formatId,
        songId: songId,
        itag: resolved.itag,
        mimeType: resolved.mimeType,
        bitrate: Value<int?>(resolved.bitrate),
        contentLength: Value<int?>(resolved.contentLength ?? size),
        lastModified: DateTime.now(),
      ),
    );
    await _library.markDownloaded(
      songId: songId,
      filePath: _paths.downloadFileName(songId, extension),
      fileSizeBytes: size,
      formatId: formatId,
    );
    await _library.updateDownloadJob(
      songId,
      DownloadJobsCompanion(
        status: const Value<int>(DownloadJobStatus.completed),
        bytesDownloaded: Value<int>(size),
        totalBytes: Value<int?>(size),
        errorMessage: const Value<String?>(null),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
    // Unduhan menggantikan cache: entri cache lagu ini tidak lagi
    // dibutuhkan (pemutar memakai file unduhan dulu).
    await _streamCache?.invalidate(songId);
    if (!_disposed) _completedController.add(songId);
    unawaited(_emitSnapshot());
  }

  Future<void> _failJob(String songId, String reason) async {
    await _library.updateDownloadJob(
      songId,
      DownloadJobsCompanion(
        status: const Value<int>(DownloadJobStatus.failed),
        errorMessage: Value<String?>(reason),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
    // Status lagu kembali ke belum diunduh: tombol unduh menampilkan
    // ikon unduh lagi dan ketukan berikutnya mencoba lagi (resume dari
    // `.part` yang dipertahankan). Job gagalnya sendiri tetap tampil
    // di kelompok Gagal tab Unduhan.
    await _library.setDownloadState(songId, DownloadState.notDownloaded);
    if (!_disposed) _failedController.add(songId);
    unawaited(_emitSnapshot());
  }

  /// Hapus job + file `.part` + kembalikan status lagu. Dipakai batal
  /// dan pembersihan job yatim. File final TIDAK disentuh di sini
  /// (hanya [deleteDownload]/[deleteAllDownloads] yang menghapusnya).
  Future<void> _deleteJobAndFiles(String songId) async {
    await _library.deleteDownloadJob(songId);
    // Status unduhan SELALU dibersihkan (bukan hanya saat "mengunduh"):
    // deleteDownload memanggil ini untuk lagu yang sudah terunduh, dan
    // versi lama yang hanya mereset status "mengunduh" membiarkan lagu
    // tetap bertanda terunduh walau file + job-nya sudah hilang (bug
    // ketahuan tes deleteDownload, 16 Nov 2026). clearDownloadState juga
    // menolkan filePath/ukuran supaya tidak ada metadata menggantung.
    await _library.clearDownloadState(songId);
    // Hapus semua .part lagu ini (ekstensi apa pun).
    try {
      final List<FileSystemEntity> listed = _paths.downloadsDir.listSync();
      for (final FileSystemEntity entity in listed) {
        if (entity is! File) continue;
        final String name = entity.path.split('/').last;
        if (name.startsWith('$songId.') && name.endsWith('.part')) {
          try {
            entity.deleteSync();
          } on FileSystemException {
            // Rekonsiliasi membersihkan sisanya.
          }
        }
      }
    } on FileSystemException {
      // Direktori tidak bisa dibaca: rekonsiliasi mencoba lagi.
    }
  }

  /// Progress satu chunk: update memori + snapshot (throttle 250 ms)
  /// + tulis database (throttle 1 dtk, supaya UI tidak membanjiri disk).
  void _onProgress(String songId, int received, int? total) {
    _liveBytes[songId] = received;
    final DateTime now = DateTime.now();
    if (now.difference(_lastSnapshotEmit) >=
        const Duration(milliseconds: 250)) {
      _lastSnapshotEmit = now;
      unawaited(_emitSnapshot());
    }
    if (now.difference(_lastProgressWrite) >= const Duration(seconds: 1)) {
      _lastProgressWrite = now;
      unawaited(
        _library.updateDownloadJob(
          songId,
          DownloadJobsCompanion(
            bytesDownloaded: Value<int>(received),
            totalBytes: Value<int?>(total),
            updatedAt: Value<DateTime>(now),
          ),
        ),
      );
    }
  }

  Future<void> _emitSnapshot() async {
    if (_disposed) return;
    final List<DownloadJob> jobs = await _library.downloadJobs();
    final List<DownloadJobView> views = <DownloadJobView>[];
    for (final DownloadJob job in jobs) {
      final SongView? song = await _library.songById(job.songId);
      if (song == null) continue;
      final int? live = _liveBytes[job.songId];
      final DownloadJob effective = live == null
          ? job
          : job.copyWith(bytesDownloaded: live);
      views.add(DownloadJobView(job: effective, song: song));
    }
    final List<SongView> downloaded = await _library.downloadedSongs(
      limit: 200,
    );
    final StorageStats stats = await _library.storageStats();
    if (_disposed) return;
    _latestSnapshot = DownloadsSnapshot(
      jobs: views,
      downloaded: downloaded,
      stats: stats,
    );
    _stateController.add(_latestSnapshot!);
  }

  /// Buang layanan (tutup stream + Dio). Panggil HANYA dari luar zona
  /// FakeAsync tes widget (mis. tearDown): tunggu pompa memakai
  /// `Future.delayed` nyata yang tidak pernah jalan di FakeAsync.
  Future<void> dispose() async {
    _disposed = true;
    await _wifiSub?.cancel();
    _wifiSub = null;
    _activeStallTimer?.cancel();
    _activeStallTimer = null;
    _activeCancelToken?.cancel('service dibuang');
    // Tunggu pompa serial selesai mengurai pekerjaan yang sedang
    // berjalan (maks 2 dtk): tanpa ini, timer watchdog / timeout
    // header yang masih pending membuat tes widget gagal ("Timer is
    // still pending") dan pumpAndSettle tidak pernah settle. Batas
    // waktu supaya resolve yang menggantung selamanya (bukan timer)
    // tidak menahan dispose; pekerjaan yang tertinggal tidak lagi
    // menyentuh stream yang sudah ditutup (dijaga cek _disposed).
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
    while (_pumping && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    await _stateController.close();
    await _completedController.close();
    await _failedController.close();
    _dio.close(force: true);
  }
}

/// Hasil satu percobaan unduh file.
enum _AttemptOutcome {
  /// File lengkap di `.part`, siap di-rename.
  done,

  /// Dibatalkan pengguna.
  cancelled,

  /// Dijeda pengguna (`.part` dipertahankan).
  paused,

  /// Ruang habis (ENOSPC).
  storageFull,

  /// Gagal sementara (jaringan/timeout/stall/ukuran tidak cocok):
  /// boleh coba lagi.
  retryable,

  /// Gagal permanen (lagu tidak tersedia).
  unplayable,
}
