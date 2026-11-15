/// Helper pompa widget dengan tema + lokalisasi Laras (Bahasa Indonesia).
///
/// Sengaja memakai `pump()` (satu frame), BUKAN `pumpAndSettle()`:
/// layar yang menampilkan CircularProgressIndicator (spinner) menjadwalkan
/// frame tanpa henti, jadi `pumpAndSettle()` tidak pernah selesai dan tes
/// menggantung sampai timeout.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

Future<void> pumpLarasWidget(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('id')],
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

/// Pompa dua frame: frame pertama mengantarkan event stream ke pendengar,
/// frame kedua me-rebuild widget yang di-setState oleh event itu.
/// Satu pump() saja sering tidak cukup karena event tiba sesudah frame
/// pertama dibangun.
Future<void> pumpTwoFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}
