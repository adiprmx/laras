import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/features/player/player_screen.dart';
import 'package:laras/l10n/generated/app_localizations_id.dart';
import 'package:laras/player/player.dart';

import 'fakes.dart';
import 'widget_helpers.dart';

void main() {
  group('PlayerScreen', () {
    late FakeAudioPlayerPort port;
    late List<Track> tracks;

    PlayerSnapshot playingSnapshot({
      bool playing = true,
      PlayerStatus status = PlayerStatus.ready,
      int currentIndex = 0,
      bool shuffleEnabled = false,
      RepeatMode repeatMode = RepeatMode.off,
      PlaybackFailure? lastError,
      bool reResolving = false,
      double speed = 1.0,
      double pitch = 1.0,
      bool skipSilence = false,
    }) {
      return PlayerSnapshot(
        currentTrack: tracks[currentIndex],
        queue: tracks,
        currentIndex: currentIndex,
        playing: playing,
        status: status,
        duration: tracks[currentIndex].duration,
        shuffleEnabled: shuffleEnabled,
        repeatMode: repeatMode,
        speed: speed,
        pitch: pitch,
        skipSilence: skipSilence,
        lastError: lastError,
        reResolving: reResolving,
      );
    }

    setUp(() {
      tracks = <Track>[
        testTrack('a', duration: const Duration(minutes: 3)),
        testTrack('b', duration: const Duration(minutes: 4)),
        testTrack('c', duration: const Duration(minutes: 5)),
      ];
      port = FakeAudioPlayerPort(
        initialSnapshot: PlayerSnapshot(
          currentTrack: tracks[0],
          queue: tracks,
          currentIndex: 0,
          playing: true,
          status: PlayerStatus.ready,
          duration: const Duration(minutes: 3),
        ),
      );
    });

    tearDown(() async {
      await port.dispose();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpLarasWidget(tester, PlayerScreen(port: port));
    }

    testWidgets('menampilkan judul, artis, slider, dan antrean',
        (WidgetTester tester) async {
      port.emitPosition(const Duration(seconds: 30));
      await pumpScreen(tester);
      // Judul lagu yang diputar tampil dua kali: header + baris antrean.
      expect(find.text('Lagu a'), findsNWidgets(2));
      expect(find.text('Artis a'), findsNWidgets(2));
      expect(find.text('0:30'), findsOneWidget);
      expect(find.text('3:00'), findsNWidgets(2));
      final Slider slider = tester.widget(find.byType(Slider));
      expect(slider.value, 30000.0);
      expect(slider.max, 180000.0);
      expect(find.text('Lagu b'), findsOneWidget);
      expect(find.text('Lagu c'), findsOneWidget);
    });

    testWidgets('tombol putar/jeda, sebelumnya, berikutnya diteruskan',
        (WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.pause));
      await tester.tap(find.byIcon(Icons.skip_previous));
      await tester.tap(find.byIcon(Icons.skip_next));
      expect(port.pauseCalls, 1);
      expect(port.skipToPreviousCalls, 1);
      expect(port.skipToNextCalls, 1);
    });

    testWidgets('tombol acak dan ulangi mengubah mode',
        (WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.shuffle));
      expect(port.setShuffleCalls, <bool>[true]);
      await tester.tap(find.byIcon(Icons.repeat));
      expect(port.setRepeatModeCalls, <RepeatMode>[RepeatMode.all]);
    });

    testWidgets('mengetuk lagu di antrean melompat ke lagu itu',
        (WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Lagu b'));
      expect(port.skipToIndexCalls, <int>[1]);
    });

    testWidgets('pengaturan suara: kecepatan dan lewati hening',
        (WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.5x'));
      expect(port.setSpeedCalls, contains(1.5));
      await tester.tap(find.byType(Switch));
      expect(port.setSkipSilenceCalls, <bool>[true]);
    });

    testWidgets('saat memuat, tombol putar diganti spinner',
        (WidgetTester tester) async {
      port.emitSnapshot(playingSnapshot(status: PlayerStatus.loading));
      await pumpScreen(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('banner error tampil dengan tombol coba lagi',
        (WidgetTester tester) async {
      port.emitSnapshot(
        playingSnapshot(
          playing: false,
          status: PlayerStatus.error,
          lastError: const PlaybackFailure(
            kind: PlaybackFailureKind.unplayable,
            trackTitle: 'Lagu a',
          ),
        ),
      );
      await pumpScreen(tester);
      expect(find.text(AppLocalizationsId().songCannotPlay), findsOneWidget);
      await tester.tap(find.text(AppLocalizationsId().retry));
      expect(port.playCalls, 1);
    });

    testWidgets('indikator mencoba lagi tampil saat re-resolve',
        (WidgetTester tester) async {
      port.emitSnapshot(
        playingSnapshot(
          status: PlayerStatus.buffering,
          reResolving: true,
        ),
      );
      await pumpScreen(tester);
      expect(find.text(AppLocalizationsId().retryingSong), findsOneWidget);
    });

    testWidgets('tanpa lagu menampilkan antrean kosong',
        (WidgetTester tester) async {
      port.emitSnapshot(PlayerSnapshot.idle);
      await pumpScreen(tester);
      expect(find.text(AppLocalizationsId().queueEmpty), findsOneWidget);
    });
  });
}
