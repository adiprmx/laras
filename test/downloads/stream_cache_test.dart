import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';

import '../data/test_database.dart';

/// Server HTTP lokal dengan dukungan Range (untuk fetch cache).
class _RangeServer {
  _RangeServer(this.bytes);

  final List<int> bytes;
  HttpServer? _server;

  Future<Uri> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((HttpRequest request) {
      final String? range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null && range.startsWith('bytes=')) {
        final int start = int.parse(range.substring(6).split('-').first);
        final List<int> rest = bytes.sublist(start);
        request.response
          ..statusCode = HttpStatus.partialContent
          ..headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-${bytes.length - 1}/${bytes.length}',
          )
          ..headers.set(HttpHeaders.contentLengthHeader, rest.length)
          ..add(rest)
          ..close();
        return;
      }
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set(HttpHeaders.contentLengthHeader, bytes.length)
        ..add(bytes)
        ..close();
    });
    return Uri.parse('http://127.0.0.1:${_server!.port}/audio');
  }

  Future<void> stop() async => _server?.close(force: true);
}

/// Server yang mengalirkan byte TANPA Content-Length (chunked).
/// Jeda 10 ms per chunk: tanpa jeda, server lokal menulis seluruh
/// 100 KB dalam ~10 ms dan `.part` sudah di-rename + di-eviction
/// sebelum polling pertama — tes tidak membedakan cap yang ditegakkan
/// dari yang tidak. Dengan jeda, klien tanpa cap masih mengunduh
/// (~60 KB di 600 ms) saat polling berjalan.
/// Catatan: byte yang DISAJIKAN server TIDAK dipakai sebagai pembeda —
/// terbukti server terus menulis ~50 KB sesudah klien membatalkan
/// (soket tidak langsung tertutup). Pembeda yang andal adalah ukuran
/// `.part` di sisi klien (lihat tes di bawah).
class _ChunkedServer {
  _ChunkedServer({required this.totalBytes});

  final int totalBytes;
  HttpServer? _server;

  Future<Uri> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((HttpRequest request) async {
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
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await response.close();
      } on Object catch (_) {
        // Klien membatalkan di tengah stream (cap/watchdog): abaikan.
        try {
          await request.response.close();
        } on Object catch (_) {}
      }
    });
    return Uri.parse('http://127.0.0.1:${_server!.port}/audio');
  }

  Future<void> stop() async => _server?.close(force: true);
}

/// Server yang mengirim header (dengan Content-Length) + 1 byte pertama
/// seketika, tapi sisa badannya lambat: 1 KB tiap [chunkDelay] sesudah
/// [firstChunkDelay]. Dipakai tes anggaran: tanpa badan lambat, fetch
/// + eviction pasca-fetch selesai dalam <500 ms dan keadaan akhirnya
/// sama dengan penolakan pra-fetch — tes tidak membedakan keduanya.
/// Dengan badan lambat, klien tanpa anggaran masih mengunduh (file
/// `.part` ADA) saat asersi berjalan, sementara klien dengan anggaran
/// sudah menolak sebelum `.part` dibuat.
/// 1 byte pertama WAJIB dikirim seketika: terbukti empiris Dio baru
/// mengembalikan respons sesudah chunk badan pertama tiba — `flush()`
/// tanpa badan TIDAK mengirim header (dio.get menunggu 2,3 dtk pada
/// server yang flush lalu diam 2 dtk).
class _SlowRangeServer {
  _SlowRangeServer(this.bytes);

  final List<int> bytes;
  static const Duration firstChunkDelay = Duration(milliseconds: 800);
  static const Duration chunkDelay = Duration(milliseconds: 250);
  int requests = 0;
  HttpServer? _server;

