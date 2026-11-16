/// Tes banner error putar bersama (P0): pesan per jenis kegagalan,
/// akhiran jumlah lagu yang dilewati, dan tombol coba lagi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/features/player/playback_error_banner.dart';
import 'package:laras/player/player.dart';

import 'widget_helpers.dart';

void main() {
  group('PlaybackErrorBanner', () {
    Future<void> pumpBanner(
      WidgetTester tester,
      PlaybackFailure failure, {
      VoidCallback? onRetry,
    }) async {
      await pumpLarasWidget(
        tester,
        PlaybackErrorBanner(failure: failure, onRetry: onRetry ?? () {}),
      );
    }

    testWidgets('jaringan: pesan tidak ada internet + tombol coba lagi',
        (WidgetTester tester) async {
      bool retried = false;
      await pumpBanner(
        tester,
        const PlaybackFailure(
          kind: PlaybackFailureKind.network,
          trackTitle: 'Lagu Uji',
        ),
        onRetry: () => retried = true,
      );
      expect(
        find.text('Tidak ada internet. Periksa koneksi, lalu coba lagi.'),
        findsOneWidget,
      );
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      await tester.tap(find.text('Coba lagi'));
      expect(retried, isTrue);
    });

    testWidgets('timeout: pesan internet lambat',
        (WidgetTester tester) async {
      await pumpBanner(
        tester,
        const PlaybackFailure(
          kind: PlaybackFailureKind.timeout,
          trackTitle: 'Lagu Uji',
        ),
      );
      expect(
        find.text('Internet lambat, lagu belum sempat dimuat. Coba lagi.'),
        findsOneWidget,
      );
    });

    testWidgets('tidak bisa diputar: pesan lagu tidak bisa diputar',
        (WidgetTester tester) async {
      await pumpBanner(
        tester,
        const PlaybackFailure(
          kind: PlaybackFailureKind.unplayable,
          trackTitle: 'Lagu Uji',
        ),
      );
      expect(
        find.text(
          'Lagu ini tidak bisa diputar sekarang. '
          'Coba lagu lain atau coba lagi nanti.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('skippedCount ditambahkan di akhir pesan',
        (WidgetTester tester) async {
      await pumpBanner(
        tester,
        const PlaybackFailure(
          kind: PlaybackFailureKind.unplayable,
          trackTitle: 'Lagu Uji',
          skippedCount: 2,
        ),
      );
      expect(
        find.text(
          'Lagu ini tidak bisa diputar sekarang. '
          'Coba lagu lain atau coba lagi nanti. '
          '2 lagu dilewati karena tidak bisa diputar.',
        ),
        findsOneWidget,
      );
    });
  });
}
