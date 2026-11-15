import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/spike_demo/spike_demo_screen.dart';
import 'package:laras/l10n/generated/app_localizations_id.dart';
import 'package:laras/player/player.dart';

import 'fakes.dart';
import 'widget_helpers.dart';

void main() {
  group('SpikeDemoScreen (memakai player nyata)', () {
    late FakeAudioPlayerPort port;
    late FakeAudioResolver resolver;
    late PlayerService service;

    setUp(() {
      port = FakeAudioPlayerPort();
      resolver = FakeAudioResolver();
      service = PlayerService(
        port: port,
        resolver: resolver,
        solver: FakeSignatureSolver(),
      );
    });

    tearDown(() async {
      await port.dispose();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      // Viewport tinggi supaya seluruh daftar (termasuk bagian log di
      // bawah) dibangun ListView dan bisa dicari tes.
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpLarasWidget(
        tester,
        PlayerScope(service: service, child: const SpikeDemoScreen()),
      );
    }

    PlayerSnapshot snapshotFor(int index, {bool playing = true}) {
      final CanarySong song = kCanarySongs[index];
      return PlayerSnapshot(
        currentTrack: Track(
          videoId: song.videoId,
          title: song.title,
          duration: Duration(seconds: song.lengthSeconds),
        ),
        queue: kCanarySongs
            .map(
              (CanarySong s) => Track(
                videoId: s.videoId,
                title: s.title,
                duration: Duration(seconds: s.lengthSeconds),
              ),
            )
            .toList(),
        currentIndex: index,
        playing: playing,
        status: PlayerStatus.ready,
      );
    }

    testWidgets('menampilkan 5 lagu kanari', (WidgetTester tester) async {
      await pumpScreen(tester);
      for (final CanarySong song in kCanarySongs) {
        expect(find.text(song.title), findsOneWidget);
      }
      expect(find.text(AppLocalizationsId().spikeDemoLogEmpty), findsOneWidget);
    });

    testWidgets('mengetuk lagu memanggil setQueue 5 lagu dengan autoplay',
        (WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text(kCanarySongs[1].title));
      await tester.pump();
      expect(port.setQueueCalls, hasLength(1));
      final (List<Track>, int, bool) call = port.setQueueCalls.single;
      expect(call.$1.length, 5);
      expect(
        call.$1.map((t) => t.videoId).toList(),
        kCanarySongs.map((s) => s.videoId).toList(),
      );
      expect(call.$2, 1);
      expect(call.$3, isTrue);
    });

    testWidgets('baris lagu mencerminkan status diputar dari snapshot',
        (WidgetTester tester) async {
      await pumpScreen(tester);
      port.emitSnapshot(snapshotFor(0, playing: true));
      await pumpTwoFrames(tester);
      expect(find.text(AppLocalizationsId().spikeDemoPlaying), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('mengetuk lagu yang diputar menjeda, mengetuk lagi melanjutkan',
        (WidgetTester tester) async {
      await pumpScreen(tester);
      port.emitSnapshot(snapshotFor(0, playing: true));
      await pumpTwoFrames(tester);
      await tester.tap(find.text(kCanarySongs[0].title));
      await tester.pump();
      expect(port.pauseCalls, 1);
      port.emitSnapshot(snapshotFor(0, playing: false));
      await pumpTwoFrames(tester);
      expect(find.text(AppLocalizationsId().spikeDemoPaused), findsOneWidget);
      await tester.tap(find.text(kCanarySongs[0].title));
      await tester.pump();
      expect(port.playCalls, 1);
    });

    testWidgets('log resolve tampil dari service',
        (WidgetTester tester) async {
      await resolver.resolve(kCanarySongs[0].videoId);
      await pumpScreen(tester);
      expect(find.textContaining('WEB_REMIX'), findsOneWidget);
      expect(find.textContaining('OK'), findsOneWidget);
    });

    testWidgets('tanpa PlayerScope menampilkan pesan jujur',
        (WidgetTester tester) async {
      await pumpLarasWidget(tester, const SpikeDemoScreen());
      expect(find.text(AppLocalizationsId().songCannotPlay), findsOneWidget);
    });
  });
}
