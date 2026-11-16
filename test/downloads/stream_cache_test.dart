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
}
