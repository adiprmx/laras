/// Helper bersama tes widget P6: prefs tiruan + layanan ketahanan +
/// pemompa LarasApp.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/extractor/canary.dart';
import 'package:laras/extractor/remote_config.dart';
import 'package:laras/features/backup/backup.dart';
import 'package:laras/features/search/search_service.dart';
import 'package:laras/main.dart';
import 'package:laras/player/player.dart';
import 'package:laras/resilience/resilience.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../player/fakes.dart';

/// Viewport HP 390x1600 (sama seperti home_screen_test.dart).
void setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 4800);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Siapkan prefs tiruan. [status] = 'ok' | 'degraded' | 'broken' (null =
/// belum pernah diperiksa).
///
/// Flag first-run (`onboarding_shown_v1`, `honesty_sheet_shown_v1`)
/// selalu true di sini supaya orkestrasi first-run Tim Rombak UI-2
/// (onboarding -> lembar kejujuran) tidak menutupi layar pada tes yang
/// memompa LarasApp. Tes lembar kejujuran sendiri memakai scaffold
/// kecilnya, bukan LarasApp.
Future<SharedPreferences> seedP6Prefs({String? status}) async {
  final Map<String, Object> values = <String, Object>{
    'onboarding_shown_v1': true,
    'honesty_sheet_shown_v1': true,
  };
  if (status != null) {
    values['laras.service_status'] = status;
    values['laras.service_checked_at_ms'] =
        DateTime.now().millisecondsSinceEpoch;
  }
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// ServiceStatusService dengan kanari palsu (resolve selalu sukses)
/// + loader config nyata (tanpa jaringan yang dipanggil di tes widget).
ServiceStatusService makeServiceStatus(SharedPreferences prefs) {
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

/// Pompa LarasApp lengkap dengan layanan P6.
Future<void> pumpP6App(
  WidgetTester tester, {
  AppSettings? settings,
  ServiceStatusService? serviceStatus,
  DataWipeService? dataWipe,
  ExternalLinks? externalLinks,
  LibraryService? libraryService,
  SearchService? searchService,
  DownloadService? downloadService,
  StreamCacheService? streamCache,
  BackupService? backupService,
  SpotifyImportService? spotifyImportService,
}) async {
  final FakeAudioPlayerPort port = FakeAudioPlayerPort();
  addTearDown(port.dispose);
  final PlayerService playerService = PlayerService(
    port: port,
    resolver: FakeAudioResolver(),
    solver: FakeSignatureSolver(),
  );
  await tester.pumpWidget(
    LarasApp(
      playerService: playerService,
      libraryService: libraryService,
      searchService: searchService,
      downloadService: downloadService,
      streamCache: streamCache,
      settings: settings,
      serviceStatus: serviceStatus,
      dataWipe: dataWipe,
      externalLinks: externalLinks,
      backupService: backupService,
      spotifyImportService: spotifyImportService,
    ),
  );
  await tester.pumpAndSettle();
}
