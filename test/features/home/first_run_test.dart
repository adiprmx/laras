/// Tes widget orkestrasi first-run (Rombak UI-2): urutan onboarding ->
/// lembar kejujuran -> beranda di HomeShell, sekali tampil, dan tidak
/// tampil lagi setelah flag ditandai.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/features/home/home_screen.dart';
import 'package:laras/features/onboarding/onboarding_flow.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/main.dart';
import 'package:laras/player/player.dart';
import 'package:laras/resilience/honesty_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppLocalizations stringsOf(WidgetTester tester) {
    return AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
  }

  Future<void> pumpFresh(
    WidgetTester tester, {
    bool onboardingShown = false,
    bool honestyShown = false,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      if (onboardingShown) kOnboardingShownKey: true,
      if (honestyShown) kHonestySheetShownKey: true,
    });
    await tester.pumpWidget(const LarasApp());
    await tester.pumpAndSettle();
  }

  testWidgets('pengguna baru: onboarding -> lembar kejujuran -> beranda',
      (WidgetTester tester) async {
    // Viewport 360x640: urutan first-run lengkap tanpa overflow.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFresh(tester);
    final AppLocalizations strings = stringsOf(tester);

    // Langkah 1: pengenalan tampil duluan, beranda tertutup.
    expect(find.text(strings.onboardingTitle1), findsOneWidget);
    expect(find.text(strings.honestyTitle), findsNothing);

    // Lewati pengenalan -> langkah 2: lembar kejujuran.
    await tester.tap(find.text(strings.skip));
    await tester.pumpAndSettle();
    expect(find.text(strings.onboardingTitle1), findsNothing);
    expect(find.text(strings.honestyTitle), findsOneWidget);

    // Tutup lembar -> langkah 3: beranda dengan 5 lagu langsung terlihat.
    await tester.tap(find.text(strings.understood));
    await tester.pumpAndSettle();
    expect(find.text(strings.honestyTitle), findsNothing);
    expect(find.text(strings.homeSongsTitle), findsOneWidget);
    for (final Track track in homeTracks) {
      expect(find.text(track.title), findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    // Kedua flag ditandai: urutan tidak terulang.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kOnboardingShownKey), isTrue);
    expect(prefs.getBool(kHonestySheetShownKey), isTrue);
  });

  testWidgets('pengenalan selesai (bukan lewati) juga lanjut ke lembar',
      (WidgetTester tester) async {
    await pumpFresh(tester);
    final AppLocalizations strings = stringsOf(tester);

    await tester.tap(find.text(strings.onboardingNext));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.onboardingNext));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.onboardingNext));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.onboardingStart));
    await tester.pumpAndSettle();

    expect(find.text(strings.honestyTitle), findsOneWidget);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kOnboardingShownKey), isTrue);
  });

  testWidgets('kedua flag sudah true: langsung beranda, tanpa interupsi',
      (WidgetTester tester) async {
    await pumpFresh(tester, onboardingShown: true, honestyShown: true);
    final AppLocalizations strings = stringsOf(tester);

    expect(find.text(strings.onboardingTitle1), findsNothing);
    expect(find.text(strings.honestyTitle), findsNothing);
    expect(find.text(strings.homeSongsTitle), findsOneWidget);
    for (final Track track in homeTracks) {
      expect(find.text(track.title), findsOneWidget);
    }
  });

  testWidgets('pengenalan sudah, lembar belum: hanya lembar yang tampil',
      (WidgetTester tester) async {
    await pumpFresh(tester, onboardingShown: true);
    final AppLocalizations strings = stringsOf(tester);

    expect(find.text(strings.onboardingTitle1), findsNothing);
    expect(find.text(strings.honestyTitle), findsOneWidget);
    await tester.tap(find.text(strings.understood));
    await tester.pumpAndSettle();
    expect(find.text(strings.homeSongsTitle), findsOneWidget);
  });

  testWidgets('lembar sudah, pengenalan belum: hanya pengenalan tampil',
      (WidgetTester tester) async {
    await pumpFresh(tester, honestyShown: true);
    final AppLocalizations strings = stringsOf(tester);

    expect(find.text(strings.onboardingTitle1), findsOneWidget);
    await tester.tap(find.text(strings.skip));
    await tester.pumpAndSettle();
    expect(find.text(strings.honestyTitle), findsNothing);
    expect(find.text(strings.homeSongsTitle), findsOneWidget);
  });
}
