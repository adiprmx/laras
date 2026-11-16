/// Tes layanan salinan data (P8, PRD B7.2/B7.3/B10.3/B7.5):
/// end-to-end ekspor -> hapus -> impor dengan database drift nyata,
/// merge (playlist nama sama, antrean di belakang, pengaturan
/// opsional), atomicitas, dan batas antrean penuh.
/// Tes ekspor memakai MethodChannel tiruan (tanpa Android).
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/features/backup/backup_file_channel.dart';
import 'package:laras/features/backup/backup_service.dart';
import 'package:laras/features/backup/import_report.dart';
import 'package:laras/resilience/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/test_database.dart';

const MethodChannel _kChannel = MethodChannel(
  'id.my.adipmusic.laras/backup_files',
);

/// Isi database uji yang kaya: 3 lagu, 1 playlist, riwayat putar +
/// pencarian, antrean 2 lagu, posisi pemutar, 1 lagu terunduh.
Future<void> seedRichLibrary(LibraryService library) async {
  await library.importSongs(<SongImport>[
    SongImport(
      song: SongsCompanion(
        id: const Value<String>('vid-1'),
        title: const Value<String>('Lagu Satu'),
        durationSeconds: const Value<int?>(180),
        liked: const Value<bool>(true),
        inLibrary: const Value<bool>(true),
      ),
      artistNames: <String>['Artis Satu'],
      artistChannelIds: <String?>['UC-1'],
    ),
    SongImport(
      song: SongsCompanion(
        id: const Value<String>('vid-2'),
        title: const Value<String>('Lagu Dua'),
        durationSeconds: const Value<int?>(200),
        inLibrary: const Value<bool>(true),
      ),
      artistNames: <String>['Artis Dua'],
    ),
    SongImport(
      song: SongsCompanion(
        id: const Value<String>('vid-3'),
        title: const Value<String>('Lagu Tiga'),
        durationSeconds: const Value<int?>(150),
      ),
      artistNames: <String>['Artis Tiga'],
    ),
  ]);
  final int playlistId = await library.createPlaylist(
    'Favoritku',
    description: 'Lagu-lagu pilihan',
  );
  await library.addSongToPlaylist(playlistId, 'vid-1');
  await library.addSongToPlaylist(playlistId, 'vid-2');
  await library.recordPlay(
    songId: 'vid-1',
    timestamp: DateTime.utc(2026, 11, 16, 10),
    playTimeMs: 120000,
  );
  await library.addSearchQuery('noah');
  await library.addSearchQuery('peterpan');
  await library.replaceQueue(<QueueItemsCompanion>[
    QueueItemsCompanion.insert(
      position: const Value<int>(0),
      songId: 'vid-1',
      source: const Value<String?>('library'),
    ),
    QueueItemsCompanion.insert(
      position: const Value<int>(1),
      songId: 'vid-2',
    ),
  ]);
  await library.savePlaybackState(
    currentIndex: 1,
    positionMs: 45000,
    shuffleEnabled: true,
    repeatMode: 1,
  );
  await library.markDownloaded(
    songId: 'vid-1',
    filePath: '/tmp/fake/vid-1.m4a',
    fileSizeBytes: 1234567,
  );
}

