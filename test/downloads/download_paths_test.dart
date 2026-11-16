import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/downloads/downloads.dart';

void main() {
  late Directory temp;
  late DownloadPaths paths;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('laras_paths_test');
    final Directory downloads = Directory('${temp.path}/downloads')
      ..createSync();
    final Directory cache = Directory('${temp.path}/cache')..createSync();
    paths = DownloadPaths(downloadsDir: downloads, cacheDir: cache);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('extensionForMimeType', () {
    test('opus -> opus', () {
      expect(
        extensionForMimeType('audio/webm; codecs="opus"'),
        'opus',
      );
    });

    test('audio/mp4 -> m4a', () {
      expect(
        extensionForMimeType('audio/mp4; codecs="mp4a.40.2"'),
        'm4a',
      );
    });

    test('audio/webm tanpa opus -> webm', () {
      expect(extensionForMimeType('audio/webm'), 'webm');
    });

    test('audio/mpeg -> mp3', () {
      expect(extensionForMimeType('audio/mpeg'), 'mp3');
    });

    test('mimeType tak dikenal -> bin', () {
      expect(extensionForMimeType('application/octet-stream'), 'bin');
      expect(extensionForMimeType(''), 'bin');
    });
  });

  group('nama file unduhan', () {
    test('downloadFileName = <videoId>.<ekstensi>', () {
      expect(paths.downloadFileName('hhn-nGSuenM', 'opus'), 'hhn-nGSuenM.opus');
    });

    test('downloadPartFile menambah .part', () {
      expect(
        paths.downloadPartFile('hhn-nGSuenM', 'opus').path,
        endsWith('hhn-nGSuenM.opus.part'),
      );
    });

    test('videoId dengan underscore dan dash diizinkan', () {
      expect(paths.downloadFileName('NL8WUtq_NDY', 'm4a'), 'NL8WUtq_NDY.m4a');
    });
  });

  group('nama file cache', () {
    test('cacheFileName = <videoId>_<itag>.<ekstensi>', () {
      expect(
        paths.cacheFileName('NL8WUtq_NDY', 251, 'opus'),
        'NL8WUtq_NDY_251.opus',
      );
    });

    test('cacheKey = <videoId>_<itag>', () {
      expect(DownloadPaths.cacheKey('NL8WUtq_NDY', 251), 'NL8WUtq_NDY_251');
    });

    test('cachePartFile menambah .part', () {
      expect(
        paths.cachePartFile('abc', 140, 'm4a').path,
        endsWith('abc_140.m4a.part'),
      );
    });
  });

  group('downloadFileFromRelative', () {
    test('nama relatif valid -> File di direktori unduhan', () {
      final File? file = paths.downloadFileFromRelative('abc123.opus');
      expect(file, isNotNull);
      expect(file!.path, endsWith('abc123.opus'));
    });

    test('nama tanpa titik -> null', () {
      expect(paths.downloadFileFromRelative('abc123'), isNull);
    });

    test('nama dengan dua titik -> null', () {
      expect(paths.downloadFileFromRelative('a.b.c'), isNull);
    });

    test('path traversal -> null', () {
      expect(paths.downloadFileFromRelative('../x.opus'), isNull);
      expect(paths.downloadFileFromRelative('a/b.opus'), isNull);
    });
  });

  group('cacheFileFromRelative (R2-L3)', () {
    test('nama relatif valid -> File di direktori cache', () {
      final File? file = paths.cacheFileFromRelative('NL8WUtq_NDY_251.opus');
      expect(file, isNotNull);
      expect(file!.path, endsWith('NL8WUtq_NDY_251.opus'));
    });

    test('path traversal -> null', () {
      expect(
        paths.cacheFileFromRelative('../../databases/laras.sqlite'),
        isNull,
      );
      expect(paths.cacheFileFromRelative('../x_251.opus'), isNull);
      expect(paths.cacheFileFromRelative('a/b_251.opus'), isNull);
    });

    test('tanpa itag atau itag bukan angka -> null', () {
      expect(paths.cacheFileFromRelative('abc123.opus'), isNull);
      expect(paths.cacheFileFromRelative('abc_xyz.opus'), isNull);
      expect(paths.cacheFileFromRelative('abc_251.opus.bak'), isNull);
    });

    test('videoId ber-underscore tetap valid (itag di _ terakhir)', () {
      expect(
        paths.cacheFileFromRelative('NL8WUtq_NDY_140.m4a'),
        isNotNull,
      );
    });

    test('isValidDownloadRelativePath menolak traversal', () {
      expect(
        DownloadPaths.isValidDownloadRelativePath(
          '../../databases/laras.sqlite',
        ),
        isFalse,
      );
      expect(
        DownloadPaths.isValidDownloadRelativePath('abc123.opus'),
        isTrue,
      );
    });
  });

  group('validasi anti path-traversal', () {
    test('videoId dengan slash ditolak', () {
      expect(
        () => paths.downloadFileName('../x', 'opus'),
        throwsArgumentError,
      );
      expect(
        () => paths.downloadFileName('a/b', 'opus'),
        throwsArgumentError,
      );
    });

    test('videoId kosong atau berspasi ditolak', () {
      expect(() => paths.downloadFileName('', 'opus'), throwsArgumentError);
      expect(
        () => paths.downloadFileName('a b', 'opus'),
        throwsArgumentError,
      );
    });

    test('ekstensi huruf besar atau bertitik ditolak', () {
      expect(
        () => paths.downloadFileName('abc', 'MP3'),
        throwsArgumentError,
      );
      expect(
        () => paths.downloadFileName('abc', '.opus'),
        throwsArgumentError,
      );
    });

    test('validasi yang sama berlaku untuk cache', () {
      expect(
        () => paths.cacheFileName('../x', 251, 'opus'),
        throwsArgumentError,
      );
    });
  });
}
