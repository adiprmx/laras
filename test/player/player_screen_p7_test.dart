/// Tes widget P7 di layar pemutar: tombol lirik + timer tidur, chip
/// hitung mundur, dan bagian equalizer di lembar pengaturan suara.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/features/lyrics/lrclib_client.dart';
import 'package:laras/features/lyrics/lyrics_service.dart';
import 'package:laras/features/player/player_screen.dart';
import 'package:laras/player/player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/lyrics/lyrics_service_test.dart' show FakeLrclibClient;
import 'fakes.dart';
import 'widget_helpers.dart';

/// Handler platform EQ palsu untuk tes layar (2 pita + 2 preset).
Future<Object?> fakeEqHandler(MethodCall call) async {
  switch (call.method) {
    case 'init':
      return <String, Object>{
        'available': true,
        'centerFreqs': <int>[60000, 14000000],
        'levels': <int>[0, 0],
        'minLevel': -1500,
        'maxLevel': 1500,
        'presets': <String>['Normal', 'Rock'],
        'currentPreset': 0,
      };
    case 'setEnabled':
      return true;
    case 'setPreset':
      return <int>[100, 200];
    case 'setBandLevel':
      return true;
    case 'release':
      return null;
    default:
      throw MissingPluginException();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerScreen P7', () {
    late FakeAudioPlayerPort port;
    late List<Track> tracks;
    late SleepTimerService sleepTimer;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tracks = <Track>[
        testTrack('a', duration: const Duration(minutes: 3)),
        testTrack('b', duration: const Duration(minutes: 4)),
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
      sleepTimer = SleepTimerService(port: port);
    });

    tearDown(() async {
      await sleepTimer.dispose();
      await port.dispose();
    });

    Future<void> pumpScreen(
      WidgetTester tester, {
      SleepTimerService? timer,
      EqualizerService? equalizer,
      LyricsService? lyrics,
    }) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpLarasWidget(
        tester,
        PlayerScreen(
          port: port,
          sleepTimer: timer,
          equalizerService: equalizer,
          lyricsService: lyrics,
        ),
      );
    }

    testWidgets('tombol Lirik + Timer tidur tampil bila service ada',
        (WidgetTester tester) async {
      final LyricsService lyrics = LyricsService(
        client: FakeLrclibClient(
          result: const LrclibTrack(id: 1, plainLyrics: 'x'),
        ),
      );
      await pumpScreen(
        tester,
        timer: sleepTimer,
        lyrics: lyrics,
      );
      expect(find.text('Lirik'), findsOneWidget);
      expect(find.text('Timer tidur'), findsOneWidget);
      expect(find.text('Pengaturan suara'), findsOneWidget);
    });

    testWidgets('tombol Lirik + Timer tidur sembunyi bila service null',
        (WidgetTester tester) async {
      await pumpScreen(tester);
      expect(find.text('Lirik'), findsNothing);
      expect(find.text('Timer tidur'), findsNothing);
      expect(find.text('Pengaturan suara'), findsOneWidget);
    });

    testWidgets('mengetuk Lirik membuka lembar lirik',
        (WidgetTester tester) async {
      final LyricsService lyrics = LyricsService(
        client: FakeLrclibClient(
          result: const LrclibTrack(
            id: 1,
            syncedLyrics: '[00:01.00]Baris lirik',
          ),
        ),
      );
      await pumpScreen(tester, lyrics: lyrics);
      await tester.tap(find.text('Lirik'));
      await tester.pumpAndSettle();
      expect(find.text('Baris lirik'), findsOneWidget);
      expect(find.text('Lirik dari LRCLIB'), findsOneWidget);
    });

    testWidgets('mengetuk Timer tidur membuka lembar pemilih',
        (WidgetTester tester) async {
      await pumpScreen(tester, timer: sleepTimer);
      await tester.tap(find.text('Timer tidur'));
      // pumpAndSettle: animasi sheet baru mulai sesudah ketukan
      // dikenali satu frame; pump() durasi tunggal meninggalkannya
      // di bawah layar. Aman di sini karena timer belum jalan
      // (belum ada Timer.periodic).
      await tester.pumpAndSettle();
      expect(find.text('5 mnt'), findsOneWidget);
      expect(find.text('60 mnt'), findsOneWidget);
      expect(find.text('Sesudah lagu ini habis'), findsOneWidget);
      expect(find.text('Waktu lain'), findsOneWidget);
    });

    testWidgets('memilih preset memulai timer + chip hitung mundur tampil',
        (WidgetTester tester) async {
      await pumpScreen(tester, timer: sleepTimer);
      await tester.tap(find.text('Timer tidur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15 mnt'));
      // Timer sudah jalan (Timer.periodic 1 detik) — pumpAndSettle
      // tidak akan pernah selesai; pump() biasa cukup karena chip
      // tampil dari ValueNotifier, bukan dari animasi tutup sheet.
      // Pump kedua memajukan jam 500ms supaya animasi tutup sheet
      // selesai — kalau tidak, teks status di dalam sheet masih ada
      // dan find.text menemukan 2 widget.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(sleepTimer.isActive, isTrue);
      expect(sleepTimer.mode.value, SleepTimerMode.timed);
      expect(find.text('Berhenti dalam 15 mnt'), findsOneWidget);
      // Matikan timer di dalam badan tes: pemeriksaan invarian binding
      // (tidak ada Timer tertinggal) jalan SEBELUM tearDown, jadi
      // dispose di tearDown saja tidak cukup.
      sleepTimer.cancel();
    });

    testWidgets('mode akhir-lagu menampilkan chip yang sesuai',
        (WidgetTester tester) async {
      await pumpScreen(tester, timer: sleepTimer);
      await tester.tap(find.text('Timer tidur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sesudah lagu ini habis'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(sleepTimer.mode.value, SleepTimerMode.afterSong);
      expect(find.text('Berhenti sesudah lagu ini'), findsOneWidget);
    });

    testWidgets('chip hitung mundur tidak tampil saat timer mati',
        (WidgetTester tester) async {
      await pumpScreen(tester, timer: sleepTimer);
      expect(find.textContaining('Berhenti'), findsNothing);
    });

    testWidgets(
        'lembar suara tanpa session menampilkan pesan putar-dulu untuk EQ',
        (WidgetTester tester) async {
      final EqualizerService equalizer = EqualizerService(
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(equalizer.dispose);
      await pumpScreen(tester, equalizer: equalizer);
      await tester.tap(find.text('Pengaturan suara'));
      await tester.pumpAndSettle();
      expect(
        find.text('Putar lagu dulu untuk mengatur suara'),
        findsOneWidget,
      );
    });

    testWidgets('bagian EQ tampil sesudah attach: preset + slider pita',
        (WidgetTester tester) async {
      const MethodChannel channel = MethodChannel(
        'id.my.adipmusic.laras/equalizer',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, fakeEqHandler);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final EqualizerService equalizer = EqualizerService(
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(equalizer.dispose);
      await equalizer.attach(123);
      await pumpScreen(tester, equalizer: equalizer);
      await tester.tap(find.text('Pengaturan suara'));
      await tester.pumpAndSettle();
      expect(find.text('Equalizer'), findsOneWidget);
      expect(find.text('Pilihan suara'), findsOneWidget);
      expect(find.text('Rock'), findsOneWidget);
      expect(find.text('Atur sendiri'), findsOneWidget);
      expect(find.text('60 Hz'), findsOneWidget);
      expect(find.text('14 kHz'), findsOneWidget);
      // Mengetuk preset Rock mengubah level (platform menjawab 100/200).
      await tester.tap(find.text('Rock'));
      await tester.pump();
      await tester.pump();
      expect(equalizer.info.value!.currentPreset, 1);
      expect(equalizer.info.value!.bands[0].levelMillibels, 100);
    });
  });
}
