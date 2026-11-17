/// Tes layar Kebijakan privasi (P10): status memuat/gagal, aset
/// nyata terbungkus, navigasi dari Tentang, dan invarian isi aset
/// sama dengan PRIVACY_POLICY.md repo.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/features/settings/about_screen.dart';
import 'package:laras/features/settings/privacy_policy_screen.dart';

import '../../player/widget_helpers.dart';

void main() {
  group('invarian isi kebijakan', () {
    test('aset sama persis dengan PRIVACY_POLICY.md repo', () {
      // flutter test berjalan dengan CWD = root paket, sama seperti
      // arb_no_jargon_test.dart.
      final List<int> repo =
          File('PRIVACY_POLICY.md').readAsBytesSync();
      final List<int> asset =
          File('assets/privacy_policy_id.md').readAsBytesSync();
      expect(listEquals(repo, asset), isTrue);
    });

    test('kebijakan menyebut LRCLIB dan kontak', () {
      final String policy = File('PRIVACY_POLICY.md').readAsStringSync();
      expect(policy, contains('LRCLIB'));
      expect(policy, contains('lrclib.net'));
      expect(policy, contains('adiprmx@gmail.com'));
    });
  });

  group('PrivacyPolicyScreen', () {
    testWidgets('menampilkan isi dari loader sebagai teks yang bisa dipilih',
        (WidgetTester tester) async {
      await pumpLarasWidget(
        tester,
        PrivacyPolicyScreen(
          policyLoader: () async => 'Isi kebijakan tes.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      final SelectableText text =
          tester.widget<SelectableText>(find.byType(SelectableText));
      expect(text.data, 'Isi kebijakan tes.');
      expect(find.text('Kebijakan privasi'), findsOneWidget);
    });

    testWidgets('menampilkan status memuat lalu isi saat loader selesai',
        (WidgetTester tester) async {
      final Completer<String> completer = Completer<String>();
      await pumpLarasWidget(
        tester,
        PrivacyPolicyScreen(policyLoader: () => completer.future),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Memuat kebijakan privasi...'), findsOneWidget);
      completer.complete('Isi kebijakan tes.');
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('gagal memuat lalu coba lagi berhasil',
        (WidgetTester tester) async {
      int calls = 0;
      await pumpLarasWidget(
        tester,
        PrivacyPolicyScreen(
          policyLoader: () async {
            calls++;
            if (calls == 1) throw Exception('aset hilang');
            return 'Isi kebijakan tes.';
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Kebijakan privasi belum bisa dibuka.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets('tanpa loader, aset nyata terbungkus dan terbaca',
        (WidgetTester tester) async {
      await pumpLarasWidget(tester, const PrivacyPolicyScreen());
      // Bukan pumpAndSettle: spinner menjadwalkan frame tanpa henti,
      // dan pumpAndSettle memakai jam palsu sehingga 10 menit fake
      // habis dalam hitungan detik bila muatan aset tertunda.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SelectableText), findsOneWidget);
      final SelectableText text =
          tester.widget<SelectableText>(find.byType(SelectableText));
      expect(text.data, contains('Kebijakan Privasi Laras'));
      expect(text.data, contains('LRCLIB'));
    });
  });

  group('navigasi dari Tentang', () {
    testWidgets('baris Kebijakan privasi membuka layar kebijakan',
        (WidgetTester tester) async {
      await pumpLarasWidget(tester, const AboutScreen());
      await tester.pumpAndSettle();
      final Finder row = find.text('Kebijakan privasi');
      expect(row, findsOneWidget);
      await tester.ensureVisible(row);
      await tester.tap(row);
      // Bukan pumpAndSettle: layar yang didorong menampilkan spinner
      // selama aset dimuat, dan spinner menjadwalkan frame tanpa
      // henti (lihat catatan di tes aset nyata di atas).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      // Tes ini hanya membuktikan navigasi + layar yang didorong
      // mulai memuat. Isi aset dibuktikan tes "tanpa loader" di
      // atas, bukan di sini: menunggu muatan aset di tes ini
      // menggantung deterministik (kuirk harness, bukan bug
      // produksi: future aset yang di-cache rootBundle dari tes
      // sebelumnya tidak pernah dilanjutkan di zona FakeAsync tes
      // ini, terbukti dengan await loadString langsung di badan
      // tes yang juga menggantung; di HP nyata tidak ada zona
      // FakeAsync dan jalur yang sama terbukti di tes langsung).
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Memuat kebijakan privasi...'), findsOneWidget);
    });
  });
}