  Future<Uri> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((HttpRequest request) async {
      requests++;
      final HttpResponse response = request.response
        ..statusCode = HttpStatus.ok
        ..headers.set(HttpHeaders.contentLengthHeader, bytes.length)
        ..bufferOutput = false;
      try {
        // Header + 1 byte pertama: membuka respons di sisi klien.
        if (bytes.isNotEmpty) {
          response.add(bytes.sublist(0, 1));
          await response.flush();
        }
        await Future<void>.delayed(firstChunkDelay);
        int sent = 1;
        while (sent < bytes.length) {
          final int size = (bytes.length - sent).clamp(0, 1024);
          response.add(bytes.sublist(sent, sent + size));
          await response.flush();
          sent += size;
          await Future<void>.delayed(chunkDelay);
        }
        await response.close();
      } on Object catch (_) {
        // Klien membatalkan (anggaran ditolak): abaikan.
        try {
          await response.close();
        } on Object catch (_) {}
      }
    });
    return Uri.parse('http://127.0.0.1:${_server!.port}/audio');
  }

  Future<void> stop() async => _server?.close(force: true);
}

/// Server yang mengirim header + satu chunk lalu diam (untuk tes
/// watchdog stall R2-L4).
class _StallingServer {
  _StallingServer(this.firstChunk, this.declaredTotal);

  final List<int> firstChunk;
  final int declaredTotal;
  HttpServer? _server;

  Future<Uri> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((HttpRequest request) async {
      try {
        final HttpResponse response = request.response
          ..statusCode = HttpStatus.ok
          ..headers.set(HttpHeaders.contentLengthHeader, declaredTotal)
          ..bufferOutput = false;
        response.add(firstChunk);
        await response.flush();
        // Diam lama: watchdog stall harus membatalkan jauh sebelum ini.
        await Future<void>.delayed(const Duration(seconds: 30));
        await response.close();
      } on Object catch (_) {}
    });
    return Uri.parse('http://127.0.0.1:${_server!.port}/audio');
  }

  Future<void> stop() async => _server?.close(force: true);
}

/// Server yang menerima koneksi tapi tidak pernah membalas (untuk tes
/// timeout header R2-L4).
class _MuteServer {
  HttpServer? _server;

  Future<Uri> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((HttpRequest request) async {
      await Future<void>.delayed(const Duration(seconds: 30));
      try {
        await request.response.close();
      } on Object catch (_) {}
    });
    return Uri.parse('http://127.0.0.1:${_server!.port}/audio');
  }

  Future<void> stop() async => _server?.close(force: true);
}

Future<void> _waitFor(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('kondisi tidak terpenuhi dalam $timeout');
}

