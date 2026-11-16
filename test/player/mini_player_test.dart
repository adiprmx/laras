import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/features/player/mini_player.dart';
import 'package:laras/player/player.dart';

import 'widget_helpers.dart';

void main() {
  group('MiniPlayer', () {
    testWidgets('menampilkan judul, artis, dan progres lagu',
        (WidgetTester tester) async {
      await pumpLarasWidget(
        tester,
        MiniPlayer(
          title: 'Lagu Uji',
          artist: 'Artis Uji',
          isPlaying: true,
          position: const Duration(seconds: 30),
          duration: const Duration(minutes: 3),
          onTap: () {},
          onPlayPause: () {},
          onNext: () {},
          onPrevious: () {},
        ),
      );
      expect(find.text('Lagu Uji'), findsOneWidget);
      expect(find.text('Artis Uji'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      final LinearProgressIndicator progress =
          tester.widget(find.byType(LinearProgressIndicator));
      expect(progress.value, moreOrLessEquals(30 / 180));
    });

    testWidgets('durasi belum diketahui: progres nol, ikon putar',
        (WidgetTester tester) async {
      await pumpLarasWidget(
        tester,
        MiniPlayer(
          title: 'Lagu Uji',
          artist: null,
          isPlaying: false,
          onTap: () {},
          onPlayPause: () {},
          onNext: () {},
          onPrevious: () {},
        ),
      );
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      final LinearProgressIndicator progress =
          tester.widget(find.byType(LinearProgressIndicator));
      expect(progress.value, 0.0);
    });

    testWidgets('tombol sebelumnya, putar/jeda, berikutnya memanggil callback',
        (WidgetTester tester) async {
      bool tappedPrev = false;
      bool tappedPlayPause = false;
      bool tappedNext = false;
      bool tappedBody = false;
      await pumpLarasWidget(
        tester,
        MiniPlayer(
          title: 'Lagu Uji',
          artist: 'Artis Uji',
          isPlaying: false,
          onTap: () => tappedBody = true,
          onPlayPause: () => tappedPlayPause = true,
          onNext: () => tappedNext = true,
          onPrevious: () => tappedPrev = true,
        ),
      );
      await tester.tap(find.byIcon(Icons.skip_previous));
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.tap(find.text('Lagu Uji'));
      expect(tappedPrev, isTrue);
      expect(tappedPlayPause, isTrue);
      expect(tappedNext, isTrue);
      expect(tappedBody, isTrue);
    });

    testWidgets('tinggi tetap 64 dp', (WidgetTester tester) async {
      await pumpLarasWidget(
        tester,
        MiniPlayer(
          title: 'Lagu Uji',
          artist: null,
          isPlaying: false,
          onTap: () {},
          onPlayPause: () {},
          onNext: () {},
          onPrevious: () {},
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('mini-player'))).height,
        64,
      );
    });

    testWidgets('sampul tampil bila artUri diberikan',
        (WidgetTester tester) async {
      await pumpLarasWidget(
        tester,
        MiniPlayer(
          title: 'Lagu Uji',
          artist: null,
          isPlaying: false,
          artUri: Uri.parse('https://i.ytimg.com/vi/abc123/hqdefault.jpg'),
          onTap: () {},
          onPlayPause: () {},
          onNext: () {},
          onPrevious: () {},
        ),
      );
      final Finder cover = find.byType(CachedNetworkImage);
      expect(cover, findsOneWidget);
      expect(
        tester.widget<CachedNetworkImage>(cover).imageUrl,
        'https://i.ytimg.com/vi/abc123/hqdefault.jpg',
      );
    });

    testWidgets('tombol hati memanggil onToggleFavorite',
        (WidgetTester tester) async {
      bool toggled = false;
      await pumpLarasWidget(
        tester,
        MiniPlayer(
          title: 'Lagu Uji',
          artist: null,
          isPlaying: false,
          isFavorite: false,
          onToggleFavorite: () => toggled = true,
          onTap: () {},
          onPlayPause: () {},
          onNext: () {},
          onPrevious: () {},
        ),
      );
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite_border));
      expect(toggled, isTrue);
    });

    testWidgets('hati terisi bila isFavorite benar; sembunyi tanpa callback',
        (WidgetTester tester) async {
      await pumpLarasWidget(
        tester,
        MiniPlayer(
          title: 'Lagu Uji',
          artist: null,
          isPlaying: false,
          isFavorite: true,
          onToggleFavorite: () {},
          onTap: () {},
          onPlayPause: () {},
          onNext: () {},
          onPrevious: () {},
        ),
      );
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      // Tanpa callback, tidak ada tombol hati sama sekali.
      await pumpLarasWidget(
        tester,
        MiniPlayer(
          title: 'Lagu Uji',
          artist: null,
          isPlaying: false,
          onTap: () {},
          onPlayPause: () {},
          onNext: () {},
          onPrevious: () {},
        ),
      );
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });
  });

  group('MiniPlayer state error (P0)', () {
    Future<void> pumpError(
      WidgetTester tester,
      PlaybackFailureKind kind, {
      VoidCallback? onPlayPause,
    }) async {
      await pumpLarasWidget(
        tester,
        MiniPlayer(
          title: 'Lagu Uji',
          artist: 'Artis Uji',
          isPlaying: false,
          failure: PlaybackFailure(kind: kind, trackTitle: 'Lagu Uji'),
          onTap: () {},
          onPlayPause: onPlayPause ?? () {},
          onNext: () {},
          onPrevious: () {},
        ),
      );
    }

    testWidgets('jaringan: pesan singkat menggantikan artis + tombol segar',
        (WidgetTester tester) async {
      await pumpError(tester, PlaybackFailureKind.network);
      expect(find.text('Lagu Uji'), findsOneWidget);
      expect(find.text('Tidak ada internet'), findsOneWidget);
      // Baris artis diganti pesan error: tidak ada ruang untuk keduanya.
      expect(find.text('Artis Uji'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byTooltip('Coba lagi'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('timeout: pesan "Internet lambat"',
        (WidgetTester tester) async {
      await pumpError(tester, PlaybackFailureKind.timeout);
      expect(find.text('Internet lambat'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('tidak bisa diputar: pesan "Tidak bisa diputar"',
        (WidgetTester tester) async {
      await pumpError(tester, PlaybackFailureKind.unplayable);
      expect(find.text('Tidak bisa diputar'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('mengetuk tombol segar memanggil onPlayPause (retry)',
        (WidgetTester tester) async {
      bool retried = false;
      await pumpError(
        tester,
        PlaybackFailureKind.network,
        onPlayPause: () => retried = true,
      );
      await tester.tap(find.byIcon(Icons.refresh));
      expect(retried, isTrue);
    });

    testWidgets('tinggi tetap 64 dp dalam state error',
        (WidgetTester tester) async {
      await pumpError(tester, PlaybackFailureKind.network);
      expect(
        tester.getSize(find.byKey(const Key('mini-player'))).height,
        64,
      );
    });
  });
}
