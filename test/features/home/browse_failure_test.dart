/// Tes widget kegagalan Jelajah (P6, B6.5): gagal parse -> tombol
/// "Periksa pembaruan"; gagal HTTP -> tombol "Coba lagi"; seksi lokal
/// tidak terpengaruh.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/search/search_service.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/resilience/resilience.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/test_database.dart';
import '../../resilience/p6_widget_helpers.dart';
import '../search/fake_online_api.dart';
import 'home_screen_test.dart' show homeExplorePage;

void main() {
  Future<void> pumpBrowseFailure(
    WidgetTester tester, {
    required ExtractorException error,
    bool withServiceStatus = true,
  }) async {
    final (LarasDatabase db, LibraryService library) = createTestLibrary();
    addTearDown(db.close);
    final FakeOnlineApi api = FakeOnlineApi(
      browsePage: homeExplorePage,
      browseError: error,
    );
    final SearchService searchService = SearchService(api: api, library: library);
    final SharedPreferences prefs = await seedP6Prefs();
    final AppSettings settings = AppSettings.forTest(prefs);
    setPhoneViewport(tester);
    await pumpP6App(
      tester,
      settings: settings,
      serviceStatus:
          withServiceStatus ? makeServiceStatus(prefs) : null,
      libraryService: library,
      searchService: searchService,
    );
  }

  Future<void> closePump(WidgetTester tester) async {
    // Pelajaran P3: tutup pump widget yang memakai watch* supaya
    // tidak ada Timer drift yang menggantung sesudah tes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('gagal parse -> pesan YouTube berubah + "Periksa pembaruan"',
      (WidgetTester tester) async {
    await pumpBrowseFailure(tester, error: parseError);
    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.exploreFailedParse), findsOneWidget);
    expect(find.text(strings.checkForUpdates), findsOneWidget);
    expect(find.text(strings.retry), findsNothing);
    // Seksi lokal tetap tampil: 5 lagu beranda tidak hilang.
    expect(find.text(strings.homeSongsTitle), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('gagal HTTP -> pesan coba lagi nanti + "Coba lagi"',
      (WidgetTester tester) async {
    await pumpBrowseFailure(
      tester,
      error: const ExtractorException(
        ResolveFailureCause.emptyResponse,
        detail: 'server kosong (tes)',
      ),
    );
    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.exploreFailedHttp), findsOneWidget);
    expect(find.text(strings.retry), findsOneWidget);
    expect(find.text(strings.checkForUpdates), findsNothing);
    expect(find.text(strings.homeSongsTitle), findsOneWidget);
    await closePump(tester);
  });

  testWidgets('gagal parse tanpa layanan status -> jatuh ke "Coba lagi"',
      (WidgetTester tester) async {
    await pumpBrowseFailure(
      tester,
      error: parseError,
      withServiceStatus: false,
    );
    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.exploreFailedParse), findsOneWidget);
    expect(find.text(strings.retry), findsOneWidget);
    expect(find.text(strings.checkForUpdates), findsNothing);
    await closePump(tester);
  });
}