void main() {
  late Directory temp;
  late DownloadPaths paths;
  late LarasDatabase db;
  late LibraryService library;
  late StreamCacheService cache;

  Future<void> seedCacheEntry(
    String videoId,
    int itag, {
    required int size,
    required DateTime lastAccessed,
    String extension = 'opus',
  }) async {
    final File file = paths.cacheFile(videoId, itag, extension);
    await file.writeAsBytes(List<int>.filled(size, 7));
    final DateTime now = DateTime.now();
    await library.upsertCacheEntry(
      CacheEntriesCompanion.insert(
        key: DownloadPaths.cacheKey(videoId, itag),
        filePath: paths.cacheFileName(videoId, itag, extension),
        sizeBytes: size,
        lastAccessed: lastAccessed,
        createdAt: now,
      ),
    );
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('laras_cache_test');
    final Directory downloads = Directory('${temp.path}/downloads')
      ..createSync();
    final Directory cacheDir = Directory('${temp.path}/cache')..createSync();
    paths = DownloadPaths(downloadsDir: downloads, cacheDir: cacheDir);
    (db, library) = createTestLibrary();
    cache = StreamCacheService(
      library: library,
      paths: paths,
      cacheLimitBytes: 1000,
    );
  });

  tearDown(() async {
    await cache.dispose();
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('eviction LRU', () {
    test('menghapus entri paling lama tidak diakses sampai di bawah batas', () async {
      final DateTime base = DateTime(2026, 11, 16, 8);
      await seedCacheEntry('aaa11111111', 251, size: 400, lastAccessed: base);
      await seedCacheEntry(
        'bbb22222222',
        251,
        size: 400,
        lastAccessed: base.add(const Duration(hours: 1)),
      );
      await seedCacheEntry(
        'ccc33333333',
        251,
        size: 400,
        lastAccessed: base.add(const Duration(hours: 2)),
      );
      // Total 1200 > batas 1000: hapus 1 entri tertua -> 800.
      await cache.evictIfNeeded();

      expect(await paths.cacheFile('aaa11111111', 251, 'opus').exists(), isFalse);
      expect(await library.cacheEntry('aaa11111111_251'), isNull);
      expect(await paths.cacheFile('bbb22222222', 251, 'opus').exists(), isTrue);
      expect(await paths.cacheFile('ccc33333333', 251, 'opus').exists(), isTrue);
      expect(await library.cacheEntry('bbb22222222_251'), isNotNull);
      expect(await library.cacheEntry('ccc33333333_251'), isNotNull);
    });

    test('tidak menghapus apa pun bila total di bawah batas', () async {
      final DateTime base = DateTime(2026, 11, 16, 8);
      await seedCacheEntry('aaa11111111', 251, size: 400, lastAccessed: base);
      await cache.evictIfNeeded();
      expect(await paths.cacheFile('aaa11111111', 251, 'opus').exists(), isTrue);
      expect(await library.cacheEntry('aaa11111111_251'), isNotNull);
    });

    test('lagu yang sedang diputar tidak pernah di-eviction', () async {
      final DateTime base = DateTime(2026, 11, 16, 8);
      await seedCacheEntry('aaa11111111', 251, size: 400, lastAccessed: base);
      await seedCacheEntry(
        'bbb22222222',
        251,
        size: 400,
        lastAccessed: base.add(const Duration(hours: 1)),
      );
      await seedCacheEntry(
        'ccc33333333',
        251,
        size: 400,
        lastAccessed: base.add(const Duration(hours: 2)),
      );
      // A tertua tapi sedang diputar: B yang dihapus.
      cache.protectedVideoId = () => 'aaa11111111';
      await cache.evictIfNeeded();

      expect(await paths.cacheFile('aaa11111111', 251, 'opus').exists(), isTrue);
      expect(await paths.cacheFile('bbb22222222', 251, 'opus').exists(), isFalse);
      expect(await paths.cacheFile('ccc33333333', 251, 'opus').exists(), isTrue);
    });

    test('videoId ber-underscore dikenali saat proteksi (pisah di _ terakhir)', () async {
      final DateTime base = DateTime(2026, 11, 16, 8);
      // 'NL8WUtq_NDY' berisi underscore; kuncinya 'NL8WUtq_NDY_251'.
      await seedCacheEntry('NL8WUtq_NDY', 251, size: 400, lastAccessed: base);
      await seedCacheEntry(
        'bbb22222222',
        251,
        size: 400,
        lastAccessed: base.add(const Duration(hours: 1)),
      );
      await seedCacheEntry(
        'ccc33333333',
        251,
        size: 400,
        lastAccessed: base.add(const Duration(hours: 2)),
      );
      cache.protectedVideoId = () => 'NL8WUtq_NDY';
      await cache.evictIfNeeded();

      expect(await paths.cacheFile('NL8WUtq_NDY', 251, 'opus').exists(), isTrue);
      expect(await library.cacheEntry('NL8WUtq_NDY_251'), isNotNull);
      expect(await paths.cacheFile('bbb22222222', 251, 'opus').exists(), isFalse);
    });
  });

  group('K9: eviction tidak pernah menghapus unduhan', () {
    test('eviction menghapus cache tapi file unduhan tetap utuh', () async {
      // Satu lagu terunduh (file + status di database).
      await library.upsertSong(
        testSong('ddd44444444', title: 'Lagu Unduhan'),
        addToLibrary: true,
      );
      final File downloadFile = paths.downloadFile('ddd44444444', 'opus');
      await downloadFile.writeAsBytes(List<int>.filled(500, 3));
      await library.markDownloaded(
        songId: 'ddd44444444',
        filePath: 'ddd44444444.opus',
        fileSizeBytes: 500,
      );
      // Cache melebihi batas.
      final DateTime base = DateTime(2026, 11, 16, 8);
      await seedCacheEntry('aaa11111111', 251, size: 600, lastAccessed: base);
      await seedCacheEntry(
        'bbb22222222',
        251,
        size: 600,
        lastAccessed: base.add(const Duration(hours: 1)),
      );

      await cache.evictIfNeeded();

      // Cache tertua terhapus...
      expect(await paths.cacheFile('aaa11111111', 251, 'opus').exists(), isFalse);
      // ...tapi unduhan utuh: file ada, status tetap terunduh.
      expect(await downloadFile.exists(), isTrue);
      expect(await downloadFile.length(), 500);
      final SongView? view = await library.songById('ddd44444444');
      expect(view?.song.downloadState, DownloadState.downloaded);
      expect(view?.song.filePath, 'ddd44444444.opus');
    });

    test('clearAll menghapus cache tapi tidak menyentuh unduhan', () async {
      await library.upsertSong(
        testSong('ddd44444444', title: 'Lagu Unduhan'),
        addToLibrary: true,
      );
      final File downloadFile = paths.downloadFile('ddd44444444', 'opus');
      await downloadFile.writeAsBytes(List<int>.filled(500, 3));
      await library.markDownloaded(
        songId: 'ddd44444444',
        filePath: 'ddd44444444.opus',
        fileSizeBytes: 500,
      );
      await seedCacheEntry(
        'aaa11111111',
        251,
        size: 400,
        lastAccessed: DateTime(2026, 11, 16, 8),
      );

      await cache.clearAll();

      expect(await paths.cacheFile('aaa11111111', 251, 'opus').exists(), isFalse);
      expect(await library.cacheEntry('aaa11111111_251'), isNull);
      expect(await downloadFile.exists(), isTrue);
      final SongView? view = await library.songById('ddd44444444');
      expect(view?.song.downloadState, DownloadState.downloaded);
    });
  });

  group('fileFor', () {
    test('mengembalikan file dan memperbarui waktu akses (LRU)', () async {
      // Waktu lama relatif terhadap jam dinding (bukan tanggal mutlak:
      // jam VM bisa berada di pagi hari tanggal yang sama).
      final DateTime old = DateTime.now().subtract(const Duration(hours: 2));
      await seedCacheEntry('aaa11111111', 251, size: 400, lastAccessed: old);
      final File? file = await cache.fileFor('aaa11111111');
      expect(file, isNotNull);
      expect(await file!.length(), 400);
      final CacheEntry? entry = await library.cacheEntry('aaa11111111_251');
      expect(entry, isNotNull);
      expect(entry!.lastAccessed.isAfter(old), isTrue);
    });

    test('videoId yang tidak di-cache -> null', () async {
      expect(await cache.fileFor('zzz99999999'), isNull);
    });

    test('entri yang filenya hilang dibersihkan dan mengembalikan null', () async {
      final DateTime now = DateTime.now();
      await library.upsertCacheEntry(
        CacheEntriesCompanion.insert(
          key: 'aaa11111111_251',
          filePath: 'aaa11111111_251.opus',
          sizeBytes: 400,
          lastAccessed: now,
          createdAt: now,
        ),
      );
      expect(await cache.fileFor('aaa11111111'), isNull);
      expect(await library.cacheEntry('aaa11111111_251'), isNull);
    });

    test('entri yang ukuran filenya tidak cocok dibersihkan', () async {
      final File file = paths.cacheFile('aaa11111111', 251, 'opus');
      await file.writeAsBytes(List<int>.filled(100, 7));
      final DateTime now = DateTime.now();
      await library.upsertCacheEntry(
        CacheEntriesCompanion.insert(
          key: 'aaa11111111_251',
          filePath: 'aaa11111111_251.opus',
          sizeBytes: 400,
          lastAccessed: now,
          createdAt: now,
        ),
      );
      expect(await cache.fileFor('aaa11111111'), isNull);
      expect(await library.cacheEntry('aaa11111111_251'), isNull);
      expect(await file.exists(), isFalse);
    });
  });

  group('invalidate', () {
    test('menghapus semua itag satu videoId beserta filenya', () async {
      final DateTime base = DateTime(2026, 11, 16, 8);
      await seedCacheEntry('aaa11111111', 251, size: 100, lastAccessed: base);
      await seedCacheEntry(
        'aaa11111111',
        140,
        size: 100,
        lastAccessed: base,
        extension: 'm4a',
      );
      await seedCacheEntry(
        'bbb22222222',
        251,
        size: 100,
        lastAccessed: base,
      );

      await cache.invalidate('aaa11111111');

      expect(await paths.cacheFile('aaa11111111', 251, 'opus').exists(), isFalse);
      expect(await paths.cacheFile('aaa11111111', 140, 'm4a').exists(), isFalse);
      expect(await library.cacheEntry('aaa11111111_251'), isNull);
      expect(await library.cacheEntry('aaa11111111_140'), isNull);
      // VideoId lain tidak ikut terhapus.
      expect(await paths.cacheFile('bbb22222222', 251, 'opus').exists(), isTrue);
    });
  });

  group('fetch latar (server lokal)', () {
    test('noteResolved mengunduh salinan penuh + manifest', () async {
      final List<int> bytes = List<int>.generate(256, (int i) => i % 256);
      final _RangeServer server = _RangeServer(bytes);
      final Uri url = await server.start();
      try {
        cache.noteResolved(
          'aaa11111111',
          url.toString(),
          251,
          'audio/webm; codecs="opus"',
        );
        await _waitFor(
          () async => await library.cacheEntry('aaa11111111_251') != null,
        );
        final File file = paths.cacheFile('aaa11111111', 251, 'opus');
        expect(await file.exists(), isTrue);
        expect(await file.readAsBytes(), bytes);
        final CacheEntry? entry = await library.cacheEntry('aaa11111111_251');
        expect(entry?.sizeBytes, 256);
        // fileFor kini mengembalikan file itu.
        expect(await cache.fileFor('aaa11111111'), isNotNull);
      } finally {
        await server.stop();
      }
    });

    test('fetch melanjutkan dari .part yang tertinggal (resume Range)', () async {
      final List<int> bytes = List<int>.generate(200, (int i) => i % 251);
      final _RangeServer server = _RangeServer(bytes);
      final Uri url = await server.start();
      try {
        // Separuh file sudah ada sebagai .part.
        final File part = paths.cachePartFile('aaa11111111', 251, 'opus');
        await part.writeAsBytes(bytes.sublist(0, 100));
        cache.noteResolved(
          'aaa11111111',
          url.toString(),
          251,
          'audio/webm; codecs="opus"',
        );
        await _waitFor(
          () async => await library.cacheEntry('aaa11111111_251') != null,
        );
        final File file = paths.cacheFile('aaa11111111', 251, 'opus');
        expect(await file.readAsBytes(), bytes);
        expect(await part.exists(), isFalse);
      } finally {
        await server.stop();
      }
    });

    test('fetch ditunda saat ada unduhan aktif, jalan sesudah idle', () async {
      final List<int> bytes = List<int>.generate(64, (int i) => i);
      final _RangeServer server = _RangeServer(bytes);
      final Uri url = await server.start();
      try {
        bool busy = true;
        cache.isBusy = () => busy;
        cache.noteResolved(
          'aaa11111111',
          url.toString(),
          251,
          'audio/webm; codecs="opus"',
        );
        await cache.pumpPending();
        // Masih sibuk: tidak ada fetch.
        expect(await library.cacheEntry('aaa11111111_251'), isNull);
        expect(
          await paths.cacheFile('aaa11111111', 251, 'opus').exists(),
          isFalse,
        );
        // Antrean unduhan kosong: fetch jalan.
        busy = false;
        await cache.pumpPending();
        await _waitFor(
          () async => await library.cacheEntry('aaa11111111_251') != null,
        );
        expect(
          await paths.cacheFile('aaa11111111', 251, 'opus').exists(),
          isTrue,
        );
      } finally {
        await server.stop();
      }
    });
  });

  group('R2-M2: anggaran byte fetch cache', () {
    test('total yang dideklarasikan di atas batas cache tidak di-fetch',
        () async {
      // Batas tes 1000 byte; server mendeklarasikan 5000 byte.
      // Badan lambat: pembeda penolakan pra-fetch dari eviction
      // pasca-fetch — klien tanpa anggaran masih mengunduh (`.part`
      // ADA) saat asersi berjalan di 500 ms.
      final List<int> bytes = List<int>.generate(5000, (int i) => i % 256);
      final _SlowRangeServer server = _SlowRangeServer(bytes);
      final Uri url = await server.start();
      try {
        cache.noteResolved(
          'aaa11111111',
          url.toString(),
          251,
          'audio/webm; codecs="opus"',
        );
        // Beri waktu fetch ditolak (gagal cepat sesudah header).
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(await library.cacheEntry('aaa11111111_251'), isNull);
        expect(
          await paths.cacheFile('aaa11111111', 251, 'opus').exists(),
          isFalse,
        );
        expect(
          await paths.cachePartFile('aaa11111111', 251, 'opus').exists(),
          isFalse,
          reason: 'anggaran ditolak sebelum `.part` dibuat',
        );
      } finally {
        await server.stop();
      }
    });

    test('stream tanpa Content-Length yang melewati anggaran dihentikan, '
        '.part dihapus', () async {
      // Batas tes 1000 byte; server mengalirkan 100 KB chunked.
      final _ChunkedServer server = _ChunkedServer(totalBytes: 100 * 1024);
      final Uri url = await server.start();
      try {
        cache.noteResolved(
          'aaa11111111',
          url.toString(),
          251,
          'audio/webm; codecs="opus"',
        );
        // Pembeda utama: pantau ukuran `.part` SELAMA fetch berjalan.
        // Dengan cap, `.part` tidak pernah melewati anggaran + 1 chunk
        // (~2 KB) lalu dihapus; tanpa cap, `.part` tumbuh terus
        // (~60 KB di 600 ms). Polling 50 ms cukup rapat: `.part`
        // tanpa cap melewati 8 KB di ~80 ms, jauh sebelum polling
        // berakhir — tidak mungkin terlewat.
        int maxPartSize = 0;
        final File partFile =
            paths.cachePartFile('aaa11111111', 251, 'opus');
        for (int i = 0; i < 12; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          try {
            if (partFile.existsSync()) {
              final int size = partFile.lengthSync();
              if (size > maxPartSize) maxPartSize = size;
            }
          } on FileSystemException {
            // `.part` dihapus antar cek: abaikan.
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(
          maxPartSize,
          lessThanOrEqualTo(8192),
          reason: 'stream dihentikan di tengah jalan, bukan diunduh penuh',
        );
        expect(await library.cacheEntry('aaa11111111_251'), isNull);
        expect(
          await paths.cacheFile('aaa11111111', 251, 'opus').exists(),
          isFalse,
        );
        expect(
          await paths.cachePartFile('aaa11111111', 251, 'opus').exists(),
          isFalse,
          reason: '.part dihapus supaya ruang langsung kembali',
        );
        // Antrean tidak macet: fetch berikutnya tetap jalan.
        final List<int> ok = List<int>.generate(64, (int i) => i);
        final _RangeServer good = _RangeServer(ok);
        final Uri goodUrl = await good.start();
        try {
          cache.noteResolved(
            'bbb22222222',
            goodUrl.toString(),
            251,
            'audio/webm; codecs="opus"',
          );
          await _waitFor(
            () async => await library.cacheEntry('bbb22222222_251') != null,
          );
        } finally {
          await good.stop();
        }
      } finally {
        await server.stop();
      }
    });

    test('eviction memberi tempat dulu bila file muat sesudah eviction',
        () async {
      // Tes PENJAGA (guard): mengunci jalur sukses — fetch yang muat
      // sesudah eviction harus BERHASIL, bukan ditolak. Urutan
      // pra-tulis vs pasca-fetch dibuktikan tes anggaran lain
      // (penolakan + penghentian mid-stream di atas, `.part` di bawah):
      // keadaan akhir eviction pra-tulis dan pasca-fetch sama.
      final DateTime base = DateTime(2026, 11, 16, 8);
      await seedCacheEntry('aaa11111111', 251, size: 600, lastAccessed: base);
      // File baru 500 byte: total 1100 > batas 1000, tapi muat bila
      // entri lama (600) di-eviction dulu.
      final List<int> bytes = List<int>.generate(500, (int i) => i % 256);
      final _RangeServer server = _RangeServer(bytes);
      final Uri url = await server.start();
      try {
        cache.noteResolved(
          'bbb22222222',
          url.toString(),
          251,
          'audio/webm; codecs="opus"',
        );
        await _waitFor(
          () async => await library.cacheEntry('bbb22222222_251') != null,
        );
        expect(await library.cacheEntry('aaa11111111_251'), isNull);
        expect(
          await paths.cacheFile('aaa11111111', 251, 'opus').exists(),
          isFalse,
        );
      } finally {
        await server.stop();
      }
    });

    test('file tidak di-fetch bila eviction terhalang lagu yang diputar',
        () async {
      final DateTime base = DateTime(2026, 11, 16, 8);
      await seedCacheEntry('aaa11111111', 251, size: 600, lastAccessed: base);
      cache.protectedVideoId = () => 'aaa11111111';
      // Badan lambat: pembeda penolakan pra-fetch (`.part` tidak pernah
      // dibuat) dari eviction pasca-fetch (`.part` ADA saat asersi).
      final List<int> bytes = List<int>.generate(500, (int i) => i % 256);
      final _SlowRangeServer server = _SlowRangeServer(bytes);
      final Uri url = await server.start();
      try {
        cache.noteResolved(
          'bbb22222222',
          url.toString(),
          251,
          'audio/webm; codecs="opus"',
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(await library.cacheEntry('bbb22222222_251'), isNull);
        expect(
          await paths.cachePartFile('bbb22222222', 251, 'opus').exists(),
          isFalse,
          reason: 'anggaran ditolak sebelum `.part` dibuat',
        );
        // Entri yang dilindungi tetap utuh.
        expect(await library.cacheEntry('aaa11111111_251'), isNotNull);
        expect(
          await paths.cacheFile('aaa11111111', 251, 'opus').exists(),
          isTrue,
        );
      } finally {
        await server.stop();
      }
    });
  });

  group('R2-L4: timeout + watchdog stall fetch cache', () {
    test('server yang diam sesudah chunk pertama: fetch dibatalkan, '
        'antrean lanjut', () async {
      final StreamCacheService fastCache = StreamCacheService(
        library: library,
        paths: paths,
        cacheLimitBytes: 1000,
        stallTimeout: const Duration(milliseconds: 300),
      );
      final List<int> first = List<int>.filled(64, 7);
      final _StallingServer stalling = _StallingServer(first, 512);
      final Uri badUrl = await stalling.start();
      try {
        fastCache.noteResolved(
          'aaa11111111',
          badUrl.toString(),
          251,
          'audio/webm; codecs="opus"',
        );
        // Watchdog 300 ms: fetch harus sudah dibatalkan dalam 5 dtk,
        // jauh sebelum server menutup di 30 dtk.
        await Future<void>.delayed(const Duration(seconds: 2));
        expect(await library.cacheEntry('aaa11111111_251'), isNull);
        // Kunci fetch lepas: fetch berikutnya jalan (antrean tidak macet).
        final List<int> ok = List<int>.generate(64, (int i) => i);
        final _RangeServer good = _RangeServer(ok);
        final Uri goodUrl = await good.start();
        try {
          fastCache.noteResolved(
            'bbb22222222',
            goodUrl.toString(),
            251,
            'audio/webm; codecs="opus"',
          );
          await _waitFor(
            () async => await library.cacheEntry('bbb22222222_251') != null,
          );
        } finally {
          await good.stop();
        }
      } finally {
        await stalling.stop();
        await fastCache.dispose();
      }
    });

    test('server yang tidak pernah membalas header: fetch dibatalkan, '
        'antrean lanjut', () async {
      final StreamCacheService fastCache = StreamCacheService(
        library: library,
        paths: paths,
        cacheLimitBytes: 1000,
        fetchHeaderTimeout: const Duration(milliseconds: 300),
      );
      final _MuteServer mute = _MuteServer();
      final Uri badUrl = await mute.start();
      try {
        fastCache.noteResolved(
          'aaa11111111',
          badUrl.toString(),
          251,
          'audio/webm; codecs="opus"',
        );
        await Future<void>.delayed(const Duration(seconds: 2));
        expect(await library.cacheEntry('aaa11111111_251'), isNull);
        final List<int> ok = List<int>.generate(64, (int i) => i);
        final _RangeServer good = _RangeServer(ok);
        final Uri goodUrl = await good.start();
        try {
          fastCache.noteResolved(
            'bbb22222222',
            goodUrl.toString(),
            251,
            'audio/webm; codecs="opus"',
          );
          await _waitFor(
            () async => await library.cacheEntry('bbb22222222_251') != null,
          );
        } finally {
          await good.stop();
        }
      } finally {
        await mute.stop();
        await fastCache.dispose();
      }
    });
  });

  group('R2-L3: nama file cache dari database divalidasi bentuknya', () {
    Future<File> seedSentinel() async {
      final File sentinel = File('${temp.path}/sentinel.txt');
      await sentinel.writeAsBytes(List<int>.filled(100, 5));
      return sentinel;
    }

    Future<void> seedPoisonedEntry({DateTime? lastAccessed}) async {
      final DateTime now = DateTime.now();
      await library.upsertCacheEntry(
        CacheEntriesCompanion.insert(
          key: 'aaa11111111_251',
          // Dari direktori cache, ini menunjuk ke file DI LUAR cache
          // (temp/sentinel.txt) — kode lama akan membaca/menghapusnya.
          filePath: '../sentinel.txt',
          sizeBytes: 100,
          lastAccessed: lastAccessed ?? now,
          createdAt: now,
        ),
      );
    }

    test('fileFor: entri beracun dihapus, file di luar cache tidak '
        'disentuh', () async {
      final File sentinel = await seedSentinel();
      await seedPoisonedEntry();
      // Ukuran sentinel sama dengan sizeBytes entri: kode lama akan
      // mengembalikan file itu sebagai "cache yang bisa dipakai".
      expect(await cache.fileFor('aaa11111111'), isNull);
      expect(await library.cacheEntry('aaa11111111_251'), isNull);
      expect(await sentinel.exists(), isTrue);
      expect(await sentinel.length(), 100);
    });

    test('evictIfNeeded: entri beracun dihapus, file di luar cache tidak '
        'dihapus', () async {
      final File sentinel = await seedSentinel();
      final DateTime base = DateTime(2026, 11, 16, 8);
      // Entri beracun paling lama tidak diakses: eviction menghapusnya
      // pertama.
      await seedPoisonedEntry(lastAccessed: base);
      await seedCacheEntry(
        'bbb22222222',
        251,
        size: 950,
        lastAccessed: base.add(const Duration(hours: 1)),
      );
      // Total manifest 1050 > batas 1000: eviction berjalan.
      await cache.setCacheLimitBytes(100);
      expect(await library.cacheEntry('aaa11111111_251'), isNull);
      expect(await sentinel.exists(), isTrue);
      expect(await sentinel.length(), 100);
    });

    test('invalidate: entri beracun dihapus, file di luar cache tidak '
        'dihapus', () async {
      final File sentinel = await seedSentinel();
      await seedPoisonedEntry();
      await cache.invalidate('aaa11111111');
      expect(await library.cacheEntry('aaa11111111_251'), isNull);
      expect(await sentinel.exists(), isTrue);
    });

    test('clearAll: entri beracun dihapus, file di luar cache tidak '
        'dihapus', () async {
      final File sentinel = await seedSentinel();
      await seedPoisonedEntry();
      await cache.clearAll();
      expect(await library.cacheEntry('aaa11111111_251'), isNull);
      expect(await sentinel.exists(), isTrue);
    });

    test('reconcile: entri beracun dihapus sebagai basi, file di luar '
        'cache tidak dihapus', () async {
      final File sentinel = await seedSentinel();
      await seedPoisonedEntry();
      final CacheReconcileResult result = await cache.reconcile();
      expect(result.staleEntriesDeleted, 1);
      expect(await library.cacheEntry('aaa11111111_251'), isNull);
      expect(await sentinel.exists(), isTrue);
    });

    test('fetch ulang: entri beracun diganti entri sah, file di luar '
        'cache tidak disentuh', () async {
      final File sentinel = await seedSentinel();
      await seedPoisonedEntry();
      final List<int> bytes = List<int>.generate(64, (int i) => i);
      final _RangeServer server = _RangeServer(bytes);
      final Uri url = await server.start();
      try {
        cache.noteResolved(
          'aaa11111111',
          url.toString(),
          251,
          'audio/webm; codecs="opus"',
        );
        await _waitFor(() async {
          final CacheEntry? entry =
              await library.cacheEntry('aaa11111111_251');
          return entry != null &&
              entry.filePath == 'aaa11111111_251.opus';
        });
        expect(await sentinel.exists(), isTrue);
        expect(
          await paths.cacheFile('aaa11111111', 251, 'opus').exists(),
          isTrue,
        );
      } finally {
        await server.stop();
      }
    });
  });
}
