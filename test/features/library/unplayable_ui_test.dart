/// Tes widget tampilan lagu tidak bisa diputar (P6, B4.7): baris redup +
/// label, baris hapus massal + dialog konfirmasi + snackbar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

import '../../data/test_database.dart';
import '../../resilience/p6_widget_helpers.dart';

void main() {
  late LarasDatabase db;
  late LibraryService library;

  setUp(() async {
    (db, library) = createTestLibrary();
    // Lembar kejujuran tidak menutupi layar.
    await seedP6Prefs();
  });

  tearDown(() async {
    await db.close();
  });

  Future<AppLocalizations> pumpLibraryTab(WidgetTester tester) async {
    setPhoneViewport(tester);
    await pumpP6App(tester, libraryService: library);
    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(strings.tabLibrary),
      ),
    );
    await tester.pumpAndSettle();
    return strings;
  }

  Future<void> closePump(WidgetTester tester) async {
    // Pelajaran P3: tutup pump widget yang memakai watch* supaya
    // tidak ada Timer drift yang menggantung sesudah tes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('lagu bertanda tampil redup + label "Tidak bisa diputar"',
      (WidgetTester tester) async {
    await library.upsertSong(
      testSong('u1', title: 'Lagu Hilang Unik'),
      addToLibrary: true,
    );
    await library.upsertSong(
      testSong('u2', title: 'Lagu Sehat Unik'),
      addToLibrary: true,
    );
    await library.markUnplayable('u1');
    final AppLocalizations strings = await pumpLibraryTab(tester);
    expect(find.text('Lagu Hilang Unik'), findsOneWidget);
    expect(find.text('Lagu Sehat Unik'), findsOneWidget);
    // Label menempel di subtitle baris lagu bertanda.
    expect(find.textContaining(strings.cannotPlayLabel), findsOneWidget);
    // Baris bertanda dibungkus Opacity 0.55.
    final Finder opacity = find.ancestor(
      of: find.text('Lagu Hilang Unik'),
      matching: find.byType(Opacity),
    );
    expect(opacity, findsWidgets);
    final List<double> values = tester
        .widgetList<Opacity>(opacity)
        .map((Opacity w) => w.opacity)
        .toList();
    expect(values, contains(0.55));
    await closePump(tester);
  });

  testWidgets('tanpa lagu bertanda: baris hapus massal tidak tampil',
      (WidgetTester tester) async {
    await library.upsertSong(
      testSong('u1', title: 'Lagu Sehat Unik'),
      addToLibrary: true,
    );
    final AppLocalizations strings = await pumpLibraryTab(tester);
    expect(find.text(strings.deleteUnplayable), findsNothing);
    await closePump(tester);
  });

  testWidgets('hapus massal: dialog konfirmasi menyebut jumlah, hapus, '
      'snackbar tampil', (WidgetTester tester) async {
    await library.upsertSong(
      testSong('u1', title: 'Lagu Hilang Satu'),
      addToLibrary: true,
    );
    await library.upsertSong(
      testSong('u2', title: 'Lagu Hilang Dua'),
      addToLibrary: true,
    );
    await library.upsertSong(
      testSong('u3', title: 'Lagu Sehat Unik'),
      addToLibrary: true,
    );
    await library.markUnplayable('u1');
    await library.markUnplayable('u2');
    final AppLocalizations strings = await pumpLibraryTab(tester);
    expect(find.text(strings.deleteUnplayable), findsOneWidget);
    await tester.tap(find.text(strings.deleteUnplayable));
    await tester.pumpAndSettle();
    expect(find.text(strings.deleteUnplayableTitle), findsOneWidget);
    // Dialog menyebut jumlah (2 lagu).
    expect(find.textContaining('2'), findsWidgets);
    await tester.tap(find.text(strings.delete));
    await tester.pumpAndSettle();
    expect(find.text('Lagu Hilang Satu'), findsNothing);
    expect(find.text('Lagu Hilang Dua'), findsNothing);
    expect(find.text('Lagu Sehat Unik'), findsOneWidget);
    expect(find.text(strings.deleteUnplayableDone(2)), findsOneWidget);
    expect(find.text(strings.deleteUnplayable), findsNothing);
    await closePump(tester);
  });

  testWidgets('hapus massal: batal di dialog tidak menghapus',
      (WidgetTester tester) async {
    await library.upsertSong(
      testSong('u1', title: 'Lagu Hilang Unik'),
      addToLibrary: true,
    );
    await library.markUnplayable('u1');
    final AppLocalizations strings = await pumpLibraryTab(tester);
    await tester.tap(find.text(strings.deleteUnplayable));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.cancel));
    await tester.pumpAndSettle();
    expect(find.text('Lagu Hilang Unik'), findsOneWidget);
    expect(find.text(strings.deleteUnplayable), findsOneWidget);
    await closePump(tester);
  });
}