Future<BackupService> makeService(
  LibraryService library, {
  Map<String, Object> prefsValues = const <String, Object>{},
  Directory? tempDir,
  void Function(BackupSettings)? onSettingsApplied,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  // getInstance meng-cache instance antar tes: bersihkan lalu isi nilai
  // tes ini secara eksplisit (setMockInitialValues saja tidak cukup).
  await prefs.clear();
  for (final MapEntry<String, Object> e in prefsValues.entries) {
    final Object value = e.value;
    if (value is bool) {
      await prefs.setBool(e.key, value);
    } else if (value is String) {
      await prefs.setString(e.key, value);
    } else if (value is int) {
      await prefs.setInt(e.key, value);
    } else if (value is double) {
      await prefs.setDouble(e.key, value);
    }
  }
  final AppSettings settings = AppSettings.forTest(prefs);
  return BackupService(
    library: library,
    settings: settings,
    prefs: prefs,
    files: BackupFileChannel(),
    tempDirProvider: tempDir == null ? null : () async => tempDir,
    onSettingsApplied: onSettingsApplied,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Tes E2E memakai DUA database in-memory sekaligus (HP lama + HP
  // baru), masing-masing dengan executor sendiri — peringatan drift
  // tentang database ganda tidak berlaku di sini.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final List<LarasDatabase> dbs = <LarasDatabase>[];
  late Directory tempDir;

  /// Database in-memory baru + service-nya; database ditutup otomatis
  /// di tearDown.
  (LarasDatabase, LibraryService) freshLibrary() {
    final (LarasDatabase, LibraryService) pair = createTestLibrary();
    dbs.add(pair.$1);
    return pair;
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('laras-p8-test');
  });

  tearDown(() async {
    for (final LarasDatabase db in dbs) {
      await db.close();
    }
    dbs.clear();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
    'E2E: ekspor -> database baru -> impor -> library + playlist pulih utuh',
    () async {
      final (_, LibraryService lib1) = freshLibrary();
      await seedRichLibrary(lib1);
      final BackupService service1 = await makeService(
        lib1,
        prefsValues: <String, Object>{
          'laras.data_saver': true,
          'laras.default_download_quality': 'balanced',
          'laras.wifi_only_downloads': true,
          'laras.cache_limit_bytes': 1073741824,
        },
        tempDir: tempDir,
      );
      final BackupData exported = await service1.buildBackupData();
      final Uint8List bytes = Uint8List.fromList(
        utf8.encode(exported.encode()),
      );

      // "HP baru": database + preferensi kosong.
      final (_, LibraryService lib2) = freshLibrary();
      final BackupService service2 = await makeService(
        lib2,
        tempDir: tempDir,
      );
      final BackupData preview = service2.previewImport(bytes);
      expect(preview.songs.length, 3);
      expect(preview.playlists.length, 1);
      final ImportReport report = await service2.importBackup(
        preview,
        applySettings: true,
      );
      expect(report.failed, 0);
      expect(report.alreadyExisted, 0);
      // 3 lagu + 1 playlist + 2 lagu playlist + 1 event + 2 query +
      // 2 antrean = 11 item baru.
      expect(report.succeeded, 11);
      expect(report.downloadedSongIds, <String>['vid-1']);

      final BackupSnapshot snap = await lib2.backupSnapshot();
      expect(
        snap.songs.map((SongView v) => v.song.id).toSet(),
        <String>{'vid-1', 'vid-2', 'vid-3'},
      );
      final Song song1 = snap.songs
          .firstWhere((SongView v) => v.song.id == 'vid-1')
          .song;
      expect(song1.liked, isTrue);
      expect(song1.totalPlayTimeMs, greaterThanOrEqualTo(120000));
      // File audio tidak ikut: status unduhan kembali 0 (B7.4).
      expect(song1.downloadState, DownloadState.notDownloaded);
      expect(snap.playlists.length, 1);
      expect(snap.playlists[0].$1.name, 'Favoritku');
      expect(snap.playlists[0].$1.description, 'Lagu-lagu pilihan');
      expect(snap.playlists[0].$2, <String>['vid-1', 'vid-2']);
      expect(snap.playEvents.length, 1);
      expect(snap.playEvents[0].playTimeMs, 120000);
      expect(
        snap.searchHistory.map((SearchHistoryData q) => q.query).toSet(),
        <String>{'noah', 'peterpan'},
      );
      expect(
        snap.queueItems.map((QueueItem q) => q.songId).toList(),
        <String>['vid-1', 'vid-2'],
      );
      expect(snap.queueItems[0].source, 'library');
      expect(snap.playbackState!.currentIndex, 1);
      expect(snap.playbackState!.positionMs, 45000);
      expect(snap.playbackState!.shuffleEnabled, isTrue);
      expect(snap.playbackState!.repeatMode, 1);

      // Pengaturan dari file diterapkan (B10.3).
      expect(service2.settings.dataSaver.value, isTrue);
      expect(service2.settings.defaultQuality.value, 'balanced');
      expect(service2.settings.wifiOnly.value, isTrue);
      expect(service2.settings.cacheLimitBytes.value, 1073741824);
    },
  );

  test('impor dua kali: kedua kalinya semua sudah ada, tidak ada duplikat',
      () async {
    final (_, LibraryService lib1) = freshLibrary();
    await seedRichLibrary(lib1);
    final BackupService service1 = await makeService(lib1);
    final Uint8List bytes = Uint8List.fromList(
      utf8.encode((await service1.buildBackupData()).encode()),
    );
    final (_, LibraryService lib2) = freshLibrary();
    final BackupService service2 = await makeService(lib2);
    await service2.importBackup(
      service2.previewImport(bytes),
      applySettings: false,
    );
    final ImportReport second = await service2.importBackup(
      service2.previewImport(bytes),
      applySettings: false,
    );
    expect(second.succeeded, 0);
    expect(second.failed, 0);
    expect(second.alreadyExisted, greaterThan(0));
    final BackupSnapshot snap = await lib2.backupSnapshot();
    expect(snap.songs.length, 3);
    expect(snap.playlists.length, 1);
    expect(snap.playEvents.length, 1);
    expect(snap.queueItems.length, 2);
  });

  test('merge playlist nama sama: lagu ditambah ke playlist yang sama '
      '(B4.8, tanpa salinan)', () async {
    final (_, LibraryService lib1) = freshLibrary();
    await seedRichLibrary(lib1);
    final BackupService service1 = await makeService(lib1);
    final Uint8List bytes = Uint8List.fromList(
      utf8.encode((await service1.buildBackupData()).encode()),
    );
    // HP tujuan sudah punya playlist "Favoritku" berisi vid-3.
    final (_, LibraryService lib2) = freshLibrary();
    await lib2.importSongs(<SongImport>[
      SongImport(
        song: SongsCompanion(
          id: const Value<String>('vid-3'),
          title: const Value<String>('Lagu Tiga'),
        ),
      ),
    ]);
    final int existingId = await lib2.createPlaylist('Favoritku');
    await lib2.addSongToPlaylist(existingId, 'vid-3');
    final BackupService service2 = await makeService(lib2);
    final ImportReport report = await service2.importBackup(
      service2.previewImport(bytes),
      applySettings: false,
    );
    expect(report.failed, 0);
    final BackupSnapshot snap = await lib2.backupSnapshot();
    expect(snap.playlists.length, 1);
    expect(snap.playlists[0].$1.name, 'Favoritku');
    expect(
      snap.playlists[0].$2.toSet(),
      <String>{'vid-1', 'vid-2', 'vid-3'},
    );
  });

  test('merge antrean: antrean backup di belakang antrean yang ada', () async {
    final (_, LibraryService lib1) = freshLibrary();
    await seedRichLibrary(lib1);
    final BackupService service1 = await makeService(lib1);
    final Uint8List bytes = Uint8List.fromList(
      utf8.encode((await service1.buildBackupData()).encode()),
    );
    final (_, LibraryService lib2) = freshLibrary();
    await lib2.importSongs(<SongImport>[
      SongImport(
        song: SongsCompanion(
          id: const Value<String>('vid-x'),
          title: const Value<String>('Lagu X'),
        ),
      ),
    ]);
    await lib2.replaceQueue(<QueueItemsCompanion>[
      QueueItemsCompanion.insert(
        position: const Value<int>(0),
        songId: 'vid-x',
      ),
    ]);
    await lib2.savePlaybackState(
      currentIndex: 0,
      positionMs: 1000,
      shuffleEnabled: false,
      repeatMode: 0,
    );
    final BackupService service2 = await makeService(lib2);
    await service2.importBackup(
      service2.previewImport(bytes),
      applySettings: false,
    );
    final BackupSnapshot snap = await lib2.backupSnapshot();
    expect(
      snap.queueItems.map((QueueItem q) => q.songId).toList(),
      <String>['vid-x', 'vid-1', 'vid-2'],
    );
    // Posisi pemutar TIDAK ditimpa: antrean tujuan tidak kosong.
    expect(snap.playbackState!.positionMs, 1000);
    expect(snap.playbackState!.currentIndex, 0);
  });

  test('pengaturan opsional: applySettings=false mempertahankan yang ada',
      () async {
    final (_, LibraryService lib1) = freshLibrary();
    await seedRichLibrary(lib1);
    final BackupService service1 = await makeService(
      lib1,
      prefsValues: <String, Object>{'laras.data_saver': true},
    );
    final Uint8List bytes = Uint8List.fromList(
      utf8.encode((await service1.buildBackupData()).encode()),
    );
    final (_, LibraryService lib2) = freshLibrary();
    bool applied = false;
    final BackupService service2 = await makeService(
      lib2,
      onSettingsApplied: (_) => applied = true,
    );
    expect(service2.settings.dataSaver.value, isFalse);
    await service2.importBackup(
      service2.previewImport(bytes),
      applySettings: false,
    );
    expect(service2.settings.dataSaver.value, isFalse);
    expect(applied, isFalse);
  });

  test('atomic: impor gagal di tengah -> database tidak berubah sama sekali',
      () async {
    final (_, LibraryService lib1) = freshLibrary();
    await seedRichLibrary(lib1);
    // File dibuat langsung (melewati validasi parse): playlist merujuk
    // lagu yang tidak ada -> insert playlistSongs melanggar FK dan
    // transaksi batal total.
    final BackupData broken = BackupData(
      version: kCurrentBackupVersion,
      appVersion: '0.9.0',
      exportedAt: DateTime.utc(2026, 11, 17),
      songs: const <BackupSong>[
        BackupSong(id: 'vid-baru', title: 'Lagu Baru'),
      ],
      playlists: const <BackupPlaylist>[
        BackupPlaylist(name: 'Rusak', songIds: <String>['vid-hilang']),
      ],
    );
    final BackupService service = await makeService(lib1);
    final BackupSnapshot before = await lib1.backupSnapshot();
    await expectLater(
      service.importBackup(broken, applySettings: false),
      throwsA(anything),
    );
    final BackupSnapshot after = await lib1.backupSnapshot();
    expect(after.songs.length, before.songs.length);
    expect(
      after.songs.map((SongView v) => v.song.id),
      isNot(contains('vid-baru')),
    );
    expect(after.playlists.length, before.playlists.length);
    expect(
      after.playlists.map(((Playlist, List<String>) e) => e.$1.name),
      isNot(contains('Rusak')),
    );
  });

  test('antrean tujuan hampir penuh: kelebihan masuk laporan gagal', () async {
    final (_, LibraryService lib1) = freshLibrary();
    await seedRichLibrary(lib1);
    final BackupService service1 = await makeService(lib1);
    final Uint8List bytes = Uint8List.fromList(
      utf8.encode((await service1.buildBackupData()).encode()),
    );
    final (_, LibraryService lib2) = freshLibrary();
    // Isi antrean tujuan dengan 199 lagu lain.
    final List<SongImport> filler = <SongImport>[];
    final List<QueueItemsCompanion> fillerQueue = <QueueItemsCompanion>[];
    for (int i = 0; i < 199; i++) {
      final String id = 'fill-$i';
      filler.add(
        SongImport(
          song: SongsCompanion(
            id: Value<String>(id),
            title: Value<String>('Isi $i'),
          ),
        ),
      );
      fillerQueue.add(
        QueueItemsCompanion.insert(
          position: Value<int>(i),
          songId: id,
        ),
      );
    }
    await lib2.importSongs(filler);
    await lib2.replaceQueue(fillerQueue);
    final BackupService service2 = await makeService(lib2);
    final ImportReport report = await service2.importBackup(
      service2.previewImport(bytes),
      applySettings: false,
    );
    // 1 slot tersisa: vid-1 masuk, vid-2 gagal (antrean penuh).
    expect(report.failed, 1);
    expect(report.failures[0].reason, ImportFailureReason.queueFull);
    expect(report.failures[0].label, contains('Lagu Dua'));
    final List<QueueItem> queue = await lib2.loadQueue();
    expect(queue.length, 200);
    expect(queue.last.songId, 'vid-1');
  });

  test('previewImport menolak file versi lebih baru dan file >10 MB',
      () async {
    final (_, LibraryService lib2) = freshLibrary();
    final BackupService service = await makeService(lib2);
    expect(
      () => service.previewImport(
        Uint8List.fromList(
          utf8.encode('{"backupVersion":99,"appVersion":"9.9.9"}'),
        ),
      ),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.newerVersion,
        ),
      ),
    );
    expect(
      () => service.previewImport(Uint8List(kMaxBackupBytes + 1)),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.tooLarge,
        ),
      ),
    );
  });

  test('exportAndShare: file ditulis ke temp, dibagikan, lalu dihapus',
      () async {
    final (_, LibraryService lib1) = freshLibrary();
    await seedRichLibrary(lib1);
    String? sharedPath;
    String? sharedName;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kChannel, (
          MethodCall call,
        ) async {
          expect(call.method, 'shareFile');
          final Map<dynamic, dynamic> args =
              call.arguments as Map<dynamic, dynamic>;
          sharedPath = args['path'] as String?;
          sharedName = args['fileName'] as String?;
          // File wajib ada saat share dipanggil, dan isinya JSON valid.
          final String content = File(sharedPath!).readAsStringSync();
          final BackupData parsed = BackupData.parseText(content);
          expect(parsed.songs.length, 3);
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_kChannel, null);
    });
    final BackupService service = await makeService(
      lib1,
      tempDir: tempDir,
    );
    final BackupExportOutcome outcome = await service.exportAndShare();
    expect(outcome, BackupExportOutcome.shared);
    expect(sharedName, matches(RegExp(r'^backup-musik-\d{8}-\d{6}\.json$')));
    // File sementara dihapus sesudah dibagikan.
    expect(File(sharedPath!).existsSync(), isFalse);
  });

  test('exportAndShare: share gagal -> outcome failed', () async {
    final (_, LibraryService lib1) = freshLibrary();
    await seedRichLibrary(lib1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kChannel, (
          MethodCall call,
        ) async {
          return false;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_kChannel, null);
    });
    final BackupService service = await makeService(
      lib1,
      tempDir: tempDir,
    );
    expect(
      await service.exportAndShare(),
      BackupExportOutcome.failed,
    );
  });
}
