/// Tes widget alur pengenalan (Rombak UI-2): 3 halaman dengan sampul
/// kanari nyata, tombol lewati, navigasi Lanjut, selesai di halaman
/// terakhir, dan tanpa overflow di viewport 360 dp + tablet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/core/widgets/album_cover.dart';
import 'package:laras/features/onboarding/onboarding_flow.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// App kecil dengan tombol yang memanggil OnboardingFlow.show,
  /// meniru pemanggilan dari Pengaturan ("Lihat pengenalan lagi").
  Future<void> pumpCaller(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => OnboardingFlow.show(context),
                child: const Text('Buka pengenalan'),
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

  Future<void> openOnboarding(WidgetTester tester) async {
    await tester.tap(find.text('Buka pengenalan'));
    await tester.pumpAndSettle();
  }

  void setViewport(WidgetTester tester, Size logical, double dpr) {
    tester.view.physicalSize =
        Size(logical.width * dpr, logical.height * dpr);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('halaman 1: sambutan + 4 sampul + Lewati + Lanjut',
      (WidgetTester tester) async {
    await pumpCaller(tester);
    await openOnboarding(tester);
    final AppLocalizations strings = stringsOf(tester);

    expect(find.text(strings.onboardingTitle1), findsOneWidget);
    expect(find.text(strings.onboardingBody1), findsOneWidget);
    // Kolase 2x2: empat sampul kanari nyata di halaman 1 (PageView juga
    // membangun halaman tetangga, jadi hitung dalam halaman 1 saja).
    expect(
      find.descendant(
        of: find.byKey(const Key('onboarding-page-1')),
        matching: find.byType(AlbumCover),
      ),
      findsNWidgets(4),
    );
    expect(find.text(strings.skip), findsOneWidget);
    expect(find.text(strings.onboardingNext), findsOneWidget);
    expect(find.text(strings.onboardingStart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lanjut menggeser halaman 1-2-3-4, terakhir Mulai',
      (WidgetTester tester) async {
    await pumpCaller(tester);
    await openOnboarding(tester);
    final AppLocalizations strings = stringsOf(tester);

    await tester.tap(find.text(strings.onboardingNext));
    await tester.pumpAndSettle();
    expect(find.text(strings.onboardingTitle2), findsOneWidget);
    expect(find.text(strings.onboardingBody2), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('onboarding-page-2')),
        matching: find.byType(AlbumCover),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(strings.onboardingNext));
    await tester.pumpAndSettle();
    expect(find.text(strings.onboardingTitle3), findsOneWidget);
    expect(find.text(strings.onboardingBody3), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('onboarding-page-3')),
        matching: find.byType(AlbumCover),
      ),
      findsOneWidget,
    );

    // Halaman 4 (terakhir): model unduh-dulu — lagu bukan bawaan app,
    // butuh internet sekali di awal. Lencana panah-unduh menandai
    // tindakan yang harus dilakukan dulu (berbeda dari lencana
    // centang-unduh halaman 3).
    await tester.tap(find.text(strings.onboardingNext));
    await tester.pumpAndSettle();
    expect(find.text(strings.onboardingTitle4), findsOneWidget);
    expect(find.text(strings.onboardingBody4), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('onboarding-page-4')),
        matching: find.byType(AlbumCover),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.text(strings.onboardingStart), findsOneWidget);
    expect(find.text(strings.onboardingNext), findsNothing);

    // Selesai menutup alur, kembali ke pemanggil.
    await tester.tap(find.text(strings.onboardingStart));
    await tester.pumpAndSettle();
    expect(find.text('Buka pengenalan'), findsOneWidget);
    expect(find.text(strings.onboardingTitle4), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lewati menutup alur dari halaman 1',
      (WidgetTester tester) async {
    await pumpCaller(tester);
    await openOnboarding(tester);
    final AppLocalizations strings = stringsOf(tester);

    await tester.tap(find.text(strings.skip));
    await tester.pumpAndSettle();
    expect(find.text('Buka pengenalan'), findsOneWidget);
    expect(find.text(strings.onboardingTitle1), findsNothing);
  });

  testWidgets('geser kiri (swipe) berpindah halaman',
      (WidgetTester tester) async {
    await pumpCaller(tester);
    await openOnboarding(tester);
    final AppLocalizations strings = stringsOf(tester);

    // Fling (bukan drag): drag -400 px di viewport 800 px tepat 50% dan
    // slop sentuh membuat halaman kembali ke awal; fling berkecepatan
    // memberi keputusan pindah halaman yang tegas seperti geseran nyata.
    await tester.fling(
      find.byType(PageView),
      const Offset(-400, 0),
      1000.0,
    );
    await tester.pumpAndSettle();
    expect(find.text(strings.onboardingTitle2), findsOneWidget);
  });

  testWidgets('viewport 360x640: keempat halaman tanpa overflow',
      (WidgetTester tester) async {
    setViewport(tester, const Size(360, 640), 3.0);
    await pumpCaller(tester);
    await openOnboarding(tester);
    final AppLocalizations strings = stringsOf(tester);

    expect(tester.takeException(), isNull);
    await tester.tap(find.text(strings.onboardingNext));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(strings.onboardingNext));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(strings.onboardingNext));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Tombol aksi terakhir tetap terlihat + bisa diketuk.
    await tester.tap(find.text(strings.onboardingStart));
    await tester.pumpAndSettle();
    expect(find.text('Buka pengenalan'), findsOneWidget);
  });

  testWidgets('viewport tablet 800x1280: tanpa overflow',
      (WidgetTester tester) async {
    setViewport(tester, const Size(800, 1280), 2.0);
    await pumpCaller(tester);
    await openOnboarding(tester);
    final AppLocalizations strings = stringsOf(tester);

    expect(tester.takeException(), isNull);
    await tester.tap(find.text(strings.onboardingNext));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.onboardingNext));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.onboardingNext));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(strings.onboardingStart), findsOneWidget);
  });
}
