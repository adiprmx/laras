import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/player/player.dart';

import 'fakes.dart';

/// Cache streaming palsu: file dikendalikan tes.
class FakePlaybackCache implements PlaybackCache {
  final Map<String, File> files = <String, File>{};
  final List<String> fileForCalls = <String>[];
  final List<(String, String, int, String)> noted =
      <(String, String, int, String)>[];
  final List<String> invalidated = <String>[];

  @override
  Future<File?> fileFor(String videoId) async {
    fileForCalls.add(videoId);
    return files[videoId];
  }

  @override
  void noteResolved(String videoId, String url, int itag, String mimeType) {
    noted.add((videoId, url, itag, mimeType));
  }

  @override
  Future<void> invalidate(String videoId) async {
    invalidated.add(videoId);
    files.remove(videoId);
  }
}

void main() {
  group('JustAudioPlayerPort + cache streaming (P5)', () {
    late FakeEngine engine;
    late FakeAudioResolver resolver;
    late FakeAudioSession session;
    late FakePlaybackCache cache;
    late JustAudioPlayerPort port;
    late Directory temp;

    Future<void> settle([int ms = 20]) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('laras_player_cache');
      engine = FakeEngine();
      resolver = FakeAudioResolver();
      session = FakeAudioSession();
      cache = FakePlaybackCache();
      port = JustAudioPlayerPort(
        engine: engine,
        resolver: resolver,
        session: session,
        playbackCache: cache,
      );
    });

    tearDown(() async {
      await port.dispose();
      await session.dispose();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('lagu di-cache diputar dari file tanpa memanggil resolver', () async {
      // Resolver dibuat gagal total: bila dipanggil, tes ini gagal
      // lewat jalur load, bukan hanya lewat hitungan panggilan.
      resolver.scripted['aaa11111111'] = <Object>[
        const ExtractorException(ResolveFailureCause.emptyResponse),
      ];
      final File cached = File('${temp.path}/aaa11111111_251.opus')
        ..writeAsBytesSync(List<int>.filled(100, 1));
      cache.files['aaa11111111'] = cached;

      await port.setQueue(
        <Track>[testTrack('aaa11111111')],
        autoplay: true,
      );
      await settle();

      expect(resolver.resolveCalls, isEmpty);
      expect(cache.fileForCalls, <String>['aaa11111111']);
      expect(engine.setSourcesCalls, hasLength(1));
      final EngineSource source = engine.setSourcesCalls.single.$1.single;
      expect(source.uri, Uri.file(cached.path));
      expect(source.tag, 'aaa11111111');
      expect(engine.playCalls, 1);
      engine.emitPlaying();
      await settle();
      expect(port.snapshot.status, PlayerStatus.ready);
      expect(port.snapshot.playing, isTrue);
    });

    test('resolve jaringan mencatat ke cache (noteResolved)', () async {
      await port.setQueue(
        <Track>[testTrack('aaa11111111')],
        autoplay: true,
      );
      await settle();

      expect(resolver.resolveCalls, <String>['aaa11111111']);
      expect(cache.noted, hasLength(1));
      final (String, String, int, String) note = cache.noted.single;
      expect(note.$1, 'aaa11111111');
      expect(note.$2, 'https://example.invalid/audio/aaa11111111');
      expect(note.$3, 140);
      expect(note.$4, 'audio/mp4');
      // Sumber engine adalah URL jaringan (cache kosong).
      final EngineSource source = engine.setSourcesCalls.single.$1.single;
      expect(
        source.uri,
        Uri.parse('https://example.invalid/audio/aaa11111111'),
      );
    });

    test('cache kosong jatuh ke resolve (fileFor null)', () async {
      await port.setQueue(
        <Track>[testTrack('aaa11111111')],
        autoplay: true,
      );
      await settle();

      expect(cache.fileForCalls, <String>['aaa11111111']);
      expect(resolver.resolveCalls, <String>['aaa11111111']);
      expect(engine.setSourcesCalls, hasLength(1));
    });

    test('error engine pada lagu dari cache: entri dihapus, re-resolve segar', () async {
      final File cached = File('${temp.path}/aaa11111111_251.opus')
        ..writeAsBytesSync(List<int>.filled(100, 1));
      cache.files['aaa11111111'] = cached;
      await port.setQueue(
        <Track>[testTrack('aaa11111111')],
        autoplay: true,
      );
      await settle();
      engine.emitPlaying();
      await settle();
      expect(resolver.resolveCalls, isEmpty);

      engine.emitError();
      await settle(200);

      // Entri cache yang rusak dihapus sebelum re-resolve...
      expect(cache.invalidated, <String>['aaa11111111']);
      expect(cache.files.containsKey('aaa11111111'), isFalse);
      // ...lalu re-resolve mengambil URL segar dari jaringan.
      expect(resolver.resolveCalls, <String>['aaa11111111']);
      expect(engine.setSourcesCalls, hasLength(2));
      final EngineSource second = engine.setSourcesCalls[1].$1.single;
      expect(
        second.uri,
        Uri.parse('https://example.invalid/audio/aaa11111111'),
      );
    });

    test('lagu lokal tidak pernah menyentuh cache maupun resolver (P0)', () async {
      const Track localTrack = Track(
        videoId: 'aaa11111111',
        title: 'Lagu Lokal',
        localPath: '/storage/emulated/0/Music/lagu.mp3',
      );
      // Cache punya file untuk videoId yang sama: tetap tidak dipakai.
      final File cached = File('${temp.path}/aaa11111111_251.opus')
        ..writeAsBytesSync(List<int>.filled(100, 1));
      cache.files['aaa11111111'] = cached;

      await port.setQueue(<Track>[localTrack], autoplay: true);
      await settle();

      expect(cache.fileForCalls, isEmpty);
      expect(resolver.resolveCalls, isEmpty);
      final EngineSource source = engine.setSourcesCalls.single.$1.single;
      expect(source.uri, Uri.file('/storage/emulated/0/Music/lagu.mp3'));
    });

    test('tanpa cache (null): perilaku resolve seperti sebelum P5', () async {
      // Port kedua dengan engine/resolver baru (dispose port pertama
      // ikut menutup engine-nya, jadi tidak bisa dipakai ulang).
      final FakeEngine engine2 = FakeEngine();
      final FakeAudioResolver resolver2 = FakeAudioResolver();
      final JustAudioPlayerPort port2 = JustAudioPlayerPort(
        engine: engine2,
        resolver: resolver2,
        session: session,
      );
      addTearDown(() async {
        await port2.dispose();
      });
      await port2.setQueue(
        <Track>[testTrack('aaa11111111')],
        autoplay: true,
      );
      await settle();

      expect(resolver2.resolveCalls, <String>['aaa11111111']);
      final EngineSource source = engine2.setSourcesCalls.single.$1.single;
      expect(
        source.uri,
        Uri.parse('https://example.invalid/audio/aaa11111111'),
      );
    });
  });
}
