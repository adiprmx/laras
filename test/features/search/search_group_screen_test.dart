/// Tes widget R2-L1 untuk SearchGroupScreen: future yang error
/// menampilkan pesan + tombol coba lagi, bukan shimmer selamanya.
/// Kedua builder (online dan lokal) diuji.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/search/search_group_screen.dart';
import 'package:laras/features/search/search_scope.dart';
import 'package:laras/features/search/search_service.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

import 'fake_online_api.dart';

const GroupedSearchResults _onlineResults = GroupedSearchResults(
  songs: <SearchSong>[
    SearchSong(videoId: 'on1', title: 'Noah Online', artist: 'Noah'),
  ],
);

/// Layanan yang search/searchLocalOnly-nya melempar StateError sampai
/// saklar dimatikan (R2-L1: mensimulasikan future yang error).
class _FlakyGroupService extends SearchService {
  _FlakyGroupService()
    : super(api: FakeOnlineApi(results: _onlineResults));

  bool throwSearch = true;
  bool throwLocal = true;

  @override
  Future<CombinedSearch> search(String query, {String? params}) async {
    if (throwSearch) throw StateError('database rusak (tes)');
    return super.search(query, params: params);
  }

  @override
  Future<LocalSearchResults> searchLocalOnly(
    String query, {
    int limit = kPageSize,
  }) async {
    if (throwLocal) throw StateError('database rusak (tes)');
    return const LocalSearchResults();
  }
}

void main() {
  Future<AppLocalizations> pumpGroup(
    WidgetTester tester, {
    required SearchGroup group,
    required SearchService service,
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
        home: SearchScope(
          service: service,
          child: SearchGroupScreen(
            title: 'Lagu',
            query: 'noah',
            group: group,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
  }

  testWidgets('R2-L1: future online yang error menampilkan pesan + coba '
      'lagi', (WidgetTester tester) async {
    final _FlakyGroupService service = _FlakyGroupService();
    final AppLocalizations strings = await pumpGroup(
      tester,
      group: SearchGroup.songs,
      service: service,
    );
    expect(find.text(strings.noResultsTitle), findsOneWidget);
    expect(find.text(strings.onlineResultsFailed), findsOneWidget);
    service.throwSearch = false;
    await tester.tap(find.text(strings.retry));
    await tester.pumpAndSettle();
    expect(find.text('Noah Online'), findsOneWidget);
  });

  testWidgets('R2-L1: future lokal yang error menampilkan pesan + coba '
      'lagi', (WidgetTester tester) async {
    final _FlakyGroupService service = _FlakyGroupService();
    final AppLocalizations strings = await pumpGroup(
      tester,
      group: SearchGroup.localSongs,
      service: service,
    );
    expect(find.text(strings.noResultsTitle), findsOneWidget);
    expect(find.text(strings.libraryFailed), findsOneWidget);
    service.throwLocal = false;
    await tester.tap(find.text(strings.retry));
    await tester.pumpAndSettle();
    // Sesudah pulih, daftar lokal kosong (tanpa library): pesan
    // "tidak ada hasil" untuk kueri itu.
    expect(find.text(strings.searchNoResults('noah')), findsOneWidget);
  });
}
