/// Tes widget layar Pengaturan nyata (P6, tugas 7 + 8): 4 kelompok,
/// saklar, dialog kualitas/batas, alur hapus data.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/features/settings/about_screen.dart';
import 'package:laras/features/settings/faq_screen.dart';
import 'package:laras/features/settings/service_status_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/resilience/resilience.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/test_database.dart';
import '../../resilience/p6_widget_helpers.dart';

class _FakeUrlSource implements DownloadUrlSource {
  @override
  Future<DownloadUrl> resolve(String videoId, DownloadQuality quality) =>
      throw UnimplementedError('tidak dipakai di tes Pengaturan');
}

class _FakeFreeSpace implements FreeSpaceProvider {
  @override
  Future<int?> freeBytes(String path) async => 10 * 1024 * 1024 * 1024;
}

void main() {
  late Directory temp;
  late LarasDatabase db;
  late LibraryService library;
  late SharedPreferences prefs;
  late AppSettings settings;
  late ServiceStatusService serviceStatus;
  late DownloadService downloads;
  late StreamCacheService streamCache;
  late DataWipeService wipe;

  /// Isi clipboard tiruan (mock channel platform, lihat setUp).
  String? clipboardText;

  /// Mock channel platform + channel external.
  ///
  /// Cacat harness (bukan kode produksi): pemanggilan MethodChannel
  /// TANPA mock di `flutter test` tidak pernah dibalas engine —
  /// future-nya menggantung selamanya. Tanpa mock ini, `deviceInfo()` /
  /// `openMail()` (channel external) dan `Clipboard.setData` (channel
  /// platform) membuat alur "Laporkan kerusakan" macet sebelum
  /// snackbar tampil, dan kedua tes laporan gagal deterministik.
  /// Di HP nyata kedua channel dijawab (MainActivity + engine).
  void installChannelMocks() {
    final TestDefaultBinaryMessengerBinding binding =
        TestDefaultBinaryMessengerBinding.instance;
    clipboardText = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        switch (call.method) {
          case 'Clipboard.getData':
            return clipboardText == null
                ? null
                : <String, Object?>{'text': clipboardText};
          case 'Clipboard.setData':
            final Map<dynamic, dynamic> args =
                call.arguments as Map<dynamic, dynamic>;
            clipboardText = args['text'] as String?;
            return null;
          default:
            return null;
        }
      },
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('id.my.adipmusic.laras/external'),
      (MethodCall call) async {
        switch (call.method) {
          case 'deviceInfo':
            return <String, String>{
              'model': 'Pixel Tes',
              'androidVersion': '14',
            };
          case 'openMail':
            return false; // tidak ada aplikasi email di tes
          default:
            return null;
        }
      },
    );
  }

  void clearChannelMocks() {
    final TestDefaultBinaryMessengerBinding binding =
        TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('id.my.adipmusic.laras/external'),
      null,
    );
  }

  setUp(() async {
    installChannelMocks();
    temp = await Directory.systemTemp.createTemp('laras_p6_settings_test');
    final Directory dlDir = Directory('${temp.path}/downloads')..createSync();
    final Directory cacheDir = Directory('${temp.path}/cache')..createSync();
    final DownloadPaths paths = DownloadPaths(
      downloadsDir: dlDir,
      cacheDir: cacheDir,
    );
    (db, library) = createTestLibrary();
    prefs = await seedP6Prefs(status: 'ok');
    settings = AppSettings.forTest(prefs);
    serviceStatus = makeServiceStatus(prefs);
    downloads = DownloadService(
      library: library,
      paths: paths,
      urlSource: _FakeUrlSource(),
      freeSpace: _FakeFreeSpace(),
    );
    // Baris "Ruang untuk lagu yang pernah diputar" hanya tampil bila
    // ada layanan cache (tanpa itu baris disembunyikan, bukan mati).
    streamCache = StreamCacheService(library: library, paths: paths);
    wipe = DataWipeService(
      prefs: prefs,
      documentsDir: temp,
      tempDir: Directory('${temp.path}/tmp')..createSync(),
      databaseFileName: 'laras.sqlite',
      downloadsDir: dlDir,
      cacheDir: cacheDir,
    );
  });

  tearDown(() async {
    await downloads.dispose();
    await streamCache.dispose();
    await db.close();
    clearChannelMocks();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<AppLocalizations> pumpSettings(WidgetTester tester) async {
    setPhoneViewport(tester);
    await pumpP6App(
      tester,
      settings: settings,
      serviceStatus: serviceStatus,
      downloadService: downloads,
      streamCache: streamCache,
      dataWipe: wipe,
      externalLinks: ExternalLinks(),
      libraryService: library,
    );
    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    // Ikon gerigi Pengaturan ada di tab Library (bukan Beranda).
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(strings.tabLibrary),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(Scaffold).last),
    )!;
  }

  Future<void> closePump(WidgetTester tester) async {
    // Pelajaran P3: tutup pump widget yang memakai watch* supaya tidak
    // ada Timer drift yang menggantung sesudah tes (dispose akhir
    // framework menjadwalkan Timer.run yang tidak sempat jalan).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('4 kelompok tampil lengkap', (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    expect(find.text(strings.playbackSettings), findsOneWidget);
    expect(find.text(strings.downloadStorageSettings), findsOneWidget);
    expect(find.text(strings.settingsServiceGroup), findsOneWidget);
    expect(find.text(strings.settingsAppGroup), findsOneWidget);
    expect(find.text(strings.qualityDataSaver), findsOneWidget);
    expect(find.text(strings.downloadQuality), findsOneWidget);
    expect(find.text(strings.playedSongsSpace), findsOneWidget);
    expect(find.text(strings.wifiOnlyDownloads), findsOneWidget);
    expect(find.text(strings.manageStorage), findsOneWidget);
    expect(find.text(strings.serviceStatus), findsOneWidget);
    expect(find.text(strings.checkForUpdates), findsOneWidget);
    expect(find.text(strings.aboutLicenses), findsOneWidget);
    expect(find.text(strings.faqTitle), findsOneWidget);
    expect(find.text(strings.showOnboardingAgain), findsOneWidget);
    expect(find.text(strings.reportProblem), findsOneWidget);
    expect(find.text(strings.wipeData), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('"Lihat pengenalan lagi" membuka alur pengenalan sungguhan',
      (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    // Implementasi sungguhan (Tim Rombak UI-2): ketuk membuka halaman
    // pengenalan; Lewati menutupnya kembali ke Pengaturan.
    await tester.tap(find.text(strings.showOnboardingAgain));
    await tester.pumpAndSettle();
    expect(find.text(strings.onboardingTitle1), findsOneWidget);
    await tester.tap(find.text(strings.skip));
    await tester.pumpAndSettle();
    expect(find.text(strings.settings), findsOneWidget);
    expect(find.text(strings.onboardingTitle1), findsNothing);
    await closePump(tester);
  });

  testWidgets('saklar Hemat data mengubah pengaturan + tersimpan',
      (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    expect(settings.dataSaver.value, isFalse);
    await tester.tap(find.text(strings.qualityDataSaver));
    await tester.pumpAndSettle();
    expect(settings.dataSaver.value, isTrue);
    expect(prefs.getBool('laras.data_saver'), isTrue);
    await closePump(tester);
  });

  testWidgets('dialog kualitas unduhan: pilih Hemat data tersimpan',
      (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    await tester.tap(find.text(strings.downloadQuality));
    await tester.pumpAndSettle();
    // Dialog menampilkan 3 opsi. Cari di dalam dialog: subtitle baris
    // ikut menampilkan label kualitas saat ini ("Terbaik").
    final Finder dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text(strings.qualityBest)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.text(strings.qualityBalanced),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.text(strings.qualityDataSaver),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.text(strings.qualityDataSaver),
      ),
    );
    await tester.pumpAndSettle();
    expect(settings.defaultQuality.value, kQualityDataSaver);
    expect(prefs.getString('laras.default_download_quality'), 'data_saver');
    await closePump(tester);
  });

  testWidgets('dialog batas ruang: pilih 1 GB tersimpan',
      (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    await tester.tap(find.text(strings.playedSongsSpace));
    await tester.pumpAndSettle();
    // Opsi memakai formatBytes (satu desimal: "250,0 MB"). Cari di
    // dalam dialog: subtitle baris ikut menampilkan batas saat ini.
    final Finder dialog = find.byType(AlertDialog);
    for (final int bytes in kCacheLimitOptions) {
      expect(
        find.descendant(of: dialog, matching: find.text(formatBytes(bytes))),
        findsOneWidget,
      );
    }
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.text(formatBytes(1024 * 1024 * 1024)),
      ),
    );
    await tester.pumpAndSettle();
    expect(settings.cacheLimitBytes.value, 1024 * 1024 * 1024);
    await closePump(tester);
  });

  testWidgets('saklar WiFi saja mengubah pengaturan',
      (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    await tester.tap(find.text(strings.wifiOnlyDownloads));
    await tester.pumpAndSettle();
    expect(settings.wifiOnly.value, isTrue);
    expect(prefs.getBool('laras.wifi_only_downloads'), isTrue);
    await closePump(tester);
  });

  testWidgets('baris status layanan membuka layar status',
      (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    await tester.tap(find.text(strings.serviceStatus));
    await tester.pumpAndSettle();
    expect(find.byType(ServiceStatusScreen), findsOneWidget);
    expect(find.text(strings.serviceNormal), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('Tentang membuka layar Tentang + versi',
      (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    await tester.tap(find.text(strings.aboutLicenses));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.textContaining('0.9.0'), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('FAQ membuka layar FAQ 12 pertanyaan',
      (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    await tester.tap(find.text(strings.faqTitle));
    await tester.pumpAndSettle();
    expect(find.byType(FaqScreen), findsOneWidget);
    expect(find.text(strings.faq1q), findsOneWidget);
    expect(find.text(strings.faq12q), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('Laporkan kerusakan: dialog kode tampil, salin bekerja',
      (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    await tester.tap(find.text(strings.reportProblem));
    await tester.pumpAndSettle();
    // Dialog: isi + label + kode + tombol salin + tombol email.
    expect(find.text(strings.reportDialogBody), findsOneWidget);
    expect(find.text(strings.diagnosticCodeLabel), findsOneWidget);
    expect(find.text(strings.copyCode), findsOneWidget);
    expect(find.text(strings.sendViaEmail), findsOneWidget);
    // Tanpa player error tercatat: kode X/XX, config bawaan (B),
    // layanan ok (O) sesuai seed.
    final SelectableText codeWidget = tester.widget(
      find.byType(SelectableText),
    );
    expect(
      codeWidget.data,
      matches(RegExp(r'^LRS1-XXX-\d{8}-X-0901-B-O$')),
    );
    await tester.tap(find.text(strings.copyCode));
    // onPressed async (clipboard lalu snackbar): satu pump tidak cukup,
    // perlu settle penuh.
    await tester.pumpAndSettle();
    expect(find.text(strings.codeCopied), findsOneWidget);
    final ClipboardData? clip = await Clipboard.getData('text/plain');
    expect(clip?.text, codeWidget.data);
    await closePump(tester);
  });

  testWidgets('Laporkan kerusakan: Batal menutup dialog tanpa aksi',
      (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    await tester.tap(find.text(strings.reportProblem));
    await tester.pumpAndSettle();
    expect(find.text(strings.reportDialogBody), findsOneWidget);
    await tester.tap(find.text(strings.cancel));
    await tester.pumpAndSettle();
    expect(find.text(strings.reportDialogBody), findsNothing);
    expect(find.text(strings.reportProblemNoMail), findsNothing);
    await closePump(tester);
  });

  testWidgets('Laporkan kerusakan tanpa aplikasi email -> alamat disalin + '
      'snackbar', (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    await tester.tap(find.text(strings.reportProblem));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.sendViaEmail));
    await tester.pumpAndSettle();
    // Dialog harus sudah tertutup (pop -> lanjut ke email).
    expect(find.text(strings.reportDialogBody), findsNothing);
    // Rantai async sesudah pop (info HP -> buka email -> salin alamat
    // -> snackbar) butuh pump ekstra walau sudah settle.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(strings.reportProblemNoMail), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('hapus data: batal di dialog pertama tidak menghapus',
      (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    await settings.setDataSaver(true);
    await tester.tap(find.text(strings.wipeData));
    await tester.pumpAndSettle();
    expect(find.text(strings.wipeDataTitle1), findsOneWidget);
    await tester.tap(find.text(strings.cancel));
    await tester.pumpAndSettle();
    expect(prefs.getBool('laras.data_saver'), isTrue);
    await closePump(tester);
  });

  testWidgets('hapus data: dua konfirmasi -> data terhapus + layar selesai',
      (WidgetTester tester) async {
    final AppLocalizations strings = await pumpSettings(tester);
    await settings.setDataSaver(true);
    File('${temp.path}/laras.sqlite').writeAsStringSync('db-palsu');
    await tester.tap(find.text(strings.wipeData));
    await tester.pumpAndSettle();
    // Tombol dialog 1 ("Hapus semua data") adalah kemunculan terakhir —
    // baris Pengaturan di belakang dialog masih ada di tree.
    await tester.tap(find.text(strings.wipeData).last);
    await tester.pumpAndSettle();
    expect(find.text(strings.wipeDataTitle2), findsOneWidget);
    await tester.tap(find.text(strings.wipeDataConfirm));
    await tester.pumpAndSettle();
    expect(find.text(strings.wipeDataDone), findsOneWidget);
    expect(prefs.getBool('laras.data_saver'), isNull);
    expect(File('${temp.path}/laras.sqlite').existsSync(), isFalse);
    await closePump(tester);
  });
}
