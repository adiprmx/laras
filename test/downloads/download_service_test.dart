import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/player/track.dart';

import '../data/test_database.dart';

/// Sumber URL palsu: mengarah ke server lokal, contentLength tetap.
class _FakeUrlSource implements DownloadUrlSource {
  _FakeUrlSource({
    required this.baseUrl,
    this.contentLength,
    this.failResolveTimes = 0,
    this.resolveError,
  });

  final String baseUrl;
  final int? contentLength;
  final int failResolveTimes;
  final ExtractorException? resolveError;
  int resolveCalls = 0;

  @override
  Future<DownloadUrl> resolve(String videoId, DownloadQuality quality) async {
    resolveCalls++;
    if (resolveCalls <= failResolveTimes && resolveError != null) {
      throw resolveError!;
    }
    return DownloadUrl(
      url: '$baseUrl/audio',
      itag: quality.primaryItag,
      mimeType: 'audio/webm; codecs="opus"',
      bitrate: 160000,
      clientName: 'test',
      contentLength: contentLength,
    );
  }
}

/// Sisa ruang palsu.
class _FakeFreeSpace implements FreeSpaceProvider {
  _FakeFreeSpace(this.free);

  int? free;

  @override
  Future<int?> freeBytes(String path) async => free;
}

/// Server HTTP lokal: dukungan Range, gagal N request pertama (500),
/// jeda antar chunk (unduhan lambat), pelacakan konkurensi.
class _TestServer {
  _TestServer({
    required this.bytes,
    this.failFirst = 0,
    this.chunkDelay,
    this.responseDelay,
  });

  final List<int> bytes;
  final int failFirst;
  final Duration? chunkDelay;
  final Duration? responseDelay;

  int requests = 0;
  int rangeRequests = 0;
  int active = 0;
  int maxActive = 0;
  HttpServer? _server;

  Future<Uri> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
    return Uri.parse('http://127.0.0.1:${_server!.port}');
  }

  Future<void> _handle(HttpRequest request) async {
    requests++;
    active++;
    if (active > maxActive) maxActive = active;
    try {
      if (responseDelay != null) {
        await Future<void>.delayed(responseDelay!);
      }
      if (requests <= failFirst) {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..close();
        return;
      }
      final String? range = request.headers.value(HttpHeaders.rangeHeader);
      List<int> body = bytes;
      int status = HttpStatus.ok;
      String? contentRange;
      if (range != null && range.startsWith('bytes=')) {
        rangeRequests++;
        final int start = int.parse(range.substring(6).split('-').first);
        if (start >= bytes.length) {
          request.response
            ..statusCode = HttpStatus.requestedRangeNotSatisfiable
            ..headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes */${bytes.length}',
            )
            ..close();
          return;
        }
        body = bytes.sublist(start);
        status = HttpStatus.partialContent;
        contentRange = 'bytes $start-${bytes.length - 1}/${bytes.length}';
      }
      // WAJIB bufferOutput=false: tanpa itu, HttpResponse menahan body di
      // buffer sampai close() — klien menerima semua byte sekaligus di
      // akhir, seolah unduhan instan (terbukti probe 16 Nov 2026:
      // 1000 B tiba sekaligus di 5,1 dtk; dengan flag ini tiap chunk
      // 100 B tiba tiap ~500 ms). Tes batal/jeda butuh chunk mengalir.
      final HttpResponse response = request.response
        ..statusCode = status
        ..headers.set(HttpHeaders.contentLengthHeader, body.length)
        ..bufferOutput = false;
      if (contentRange != null) {
        response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
      }
      if (chunkDelay == null) {
        response.add(body);
      } else {
        const int chunks = 10;
        final int size = (body.length / chunks).ceil();
        for (int i = 0; i < body.length; i += size) {
          final int end = (i + size).clamp(0, body.length);
          response.add(body.sublist(i, end));
          await response.flush();
          await Future<void>.delayed(chunkDelay!);
        }
      }
      await response.close();
    } on Object catch (_) {
      // Klien membatalkan di tengah stream (pause/cancel): abaikan.
      try {
        await request.response.close();
      } on Object catch (_) {}
    } finally {
      active--;
    }
  }

  Future<void> stop() async => _server?.close(force: true);
}

