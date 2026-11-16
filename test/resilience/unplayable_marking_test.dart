/// Tes penjaga penandaan lagu (P6, B4.7): kerusakan massal dan lagu
/// terunduh tidak pernah ditandai.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/canary.dart';
import 'package:laras/extractor/remote_config.dart';
import 'package:laras/resilience/service_status.dart';
import 'package:laras/resilience/unplayable_marking.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/test_database.dart';
import '../player/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LarasDatabase db;
  late LibraryService library;
  late SharedPreferences prefs;

  setUp(() async {
    (db, library) = createTestLibrary();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  ServiceStatusService makeStatusService() {
    return ServiceStatusService(
      canary: CanaryChecker(
        resolver: FakeAudioResolver(),
        prefs: prefs,
        videoIds: const <String>['aaa111aaa11'],
      ),
      config: RemoteConfigLoader(prefs: prefs, dio: Dio()),
      prefs: prefs,
    );
  }

  test('mark biasa menandai lagu', () async {
    await library.upsertSong(testSong('s1'), addToLibrary: true);
    final LibraryUnplayableMarker marker = LibraryUnplayableMarker(
      library: library,
    );
    await marker.mark('s1');
    expect(await library.isUnplayable('s1'), isTrue);
  });

  test('mark diblokir saat status layanan broken (kerusakan massal)',
      () async {
    await library.upsertSong(testSong('s1'), addToLibrary: true);
    await prefs.setString('laras.service_status', 'broken');
    final LibraryUnplayableMarker marker = LibraryUnplayableMarker(
      library: library,
      serviceStatus: makeStatusService(),
    );
    await marker.mark('s1');
    expect(await library.isUnplayable('s1'), isFalse);
  });

  test('mark diblokir saat status degraded? TIDAK — hanya broken yang '
      'memblokir', () async {
    await library.upsertSong(testSong('s1'), addToLibrary: true);
    await prefs.setString('laras.service_status', 'degraded');
    final LibraryUnplayableMarker marker = LibraryUnplayableMarker(
      library: library,
      serviceStatus: makeStatusService(),
    );
    await marker.mark('s1');
    expect(await library.isUnplayable('s1'), isTrue);
  });

  test('mark tidak pernah menandai lagu terunduh', () async {
    await library.upsertSong(testSong('s1'), addToLibrary: true);
    await library.markDownloaded(
      songId: 's1',
      filePath: 's1.m4a',
      fileSizeBytes: 1000,
    );
    final LibraryUnplayableMarker marker = LibraryUnplayableMarker(
      library: library,
    );
    await marker.mark('s1');
    expect(await library.isUnplayable('s1'), isFalse);
  });

  test('clear membersihkan tanda', () async {
    await library.upsertSong(testSong('s1'), addToLibrary: true);
    await library.markUnplayable('s1');
    final LibraryUnplayableMarker marker = LibraryUnplayableMarker(
      library: library,
    );
    expect(await marker.isMarked('s1'), isTrue);
    await marker.clear('s1');
    expect(await marker.isMarked('s1'), isFalse);
  });
}
