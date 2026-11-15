import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/player/player.dart';

import 'fakes.dart';

void main() {
  group('JustAudioPlayerPort', () {
    late FakeEngine engine;
    late FakeAudioResolver resolver;
    late FakeAudioSession session;
    late JustAudioPlayerPort port;
    late List<Track> tracks;

    /// Biarkan rantai async yang tidak ditunggu (pramuat, re-resolve)
    /// selesai berjalan.
    Future<void> settle([int ms = 20]) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    setUp(() {
      engine = FakeEngine();
      resolver = FakeAudioResolver();
      session = FakeAudioSession();
      port = JustAudioPlayerPort(
        engine: engine,
        resolver: resolver,
        session: session,
      );
      tracks = <Track>[testTrack('a'), testTrack('b'), testTrack('c')];
    });

    tearDown(() async {
      await port.dispose();
      await session.dispose();
    });

    test('setQueue autoplay memuat lagu pertama dan memutar', () async {
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(resolver.resolveCalls, contains('a'));
      expect(engine.setSourcesCalls, hasLength(1));
      expect(engine.setSourcesCalls.single.$1.single.tag, 'a');
      expect(engine.playCalls, 1);
      expect(session.setActiveCalls, contains(true));
      engine.emitPlaying();
      await settle();
      expect(port.snapshot.playing, isTrue);
      expect(port.snapshot.currentTrack, same(tracks[0]));
      expect(port.snapshot.status, PlayerStatus.ready);
    });

    test('setQueue tanpa autoplay tidak memutar sampai play()', () async {
      await port.setQueue(tracks);
      await settle();
      expect(engine.playCalls, 0);
      await port.play();
      expect(engine.playCalls, 1);
    });

    test('play() selama load berjalan ditunda sampai load selesai', () async {
      resolver = FakeAudioResolver(delay: const Duration(milliseconds: 80));
      port = JustAudioPlayerPort(
        engine: engine,
        resolver: resolver,
        session: session,
      );
      final Future<void> loading = port.setQueue(tracks);
      await port.play();
      expect(engine.playCalls, 0);
      await loading;
      expect(engine.playCalls, 1);
    });

    test('jendela gapless: lagu berikutnya dipramuat di latar', () async {
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(
        engine.sources.map((s) => s.tag).toList(),
        <String>['a', 'b'],
      );
      expect(resolver.resolveCalls, contains('b'));
    });

    test('skipToNext via jendela lalu indeks engine pindah lagu', () async {
      await port.setQueue(tracks, autoplay: true);
      await settle();
      engine.emitPlaying();
      await port.skipToNext();
      expect(engine.seekToNextCalls, 1);
      engine.emitCurrentIndex(1);
      await settle();
      expect(port.snapshot.currentTrack, same(tracks[1]));
      expect(port.snapshot.currentIndex, 1);
      expect(port.position, Duration.zero);
      // Lagu ketiga kini dipramuat sebagai lagu berikutnya.
      expect(
        engine.addedSources.map((s) => s.tag).toList(),
        <String>['b', 'c'],
      );
      expect(resolver.resolveCalls, contains('c'));
    });

    test('skipToNext tanpa jendela memuat lagu berikutnya langsung', () async {
      resolver.scripted['b'] = <Object>[
        const ExtractorException(ResolveFailureCause.httpForbidden),
      ];
      await port.setQueue(tracks, autoplay: true);
      await settle();
      // Pramuat b gagal diam-diam: jendela hanya berisi a.
      expect(engine.sources.map((s) => s.tag).toList(), <String>['a']);
      await port.skipToNext();
      expect(engine.seekToNextCalls, 0);
      expect(port.snapshot.currentTrack, same(tracks[1]));
      expect(engine.setSourcesCalls.last.$1.single.tag, 'b');
    });

    test('skipToPrevious di atas 3 detik kembali ke awal lagu', () async {
      await port.setQueue(tracks, autoplay: true);
      await settle();
      engine.emitPlaying();
      engine.emitPosition(const Duration(seconds: 10));
      await settle();
      await port.skipToPrevious();
      expect(engine.seekCalls.last, Duration.zero);
      expect(port.snapshot.currentTrack, same(tracks[0]));
    });

    test('skipToPrevious di bawah 3 detik pindah ke lagu sebelumnya',
        () async {
      await port.setQueue(tracks, initialIndex: 1, autoplay: true);
      await settle();
      engine.emitPlaying();
      engine.emitPosition(const Duration(seconds: 2));
      await settle();
      await port.skipToPrevious();
      expect(port.snapshot.currentTrack, same(tracks[0]));
    });

    test('skipToIndex melompat; mengetuk lagu yang diputar mengulang dari awal',
        () async {
      await port.setQueue(tracks, autoplay: true);
      await settle();
      await port.skipToIndex(2);
      expect(port.snapshot.currentTrack, same(tracks[2]));
      await port.skipToIndex(2);
      expect(engine.seekCalls.last, Duration.zero);
      await port.skipToIndex(99);
      expect(port.snapshot.currentTrack, same(tracks[2]));
    });

    test('seek dijepit ke 0 dan durasi', () async {
      await port.setQueue(tracks, autoplay: true);
      await settle();
      await port.seek(const Duration(minutes: 99));
      expect(engine.seekCalls.last, const Duration(minutes: 3));
      await port.seek(const Duration(seconds: -5));
      expect(engine.seekCalls.last, Duration.zero);
    });

    test('shuffle mempertahankan lagu yang diputar, matikan mengembalikan urutan',
        () async {
      await port.setQueue(tracks, initialIndex: 1, autoplay: true);
      await settle();
      await port.setShuffle(true);
      expect(port.snapshot.shuffleEnabled, isTrue);
      expect(port.snapshot.currentTrack, same(tracks[1]));
      expect(port.snapshot.currentIndex, 0);
      expect(port.snapshot.queue.length, 3);
      await port.setShuffle(false);
      expect(port.snapshot.shuffleEnabled, isFalse);
      expect(port.snapshot.queue, tracks);
      expect(port.snapshot.currentIndex, 1);
    });

    test('repeat one mengatur loop engine, all/off mematikan', () async {
      await port.setQueue(tracks);
      await port.setRepeatMode(RepeatMode.one);
      expect(engine.loopMode, EngineLoopMode.one);
      expect(port.snapshot.repeatMode, RepeatMode.one);
      await port.setRepeatMode(RepeatMode.all);
      expect(engine.loopMode, EngineLoopMode.off);
      await port.setRepeatMode(RepeatMode.off);
      expect(engine.loopMode, EngineLoopMode.off);
    });

    test('kecepatan, pitch, skip silence diteruskan dan dijepit', () async {
      await port.setSpeed(2.0);
      expect(engine.speed, 2.0);
      expect(port.snapshot.speed, 2.0);
      await port.setSpeed(9.0);
      expect(engine.speed, 3.0);
      await port.setPitch(0.1);
      expect(engine.pitch, 0.5);
      await port.setPitch(1.5);
      expect(engine.pitch, 1.5);
      await port.setSkipSilence(true);
      expect(engine.skipSilence, isTrue);
    });

    test('addToQueue mengembalikan false saat antrean penuh', () async {
      final List<Track> full = List<Track>.generate(
        kMaxQueueLength,
        (int i) => testTrack('t$i'),
      );
      await port.setQueue(full);
      await settle();
      expect(await port.addToQueue(testTrack('extra')), isFalse);
      expect(port.snapshot.queue.length, kMaxQueueLength);
    });

    test('removeFromQueue lagu yang diputar memuat lagu berikutnya', () async {
      await port.setQueue(tracks, autoplay: true);
      await settle();
      engine.emitPlaying();
      await port.removeFromQueue(0);
      expect(port.snapshot.currentTrack, same(tracks[1]));
      expect(engine.setSourcesCalls.last.$1.single.tag, 'b');
    });

    test('removeFromQueue lagu terakhir mengosongkan pemutar', () async {
      await port.setQueue(<Track>[tracks[0]], autoplay: true);
      await settle();
      await port.removeFromQueue(0);
      expect(port.snapshot.currentTrack, isNull);
      expect(port.snapshot.status, PlayerStatus.idle);
      expect(engine.stopCalls, 1);
    });

    test('clearQueue menghentikan dan mengosongkan', () async {
      await port.setQueue(tracks, autoplay: true);
      await settle();
      await port.clearQueue();
      expect(port.snapshot.queue, isEmpty);
      expect(port.snapshot.status, PlayerStatus.idle);
      expect(engine.stopCalls, 1);
    });

    test('stop mematikan sesi audio dan status idle', () async {
      await port.setQueue(tracks, autoplay: true);
      await settle();
      await port.stop();
      expect(engine.stopCalls, 1);
      expect(session.setActiveCalls.last, isFalse);
      expect(port.snapshot.playing, isFalse);
      expect(port.snapshot.status, PlayerStatus.idle);
    });

    group('re-resolve (seam K-F2-05)', () {
      test('error di tengah lagu: resolve ulang dan lanjut dari posisi terakhir',
          () async {
        await port.setQueue(tracks, autoplay: true);
        await settle();
        engine.emitPlaying();
        engine.emitPosition(const Duration(seconds: 30));
        await settle();
        engine.emitError();
        await settle();
        expect(
          resolver.resolveCalls.where((id) => id == 'a').length,
          2,
        );
        final (List<EngineSource>, int, Duration?) lastLoad =
            engine.setSourcesCalls.last;
        expect(lastLoad.$1.single.tag, 'a');
        expect(lastLoad.$3, const Duration(seconds: 30));
        expect(engine.playCalls, 2);
        expect(port.snapshot.currentTrack, same(tracks[0]));
        expect(port.snapshot.reResolving, isFalse);
      });

      test('gagal 3 kali lalu maju ke lagu berikutnya dengan error jujur',
          () async {
        resolver.scripted['a'] = <Object>[
          testResolved('a'),
          const ExtractorException(ResolveFailureCause.httpForbidden),
          const ExtractorException(ResolveFailureCause.httpForbidden),
          const ExtractorException(ResolveFailureCause.httpForbidden),
        ];
        await port.setQueue(tracks, autoplay: true);
        await settle();
        engine.emitPlaying();
        engine.emitPosition(const Duration(seconds: 30));
        await settle();
        engine.emitError();
        await settle(50);
        expect(
          resolver.resolveCalls.where((id) => id == 'a').length,
          4,
        );
        expect(port.snapshot.currentTrack, same(tracks[1]));
        expect(port.snapshot.lastError, isNotNull);
        expect(
          port.snapshot.lastError!.kind,
          PlaybackFailureKind.unplayable,
        );
        expect(port.snapshot.lastError!.skippedCount, 1);
        expect(port.snapshot.lastError!.trackTitle, 'Lagu a');
      });

      test('gagal jaringan dilaporkan sebagai network, bukan unplayable',
          () async {
        resolver.scripted['a'] = <Object>[
          testResolved('a'),
          const ExtractorException(
            ResolveFailureCause.httpForbidden,
            isNetworkError: true,
          ),
          const ExtractorException(
            ResolveFailureCause.httpForbidden,
            isNetworkError: true,
          ),
          const ExtractorException(
            ResolveFailureCause.httpForbidden,
            isNetworkError: true,
          ),
        ];
        await port.setQueue(<Track>[tracks[0]], autoplay: true);
        await settle();
        engine.emitPlaying();
        engine.emitPosition(const Duration(seconds: 30));
        await settle();
        engine.emitError();
        await settle(50);
        expect(port.snapshot.status, PlayerStatus.error);
        expect(port.snapshot.lastError!.kind, PlaybackFailureKind.network);
      });

      test('skip pengguna di tengah re-resolve membatalkan re-resolve',
          () async {
        resolver = FakeAudioResolver(delay: const Duration(milliseconds: 100));
        port = JustAudioPlayerPort(
          engine: engine,
          resolver: resolver,
          session: session,
        );
        await port.setQueue(tracks, autoplay: true);
        await settle(150);
        engine.emitPlaying();
        engine.emitPosition(const Duration(seconds: 30));
        await settle();
        engine.emitError();
        await port.skipToNext();
        engine.emitCurrentIndex(1);
        await settle(200);
        expect(port.snapshot.currentTrack, same(tracks[1]));
        // Re-resolve dibatalkan: tidak ada setSources kedua untuk lagu a.
        expect(engine.setSourcesCalls, hasLength(1));
      });

      test('error di ujung lagu dianggap selesai, langsung lanjut', () async {
        await port.setQueue(tracks, autoplay: true);
        await settle();
        engine.emitPlaying();
        engine.emitPosition(const Duration(seconds: 178));
        await settle();
        engine.emitError();
        await settle();
        expect(
          resolver.resolveCalls.where((id) => id == 'a').length,
          1,
        );
        expect(port.snapshot.currentTrack, same(tracks[1]));
      });
    });

    group('gagal muat awal dan rantai lewati', () {
      test('gagal resolve awal memberi status error, play() mencoba lagi',
          () async {
        resolver.scripted['a'] = <Object>[
          const ExtractorException(
            ResolveFailureCause.httpForbidden,
            isNetworkError: true,
          ),
        ];
        await port.setQueue(tracks, autoplay: true);
        await settle();
        expect(port.snapshot.status, PlayerStatus.error);
        expect(port.snapshot.lastError!.kind, PlaybackFailureKind.network);
        await port.play();
        await settle();
        expect(port.snapshot.lastError, isNull);
        expect(engine.playCalls, 1);
        engine.emitPlaying();
        await settle();
        expect(port.snapshot.playing, isTrue);
      });

      test('selesai sendiri: lagu yang gagal dilewati ke lagu berikutnya',
          () async {
        resolver.scripted['b'] = <Object>[
          const ExtractorException(ResolveFailureCause.httpForbidden),
          const ExtractorException(ResolveFailureCause.httpForbidden),
        ];
        await port.setQueue(tracks, autoplay: true);
        await settle();
        engine.emitPlaying();
        engine.emitState(
          const EngineState(
            playing: false,
            processing: EngineProcessing.completed,
          ),
        );
        await settle();
        expect(port.snapshot.currentTrack, same(tracks[2]));
        expect(port.snapshot.lastError, isNotNull);
        expect(port.snapshot.lastError!.skippedCount, 1);
        expect(resolver.resolveCalls.where((id) => id == 'b').length, 2);
      });

      test('selesai di ujung antrean: status completed, play() mengulang dari awal',
          () async {
        await port.setQueue(<Track>[tracks[0]], autoplay: true);
        await settle();
        engine.emitPlaying();
        engine.emitState(
          const EngineState(
            playing: false,
            processing: EngineProcessing.completed,
          ),
        );
        await settle();
        expect(port.snapshot.status, PlayerStatus.completed);
        expect(port.snapshot.playing, isFalse);
        await port.play();
        expect(engine.seekCalls.last, Duration.zero);
        expect(engine.playCalls, 2);
      });
    });

    group('interupsi (audio_session)', () {
      test('panggilan masuk menjeda lalu lanjut otomatis', () async {
        await port.setQueue(tracks, autoplay: true);
        await settle();
        engine.emitPlaying();
        await settle();
        session.emitInterruption(begin: true, kind: InterruptionKind.pause);
        await settle();
        expect(engine.pauseCalls, 1);
        engine.emitState(
          const EngineState(
            playing: false,
            processing: EngineProcessing.ready,
          ),
        );
        await settle();
        session.emitInterruption(begin: false, kind: InterruptionKind.pause);
        await settle();
        expect(engine.playCalls, 2);
      });

      test('jeda manual selama interupsi membatalkan lanjut otomatis',
          () async {
        await port.setQueue(tracks, autoplay: true);
        await settle();
        engine.emitPlaying();
        await settle();
        session.emitInterruption(begin: true, kind: InterruptionKind.pause);
        await settle();
        await port.pause();
        session.emitInterruption(begin: false, kind: InterruptionKind.pause);
        await settle();
        expect(engine.playCalls, 1);
      });

      test('duck mengecilkan volume lalu mengembalikan', () async {
        await port.setQueue(tracks, autoplay: true);
        await settle();
        session.emitInterruption(begin: true, kind: InterruptionKind.duck);
        await settle();
        expect(session.setActiveCalls, isNotEmpty);
        expect(engine.volumeCalls, <double>[0.3]);
        session.emitInterruption(begin: false, kind: InterruptionKind.duck);
        await settle();
        expect(engine.volumeCalls, <double>[0.3, 1.0]);
      });

      test('headset dicabut menjeda tanpa lanjut otomatis', () async {
        await port.setQueue(tracks, autoplay: true);
        await settle();
        engine.emitPlaying();
        await settle();
        session.emitNoisy();
        await settle();
        expect(engine.pauseCalls, 1);
        expect(engine.playCalls, 1);
      });
    });
  });
}
