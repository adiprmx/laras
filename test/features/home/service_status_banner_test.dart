/// Tes widget banner status 3 tingkat di beranda (P6, tugas 3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/features/home/service_status_banner.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/resilience/resilience.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../resilience/p6_widget_helpers.dart';

void main() {
  testWidgets('status ok = tanpa banner', (WidgetTester tester) async {
    final SharedPreferences prefs = await seedP6Prefs(status: 'ok');
    final ServiceStatusService service = makeServiceStatus(prefs);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Scaffold(body: ServiceStatusBanner(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold)),
    )!;
    expect(find.text(strings.serviceDegradedBanner), findsNothing);
    expect(find.text(strings.serviceBrokenBanner), findsNothing);
    expect(find.byType(ServiceStatusBanner), findsOneWidget);
  });

  testWidgets('status degraded = banner tipis tanpa tombol pembaruan',
      (WidgetTester tester) async {
    final SharedPreferences prefs = await seedP6Prefs(status: 'degraded');
    final ServiceStatusService service = makeServiceStatus(prefs);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Scaffold(body: ServiceStatusBanner(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold)),
    )!;
    expect(find.text(strings.serviceDegradedBanner), findsOneWidget);
    expect(find.text(strings.serviceBrokenBanner), findsNothing);
    expect(find.text(strings.checkForUpdates), findsNothing);
  });

  testWidgets('status broken = banner jelas + tombol "Periksa pembaruan"',
      (WidgetTester tester) async {
    final SharedPreferences prefs = await seedP6Prefs(status: 'broken');
    final ServiceStatusService service = makeServiceStatus(prefs);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Scaffold(body: ServiceStatusBanner(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold)),
    )!;
    expect(find.text(strings.serviceBrokenBanner), findsOneWidget);
    expect(find.text(strings.serviceDegradedBanner), findsNothing);
    expect(find.text(strings.checkForUpdates), findsOneWidget);
  });

  testWidgets('banner broken tampil di beranda LarasApp (wiring)',
      (WidgetTester tester) async {
    final SharedPreferences prefs = await seedP6Prefs(status: 'broken');
    final ServiceStatusService service = makeServiceStatus(prefs);
    final AppSettings settings = AppSettings.forTest(prefs);
    setPhoneViewport(tester);
    await pumpP6App(tester, settings: settings, serviceStatus: service);
    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.serviceBrokenBanner), findsOneWidget);
    expect(find.text(strings.checkForUpdates), findsOneWidget);
    // Pelajaran P3: tutup pump supaya Timer drift tidak menggantung.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
