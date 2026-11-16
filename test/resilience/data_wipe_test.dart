/// Tes "Hapus semua data" (B7.3, P6).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/resilience/data_wipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory documents;
  late Directory temp;
  late Directory downloads;
  late Directory cache;
  late SharedPreferences prefs;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('laras-wipe-test');
    documents = Directory('${root.path}/docs')..createSync();
    temp = Directory('${root.path}/tmp')..createSync();
    downloads = Directory('${root.path}/dl')..createSync();
    cache = Directory('${root.path}/cache')..createSync();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'laras.data_saver': true,
      'laras.service_status': 'broken',
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  DataWipeService makeWipe({
    Future<void> Function()? onStop,
    Future<void> Function()? onClose,
  }) {
    return DataWipeService(
      prefs: prefs,
      documentsDir: documents,
      tempDir: temp,
      databaseFileName: 'laras.sqlite',
      downloadsDir: downloads,
      cacheDir: cache,
      onStopDownloads: onStop,
      onCloseDatabase: onClose,
    );
  }

  test('menghapus DB + unduhan + cache + temp + preferensi', () async {
    File('${documents.path}/laras.sqlite').writeAsStringSync('db');
    File('${documents.path}/laras.sqlite-wal').writeAsStringSync('wal');
    File('${documents.path}/laras.sqlite-shm').writeAsStringSync('shm');
    File('${downloads.path}/lagu.m4a').writeAsStringSync('audio');
    File('${cache.path}/c1.opus').writeAsStringSync('cache');
    File('${temp.path}/sisa.tmp').writeAsStringSync('tmp');
    bool stopped = false;
    bool closed = false;

    final WipeResult result = await makeWipe(
      onStop: () async {
        stopped = true;
      },
      onClose: () async {
        closed = true;
      },
    ).wipeAll();

    expect(stopped, isTrue);
    expect(closed, isTrue);
    expect(result.fullySucceeded, isTrue);
    expect(result.errors, isEmpty);
    expect(result.deletedFiles, 6);
    expect(result.deletedDirectories, 2);
    expect(result.preferencesCleared, isTrue);
    expect(File('${documents.path}/laras.sqlite').existsSync(), isFalse);
    expect(File('${documents.path}/laras.sqlite-wal').existsSync(), isFalse);
    expect(downloads.existsSync(), isFalse);
    expect(cache.existsSync(), isFalse);
    expect(File('${temp.path}/sisa.tmp').existsSync(), isFalse);
    expect(prefs.getBool('laras.data_saver'), isNull);
    expect(prefs.getString('laras.service_status'), isNull);
  });

  test('file yang sudah tidak ada bukan kegagalan (idempotent)', () async {
    final WipeResult result = await makeWipe().wipeAll();
    expect(result.fullySucceeded, isTrue);
    expect(result.deletedFiles, 0);
    // Jalankan kedua kali: tetap sukses.
    final WipeResult again = await makeWipe().wipeAll();
    expect(again.fullySucceeded, isTrue);
  });

  test('satu langkah gagal tidak menghentikan langkah lain', () async {
    File('${downloads.path}/lagu.m4a').writeAsStringSync('audio');
    final WipeResult result = await makeWipe(
      onClose: () async {
        throw StateError('db sudah tertutup');
      },
    ).wipeAll();
    expect(result.fullySucceeded, isFalse);
    expect(result.errors, hasLength(1));
    expect(result.errors.first, contains('menutup database'));
    // Unduhan tetap terhapus walau penutupan DB gagal.
    expect(downloads.existsSync(), isFalse);
    expect(result.preferencesCleared, isTrue);
  });
}