/// Server yang mengalirkan byte TANPA Content-Length (chunked): total
/// tidak diketahui klien dari header — satu-satunya rem adalah cap
/// byte R2-M2 (total dari resolver + margin, atau batas absolut).
class _ChunkedServer {
  _ChunkedServer({required this.totalBytes});

  final int totalBytes;
  int requests = 0;
  HttpServer? _server;

  Future<Uri> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((HttpRequest request) async {
      requests++;
      final HttpResponse response = request.response
        ..statusCode = HttpStatus.ok
        ..bufferOutput = false;
      try {
        int sent = 0;
        while (sent < totalBytes) {
          final int size = (totalBytes - sent).clamp(0, 1024);
          response.add(List<int>.filled(size, 9));
          await response.flush();
          sent += size;
        }
        await response.close();
      } on Object catch (_) {
        // Klien membatalkan di tengah stream (cap tercapai): abaikan.
        try {
          await request.response.close();
        } on Object catch (_) {}
      }
    });
    return Uri.parse('http://127.0.0.1:${_server!.port}');
  }

  Future<void> stop() async => _server?.close(force: true);
}

Future<DownloadJob?> _waitForJob(
  LibraryService library,
  String songId,
  bool Function(DownloadJob?) done, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final DownloadJob? job = await library.downloadJobBySongId(songId);
    if (done(job)) return job;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('job $songId tidak mencapai kondisi dalam $timeout');
}

Track _track(String videoId, {String title = 'Lagu Uji'}) {
  return Track(
    videoId: videoId,
    title: title,
    duration: const Duration(seconds: 180),
  );
}

