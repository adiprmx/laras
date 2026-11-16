/// Tes widget lembar kejujuran satu kali (P6, B11.5) sebagai komponen
/// callable: orkestrasi first-run milik Tim Rombak UI-2; komponen ini
/// hanya menampilkan lembar + menandai flag `honesty_sheet_shown_v1`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/features/settings/faq_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/resilience/honesty_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Scaffold kecil dengan tombol yang memanggil showHonestySheet,
  /// meniru cara Tim Rombak UI-2 memanggilnya dari app shell.
  Future<void> pumpCaller(
    WidgetTester tester, {
    bool alreadyShown = false,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      if (alreadyShown) kHonestySheetShownKey: true,
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showHonestySheet(context),
                child: const Text('Tampilkan lembar'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppLocalizations stringsOf(WidgetTester tester) {
    return AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
  }

  testWidgets('lembar tampil saat dipanggil: judul + isi + tautan FAQ 1-2',
      (WidgetTester tester) async {
    await pumpCaller(tester);
    await tester.tap(find.text('Tampilkan lembar'));
    await tester.pumpAndSettle();
    final AppLocalizations strings = stringsOf(tester);
    expect(find.text(strings.honestyTitle), findsOneWidget);
    expect(find.text(strings.honestyBody), findsOneWidget);
    expect(find.text(strings.faq1q), findsOneWidget);
    expect(find.text(strings.faq2q), findsOneWidget);
    expect(find.text(strings.understood), findsOneWidget);
  });

  testWidgets('tombol Mengerti menutup + menandai flag shown',
      (WidgetTester tester) async {
    await pumpCaller(tester);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kHonestySheetShownKey), isNull);
    await tester.tap(find.text('Tampilkan lembar'));
    await tester.pumpAndSettle();
    final AppLocalizations strings = stringsOf(tester);
    await tester.tap(find.text(strings.understood));
    await tester.pumpAndSettle();
    expect(find.text(strings.honestyTitle), findsNothing);
    expect(prefs.getBool(kHonestySheetShownKey), isTrue);
    expect(await isHonestySheetShown(), isTrue);
  });

  testWidgets('ditutup dengan ketuk di luar lembar tetap menandai flag',
      (WidgetTester tester) async {
    await pumpCaller(tester);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.tap(find.text('Tampilkan lembar'));
    await tester.pumpAndSettle();
    final AppLocalizations strings = stringsOf(tester);
    expect(find.text(strings.honestyTitle), findsOneWidget);
    // Ketuk penghalang di atas lembar.
    await tester.tapAt(const Offset(200, 80));
    await tester.pumpAndSettle();
    expect(find.text(strings.honestyTitle), findsNothing);
    expect(prefs.getBool(kHonestySheetShownKey), isTrue);
  });

  testWidgets('pemanggilan kedua tidak menampilkan lagi (satu kali)',
      (WidgetTester tester) async {
    await pumpCaller(tester);
    final AppLocalizations strings = stringsOf(tester);
    await tester.tap(find.text('Tampilkan lembar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.understood));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tampilkan lembar'));
    await tester.pumpAndSettle();
    expect(find.text(strings.honestyTitle), findsNothing);
  });

  testWidgets('flag sudah true sejak awal: tidak tampil sama sekali',
      (WidgetTester tester) async {
    await pumpCaller(tester, alreadyShown: true);
    final AppLocalizations strings = stringsOf(tester);
    await tester.tap(find.text('Tampilkan lembar'));
    await tester.pumpAndSettle();
    expect(find.text(strings.honestyTitle), findsNothing);
  });

  testWidgets('tautan FAQ 1 membuka layar FAQ di pertanyaan 1',
      (WidgetTester tester) async {
    await pumpCaller(tester);
    await tester.tap(find.text('Tampilkan lembar'));
    await tester.pumpAndSettle();
    final AppLocalizations strings = stringsOf(tester);
    await tester.tap(find.text(strings.faq1q));
    await tester.pumpAndSettle();
    expect(find.byType(FaqScreen), findsOneWidget);
    expect(find.text(strings.faq1a), findsOneWidget);
  });
}
