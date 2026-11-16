/// Tes widget layar Salinan data (P8): render, ekspor lewat channel
/// tiruan, alur impor (pilih file -> dialog ringkasan -> pulihkan ->
/// laporan), dan entri impor Spotify.
library;

import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/features/backup/backup_file_channel.dart';
import 'package:laras/features/backup/backup_screen.dart';
import 'package:laras/features/backup/backup_service.dart';
import 'package:laras/features/backup/spotify_import.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/resilience/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/test_database.dart';
import '../search/fake_online_api.dart';
import 'backup_service_test.dart' show seedRichLibrary;

const MethodChannel _kChannel = MethodChannel(
  'id.my.adipmusic.laras/backup_files',
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LarasDatabase db;
  late LibraryService library;
  late BackupService backup;
  late Directory tempDir;
  late List<MethodCall> channelCalls;

  /// Isi yang dikembalikan pemilih file tiruan (null = batal).
  Map<String, Object?>? pickedFile;

  Future<void> pumpBackupScreen(
    WidgetTester tester, {
    SpotifyImportService? spotify,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[Locale('id')],
        home: BackupScreen(backup: backup, spotify: spotify),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    (db, library) = createTestLibrary();
    tempDir = Directory.systemTemp.createTempSync('laras-p8-widget');
    channelCalls = <MethodCall>[];
    pickedFile = null;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    backup = BackupService(
      library: library,
      settings: AppSettings.forTest(prefs),
      prefs: prefs,
      files: BackupFileChannel(),
      tempDirProvider: () async => tempDir,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kChannel, (MethodCall call) async {
          channelCalls.add(call);
          switch (call.method) {
            case 'shareFile':
              return true;
            case 'pickFile':
              return pickedFile;
            default:
              return null;
          }
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kChannel, null);
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('render: judul, penjelasan, tombol; library kosong -> catatan',
      (WidgetTester tester) async {
    await pumpBackupScreen(tester);
    expect(find.text('Salinan data'), findsOneWidget);
    expect(find.textContaining('File lagu yang sudah diunduh'), findsOneWidget);
    expect(find.text('Salin data ke file'), findsOneWidget);
    expect(find.text('Pulihkan dari file'), findsOneWidget);
    expect(find.textContaining('Belum ada data untuk disalin'), findsOneWidget);
    // Tanpa service Spotify, entri impor Spotify disembunyikan.
    expect(find.text('Bawa playlist dari Spotify'), findsNothing);
  });

  testWidgets('isi salinan saat ini: jumlah lagu + playlist tampil',
      (WidgetTester tester) async {
    await seedRichLibrary(library);
    await pumpBackupScreen(tester);
    expect(find.text('3 lagu'), findsOneWidget);
    expect(find.text('1 playlist'), findsOneWidget);
    expect(find.text('1 lagu favorit'), findsOneWidget);
    expect(find.text('2 lagu di antrean'), findsOneWidget);
    expect(find.text('1 lagu pernah diunduh'), findsOneWidget);
  });

  testWidgets('ekspor: ketuk tombol -> shareFile dipanggil + snackbar',
      (WidgetTester tester) async {
    await seedRichLibrary(library);
    await pumpBackupScreen(tester);
    await tester.tap(find.text('Salin data ke file'));
    await tester.pumpAndSettle();
    expect(
      channelCalls.where((MethodCall c) => c.method == 'shareFile').length,
      1,
    );
    expect(
      find.textContaining('File salinan siap dibagikan'),
      findsOneWidget,
    );
  });

  testWidgets('impor: pilih file -> dialog ringkasan -> pulihkan -> laporan',
      (WidgetTester tester) async {
    // Buat file salinan dari database lain (seolah dari HP lama).
    final (LarasDatabase dbOld, LibraryService libOld) = createTestLibrary();
    addTearDown(dbOld.close);
    await seedRichLibrary(libOld);
    final BackupData exported = await BackupService(
      library: libOld,
      settings: backup.settings,
      prefs: await SharedPreferences.getInstance(),
      files: BackupFileChannel(),
    ).buildBackupData();
    pickedFile = <String, Object?>{
      'bytes': Uint8List.fromList(utf8.encode(exported.encode())),
      'name': 'backup-musik-20261117-043805.json',
    };

    await pumpBackupScreen(tester);
    await tester.tap(find.text('Pulihkan dari file'));
    await tester.pumpAndSettle();
    // Dialog ringkasan (B10.3).
    expect(find.text('Pulihkan salinan ini?'), findsOneWidget);
    expect(find.text('3 lagu'), findsOneWidget);
    expect(find.text('1 playlist'), findsOneWidget);
    expect(
      find.text('Pulihkan juga pengaturan dari file ini'),
      findsOneWidget,
    );
    await tester.tap(find.text('Pulihkan'));
    await tester.pumpAndSettle();
    // Laporan hasil impor (B10.4).
    expect(find.text('Hasil impor'), findsOneWidget);
    expect(find.text('11 berhasil, 0 sudah ada, 0 gagal'), findsOneWidget);
    expect(find.text('Unduh ulang lagu yang dulu sudah diunduh'), findsOneWidget);
    // Data benar-benar masuk.
    final BackupSnapshot snap = await library.backupSnapshot();
    expect(snap.songs.length, 3);
    expect(snap.playlists.length, 1);
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Hasil impor'), findsNothing);
  });

  testWidgets('impor file rusak -> snackbar, tanpa dialog',
      (WidgetTester tester) async {
    pickedFile = <String, Object?>{
      'bytes': Uint8List.fromList(utf8.encode('{"bukan": "salinan"}')),
      'name': 'rusak.json',
    };
    await pumpBackupScreen(tester);
    await tester.tap(find.text('Pulihkan dari file'));
    await tester.pumpAndSettle();
    expect(find.text('Pulihkan salinan ini?'), findsNothing);
    expect(
      find.text('File ini bukan file salinan dari app ini. '
          'Pilih file salinan yang benar.'),
      findsOneWidget,
    );
  });

  testWidgets('entri Spotify tampil bila service ada; ketuk -> layar impor',
      (WidgetTester tester) async {
    final SpotifyImportService spotify = SpotifyImportService(
      library: library,
      api: FakeOnlineApi(),
    );
    await pumpBackupScreen(tester, spotify: spotify);
    expect(find.text('Bawa playlist dari Spotify'), findsOneWidget);
    await tester.tap(find.text('Bawa playlist dari Spotify'));
    await tester.pumpAndSettle();
    expect(find.text('Tempel daftar lagu'), findsOneWidget);
    expect(find.text('Pilih file daftar lagu'), findsOneWidget);
    // Bagian tautan ada di bawah lipatan: gulir dulu (ListView malas).
    // Drag dari widget yang terlihat (scrollUntilVisible tanpa argumen
    // scrollable gagal: ada 3 Scrollable — ListView + 2 TextField).
    await tester.drag(
      find.text('Pilih file daftar lagu'),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    expect(find.text('Baca dari tautan'), findsOneWidget);
  });
}