void main() {
  late Directory temp;
  late DownloadPaths paths;
  late LarasDatabase db;
  late LibraryService library;
  late _FakeFreeSpace freeSpace;
  DownloadService? service;

  Future<DownloadService> buildService({
    required _FakeUrlSource urlSource,
    int? maxDownloadBytes,
    bool allowLocalServer = true,
  }) async {
    final DownloadService created = DownloadService(
      library: library,
      paths: paths,
      urlSource: urlSource,
      freeSpace: freeSpace,
      backoffFor: (_) => Duration.zero,
      // Server tes adalah HTTP lokal (127.0.0.1): validator allowlist
      // produksi (R2-M1) dilonggarkan di sini, kecuali tes sabuk R2-M1
      // yang sengaja memakai validator bawaan (allowLocalServer false).
      urlValidator: allowLocalServer ? (_) => true : null,
      maxDownloadBytes: maxDownloadBytes ?? kMaxDownloadBytes,
    );
    service = created;
    created.start();
    return created;
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('laras_dl_test');
    final Directory downloads = Directory('${temp.path}/downloads')
      ..createSync();
    final Directory cacheDir = Directory('${temp.path}/cache')..createSync();
    paths = DownloadPaths(downloadsDir: downloads, cacheDir: cacheDir);
    (db, library) = createTestLibrary();
    // 10 GB bebas: pra-periksa ruang lolos untuk semua tes kecuali
    // tes penolakan ruang.
    freeSpace = _FakeFreeSpace(10 * 1024 * 1024 * 1024);
  });

  tearDown(() async {
    await service?.dispose();
    service = null;
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('unduhan penuh: file benar, lagu ditandai terunduh, job selesai', () async {
    final List<int> bytes = List<int>.generate(1000, (int i) => i % 256);
    final _TestServer server = _TestServer(bytes: bytes);
    final Uri base = await server.start();
    try {
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(baseUrl: base.toString(), contentLength: 1000),
      );
      final List<String> completed = <String>[];
      final StreamSubscription<String> sub =
          downloads.completedStream.listen(completed.add);

      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      final DownloadJob? job = await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.completed,
      );

      expect(job!.attempts, 1);
      expect(job.bytesDownloaded, 1000);
      expect(job.totalBytes, 1000);
      final File file = paths.downloadFile('aaa11111111', 'opus');
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), bytes);
      expect(await paths.downloadPartFile('aaa11111111', 'opus').exists(), isFalse);
      final SongView? view = await library.songById('aaa11111111');
      expect(view?.song.downloadState, DownloadState.downloaded);
      expect(view?.song.filePath, 'aaa11111111.opus');
      expect(view?.song.fileSizeBytes, 1000);
      // trackFor membawa localPath ke file itu.
      final Track track = downloads.trackFor(view!);
      expect(track.localPath, file.path);
      expect(track.isLocal, isTrue);
      // Stream selesai + hitungan ruang.
      expect(completed, <String>['aaa11111111']);
      final StorageStats stats = await downloads.storageStats();
      expect(stats.downloadCount, 1);
      expect(stats.downloadBytes, 1000);
      await sub.cancel();
    } finally {
      await server.stop();
    }
  });

  test('resume: melanjutkan dari .part yang tertinggal via Range', () async {
    final List<int> bytes = List<int>.generate(1000, (int i) => i % 251);
    final _TestServer server = _TestServer(bytes: bytes);
    final Uri base = await server.start();
    try {
      // 400 byte pertama sudah ada sebagai .part.
      final File part = paths.downloadPartFile('aaa11111111', 'opus');
      await part.writeAsBytes(bytes.sublist(0, 400));
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(baseUrl: base.toString(), contentLength: 1000),
      );
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.completed,
      );
      expect(server.rangeRequests, 1);
      final File file = paths.downloadFile('aaa11111111', 'opus');
      expect(await file.readAsBytes(), bytes);
    } finally {
      await server.stop();
    }
  });

  test('retry: gagal 2x lalu berhasil, percobaan dihitung 3', () async {
    final List<int> bytes = List<int>.generate(500, (int i) => i % 256);
    final _TestServer server = _TestServer(bytes: bytes, failFirst: 2);
    final Uri base = await server.start();
    try {
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(baseUrl: base.toString(), contentLength: 500),
      );
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      final DownloadJob? job = await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.completed,
      );
      expect(job!.attempts, 3);
      expect(server.requests, 3);
      final File file = paths.downloadFile('aaa11111111', 'opus');
      expect(await file.readAsBytes(), bytes);
    } finally {
      await server.stop();
    }
  });

  test('gagal total sesudah 3 percobaan: job failed, status lagu direset', () async {
    final List<int> bytes = List<int>.generate(500, (int i) => i % 256);
    final _TestServer server = _TestServer(bytes: bytes, failFirst: 100);
    final Uri base = await server.start();
    try {
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(baseUrl: base.toString(), contentLength: 500),
      );
      final List<String> failed = <String>[];
      final StreamSubscription<String> sub =
          downloads.failedStream.listen(failed.add);
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      final DownloadJob? job = await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.failed,
      );
      expect(job!.attempts, 3);
      expect(job.errorMessage, DownloadFailure.network);
      expect(server.requests, 3);
      // Status lagu kembali ke belum diunduh (tombol unduh muncul lagi).
      final SongView? view = await library.songById('aaa11111111');
      expect(view?.song.downloadState, DownloadState.notDownloaded);
      expect(failed, <String>['aaa11111111']);
      await sub.cancel();
    } finally {
      await server.stop();
    }
  });

  test('serial: hanya 1 unduhan aktif dalam satu waktu, urutan antrean dijaga', () async {
    final List<int> bytes = List<int>.generate(200, (int i) => i % 256);
    final _TestServer server = _TestServer(
      bytes: bytes,
      responseDelay: const Duration(milliseconds: 300),
    );
    final Uri base = await server.start();
    try {
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(baseUrl: base.toString(), contentLength: 200),
      );
      final List<String> completed = <String>[];
      final StreamSubscription<String> sub =
          downloads.completedStream.listen(completed.add);
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      expect(await downloads.enqueue(_track('bbb22222222')), isTrue);
      await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.completed,
      );
      await _waitForJob(
        library,
        'bbb22222222',
        (DownloadJob? j) => j?.status == DownloadJobStatus.completed,
      );
      expect(server.maxActive, 1);
      expect(completed, <String>['aaa11111111', 'bbb22222222']);
      await sub.cancel();
    } finally {
      await server.stop();
    }
  });

  test('batal job antrean: job + status dibersihkan, job aktif tetap jalan', () async {
    final List<int> bytes = List<int>.generate(200, (int i) => i % 256);
    final _TestServer server = _TestServer(
      bytes: bytes,
      responseDelay: const Duration(milliseconds: 500),
    );
    final Uri base = await server.start();
    try {
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(baseUrl: base.toString(), contentLength: 200),
      );
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      expect(await downloads.enqueue(_track('bbb22222222')), isTrue);
      await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.running,
      );
      await downloads.cancel('bbb22222222');
      expect(await library.downloadJobBySongId('bbb22222222'), isNull);
      final SongView? viewB = await library.songById('bbb22222222');
      expect(viewB?.song.downloadState, DownloadState.notDownloaded);
      // Job pertama tetap selesai.
      await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.completed,
      );
    } finally {
      await server.stop();
    }
  });

  test('batal job aktif: job + .part dihapus, status lagu direset', () async {
    final List<int> bytes = List<int>.generate(1000, (int i) => i % 256);
    // Jendela unduhan ~5 dtk (10 chunk x 500 ms): dengan 100 ms/chunk,
    // unduhan selesai sebelum tes sempat membatalkan saat mesin sibuk
    // (paralel suite penuh) dan tes menggantung di _waitForJob.
    final _TestServer server = _TestServer(
      bytes: bytes,
      chunkDelay: const Duration(milliseconds: 500),
    );
    final Uri base = await server.start();
    try {
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(baseUrl: base.toString(), contentLength: 1000),
      );
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      // Tunggu unduhan berjalan (ada .part berisi sebagian + job masih
      // running). Bila unduhan keburu selesai, gagalkan cepat dengan
      // pesan jelas, bukan menggantung 15 dtk di _waitForJob.
      final File part = paths.downloadPartFile('aaa11111111', 'opus');
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 8));
      while (DateTime.now().isBefore(deadline)) {
        final DownloadJob? current =
            await library.downloadJobBySongId('aaa11111111');
        if (current?.status == DownloadJobStatus.completed) {
          fail('unduhan selesai sebelum tes sempat membatalkan');
        }
        if (await part.exists() && await part.length() > 0) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(await part.exists(), isTrue);
      expect(await part.length(), greaterThan(0));

      await downloads.cancel('aaa11111111');
      await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j == null,
      );
      expect(await part.exists(), isFalse);
      expect(await paths.downloadFile('aaa11111111', 'opus').exists(), isFalse);
      final SongView? view = await library.songById('aaa11111111');
      expect(view?.song.downloadState, DownloadState.notDownloaded);
    } finally {
      await server.stop();
    }
  });

  test('jeda lalu lanjut: .part dipertahankan, resume menyelesaikan file', () async {
    final List<int> bytes = List<int>.generate(1000, (int i) => i % 251);
    // Jendela unduhan ~5 dtk (alasan sama dengan tes batal: 100 ms/chunk
    // membuat unduhan selesai sebelum tes sempat menjeda saat mesin sibuk,
    // lalu part.length() melempar PathNotFoundException karena .part sudah
    // di-rename menjadi file final).
    final _TestServer server = _TestServer(
      bytes: bytes,
      chunkDelay: const Duration(milliseconds: 500),
    );
    final Uri base = await server.start();
    try {
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(baseUrl: base.toString(), contentLength: 1000),
      );
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      final File part = paths.downloadPartFile('aaa11111111', 'opus');
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 8));
      while (DateTime.now().isBefore(deadline)) {
        final DownloadJob? current =
            await library.downloadJobBySongId('aaa11111111');
        if (current?.status == DownloadJobStatus.completed) {
          fail('unduhan selesai sebelum tes sempat menjeda');
        }
        if (await part.exists() && await part.length() > 0) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final int partial = await part.length();
      expect(partial, greaterThan(0));
      expect(partial, lessThan(1000));

      await downloads.pause('aaa11111111');
      final DownloadJob? paused = await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.paused,
      );
      expect(paused, isNotNull);
      // .part dipertahankan untuk resume (boleh sedikit lebih besar dari
      // yang terukur sebelum jeda: satu chunk bisa mendarat di antara
      // pengukuran dan pembatalan token).
      expect(await part.exists(), isTrue);
      final int pausedLength = await part.length();
      expect(pausedLength, greaterThanOrEqualTo(partial));
      expect(pausedLength, lessThan(1000));

      await downloads.resumeJob('aaa11111111');
      await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.completed,
      );
      expect(server.rangeRequests, greaterThanOrEqualTo(1));
      final File file = paths.downloadFile('aaa11111111', 'opus');
      expect(await file.readAsBytes(), bytes);
    } finally {
      await server.stop();
    }
  });

  test('ruang tidak cukup: job gagal storage_full tanpa memanggil server', () async {
    final List<int> bytes = List<int>.generate(1000, (int i) => i % 256);
    final _TestServer server = _TestServer(bytes: bytes);
    final Uri base = await server.start();
    try {
      freeSpace.free = 50;
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(baseUrl: base.toString(), contentLength: 1000),
      );
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      final DownloadJob? job = await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.failed,
      );
      expect(job!.errorMessage, DownloadFailure.storageFull);
      expect(job.attempts, 1);
      expect(server.requests, 0);
    } finally {
      await server.stop();
    }
  });

  test('ruang tidak diketahui (null): unduhan tetap jalan', () async {
    final List<int> bytes = List<int>.generate(200, (int i) => i % 256);
    final _TestServer server = _TestServer(bytes: bytes);
    final Uri base = await server.start();
    try {
      freeSpace.free = null;
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(baseUrl: base.toString(), contentLength: 200),
      );
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.completed,
      );
    } finally {
      await server.stop();
    }
  });

  test('dedup: enqueue lagu yang sama dua kali hanya membuat 1 job', () async {
    final List<int> bytes = List<int>.generate(200, (int i) => i % 256);
    final _TestServer server = _TestServer(bytes: bytes);
    final Uri base = await server.start();
    try {
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(baseUrl: base.toString(), contentLength: 200),
      );
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      expect(await downloads.enqueue(_track('aaa11111111')), isFalse);
      await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.completed,
      );
      // Sudah terunduh: enqueue lagi ditolak.
      expect(await downloads.enqueue(_track('aaa11111111')), isFalse);
      expect((await library.downloadJobs()).length, 1);
      expect(server.requests, 1);
    } finally {
      await server.stop();
    }
  });

  test('deleteDownload: file + job + status dibersihkan, lagu tetap di Library', () async {
    final List<int> bytes = List<int>.generate(200, (int i) => i % 256);
    final _TestServer server = _TestServer(bytes: bytes);
    final Uri base = await server.start();
    try {
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(baseUrl: base.toString(), contentLength: 200),
      );
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.completed,
      );
      await downloads.deleteDownload('aaa11111111');
      expect(await paths.downloadFile('aaa11111111', 'opus').exists(), isFalse);
      expect(await library.downloadJobBySongId('aaa11111111'), isNull);
      final SongView? view = await library.songById('aaa11111111');
      expect(view, isNotNull);
      expect(view!.song.downloadState, DownloadState.notDownloaded);
      expect(view.song.filePath, isNull);
      expect(view.song.inLibrary, isTrue);
    } finally {
      await server.stop();
    }
  });

  test('resolve gagal permanen (bukan jaringan): unplayable tanpa retry', () async {
    final _TestServer server = _TestServer(bytes: <int>[]);
    final Uri base = await server.start();
    try {
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(
          baseUrl: base.toString(),
          failResolveTimes: 10,
          resolveError: const ExtractorException(
            ResolveFailureCause.parseFailed,
          ),
        ),
      );
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      final DownloadJob? job = await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.failed,
      );
      expect(job!.errorMessage, DownloadFailure.unplayable);
      expect(job.attempts, 1);
      expect(server.requests, 0);
    } finally {
      await server.stop();
    }
  });

  test('resolve gagal jaringan 2x lalu berhasil: retry resolve dihitung', () async {
    final List<int> bytes = List<int>.generate(200, (int i) => i % 256);
    final _TestServer server = _TestServer(bytes: bytes);
    final Uri base = await server.start();
    try {
      final _FakeUrlSource source = _FakeUrlSource(
        baseUrl: base.toString(),
        contentLength: 200,
        failResolveTimes: 2,
        resolveError: const ExtractorException(
          ResolveFailureCause.emptyResponse,
          isNetworkError: true,
        ),
      );
      final DownloadService downloads = await buildService(urlSource: source);
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      final DownloadJob? job = await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.completed,
      );
      expect(job!.attempts, 3);
      expect(source.resolveCalls, 3);
    } finally {
      await server.stop();
    }
  });

  test('enqueue ulang job gagal: anggaran percobaan direset, unduhan jalan', () async {
    final List<int> bytes = List<int>.generate(200, (int i) => i % 256);
    final _TestServer server = _TestServer(bytes: bytes, failFirst: 3);
    final Uri base = await server.start();
    try {
      final DownloadService downloads = await buildService(
        urlSource: _FakeUrlSource(baseUrl: base.toString(), contentLength: 200),
      );
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.failed,
      );
      // Server kini sehat (3 kegagalan terpakai): enqueue ulang berhasil.
      expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
      final DownloadJob? job = await _waitForJob(
        library,
        'aaa11111111',
        (DownloadJob? j) => j?.status == DownloadJobStatus.completed,
      );
      expect(job!.attempts, 1);
      expect(job.errorMessage, isNull);
    } finally {
      await server.stop();
    }
  });

  group('R2-M1: sabuk kedua validasi URL di layanan unduhan', () {
    test('URL di luar host yang diizinkan tidak pernah di-fetch', () async {
      final _TestServer server = _TestServer(bytes: <int>[]);
      await server.start();
      try {
        // Validator bawaan (allowlist produksi), bukan yang longgar.
        final DownloadService downloads = await buildService(
          urlSource: _FakeUrlSource(
            baseUrl: 'https://evil.example',
            contentLength: 1000,
          ),
          allowLocalServer: false,
        );
        expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
        final DownloadJob? job = await _waitForJob(
          library,
          'aaa11111111',
          (DownloadJob? j) => j?.status == DownloadJobStatus.failed,
        );
        // Gagal permanen tanpa retry: URL tidak sah tidak akan sah.
        expect(job!.errorMessage, DownloadFailure.unplayable);
        expect(job.attempts, 1);
        expect(server.requests, 0);
        expect(
          await paths.downloadFile('aaa11111111', 'opus').exists(),
          isFalse,
        );
        expect(
          await paths.downloadPartFile('aaa11111111', 'opus').exists(),
          isFalse,
        );
      } finally {
        await server.stop();
      }
    });
  });

  group('R2-M2: cap byte unduhan', () {
    test('total yang dideklarasikan di atas cap ditolak tanpa request',
        () async {
      final List<int> bytes = List<int>.generate(200, (int i) => i % 256);
      final _TestServer server = _TestServer(bytes: bytes);
      final Uri base = await server.start();
      try {
        final DownloadService downloads = await buildService(
          urlSource: _FakeUrlSource(
            baseUrl: base.toString(),
            contentLength: 20 * 1024,
          ),
          maxDownloadBytes: 10 * 1024,
        );
        expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
        final DownloadJob? job = await _waitForJob(
          library,
          'aaa11111111',
          (DownloadJob? j) => j?.status == DownloadJobStatus.failed,
        );
        expect(job!.errorMessage, DownloadFailure.unplayable);
        expect(job.attempts, 1);
        expect(server.requests, 0, reason: 'ditolak sebelum mengunduh');
      } finally {
        await server.stop();
      }
    });

    test('total dari header respons di atas cap ditolak sebelum membaca '
        'badan', () async {
      final List<int> bytes = List<int>.generate(20 * 1024, (int i) => i % 256);
      final _TestServer server = _TestServer(bytes: bytes);
      final Uri base = await server.start();
      try {
        final DownloadService downloads = await buildService(
          urlSource: _FakeUrlSource(
            baseUrl: base.toString(),
            contentLength: null,
          ),
          maxDownloadBytes: 10 * 1024,
        );
        expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
        final DownloadJob? job = await _waitForJob(
          library,
          'aaa11111111',
          (DownloadJob? j) => j?.status == DownloadJobStatus.failed,
        );
        expect(job!.errorMessage, DownloadFailure.unplayable);
        expect(job.attempts, 1);
        expect(server.requests, 1, reason: 'header dibaca, badan tidak');
        expect(
          await paths.downloadFile('aaa11111111', 'opus').exists(),
          isFalse,
        );
        expect(
          await paths.downloadPartFile('aaa11111111', 'opus').exists(),
          isFalse,
        );
      } finally {
        await server.stop();
      }
    });

    test('stream tanpa Content-Length yang melewati cap dihentikan di '
        'tengah jalan, .part dihapus', () async {
      // Server mengalirkan 100 KB chunked; resolver mendeklarasikan
      // 5 KB; cap tes 10 KB -> stream dihentikan di ~10 KB.
      final _ChunkedServer server = _ChunkedServer(totalBytes: 100 * 1024);
      final Uri base = await server.start();
      try {
        final DownloadService downloads = await buildService(
          urlSource: _FakeUrlSource(
            baseUrl: base.toString(),
            contentLength: 5 * 1024,
          ),
          maxDownloadBytes: 10 * 1024,
        );
        expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
        final DownloadJob? job = await _waitForJob(
          library,
          'aaa11111111',
          (DownloadJob? j) => j?.status == DownloadJobStatus.failed,
        );
        expect(job!.errorMessage, DownloadFailure.unplayable);
        expect(job.attempts, 1, reason: 'tanpa retry: server berbohong');
        expect(server.requests, 1);
        // .part dihapus (bukan dipertahankan 10 KB): ruang kembali.
        expect(
          await paths.downloadPartFile('aaa11111111', 'opus').exists(),
          isFalse,
        );
        expect(
          await paths.downloadFile('aaa11111111', 'opus').exists(),
          isFalse,
        );
      } finally {
        await server.stop();
      }
    });

    test('stream tanpa total yang dideklarasikan memakai batas absolut',
        () async {
      final _ChunkedServer server = _ChunkedServer(totalBytes: 100 * 1024);
      final Uri base = await server.start();
      try {
        final DownloadService downloads = await buildService(
          urlSource: _FakeUrlSource(
            baseUrl: base.toString(),
            contentLength: null,
          ),
          maxDownloadBytes: 10 * 1024,
        );
        expect(await downloads.enqueue(_track('aaa11111111')), isTrue);
        final DownloadJob? job = await _waitForJob(
          library,
          'aaa11111111',
          (DownloadJob? j) => j?.status == DownloadJobStatus.failed,
        );
        expect(job!.errorMessage, DownloadFailure.unplayable);
        expect(job.attempts, 1);
        expect(
          await paths.downloadPartFile('aaa11111111', 'opus').exists(),
          isFalse,
        );
      } finally {
        await server.stop();
      }
    });
  });
}
