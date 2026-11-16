/// Tes reproduksi insiden P0 (16 Nov 2026): demo P3 tidak bisa memutar
/// di HP owner - lagu diketuk, mini-player tampil dengan ikon putar, tanpa
/// bunyi dan tanpa penjelasan error apa pun.
///
/// Tes-tes ini mem-pin perilaku pemutar untuk tiap mode gagal (timeout,
/// jaringan putus, tidak bisa diputar, setSources gagal, semua lagu gagal)
/// dan membuktikan jalur lokal (file di perangkat, P5) tidak pernah
/// menyentuh resolver jaringan.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/player/player.dart';

import 'fakes.dart';

void main() {
  group('P0 reproduksi mode gagal', () {
    late FakeEngine engine;
    late FakeAudioResolver resolver;
    late FakeAudioSession session;
    late JustAudioPlayerPort port;
    late List<Track> tracks;

    /// Biarkan rantai async yang tidak ditunggu (pramuat, re-resolve,
    /// rantai lewati) selesai berjalan.
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

    test('insiden P0: resolve gagal -> status error + lagu tetap tampil', () async {
      // Akar insiden: ekstraksi base.js gagal (unknownPlayerHash) sehingga
      // resolve melempar sebelum request player.
      resolver.results['a'] = const ExtractorException(
        ResolveFailureCause.unknownPlayerHash,
        detail: 'ekstraksi base.js gagal',
      );
      await port.setQueue(tracks, autoplay: true);
      await settle();
      // Persis seperti screenshot owner: lagu yang diketuk tetap menjadi
      // lagu saat ini, tidak ada bunyi, status error.
      expect(port.snapshot.status, PlayerStatus.error);
      expect(port.snapshot.currentTrack, same(tracks[0]));
      expect(port.snapshot.playing, isFalse);
      expect(port.snapshot.lastError, isNotNull);
      expect(port.snapshot.lastError!.kind, PlaybackFailureKind.unplayable);
      expect(port.snapshot.lastError!.trackTitle, 'Lagu a');
      expect(engine.playCalls, 0);
    });

    test('kegagalan muat awal TIDAK auto-skip ke lagu berikutnya', () async {
      resolver.results['a'] = const ExtractorException(
        ResolveFailureCause.httpForbidden,
      );
      await port.setQueue(tracks, autoplay: true);
      await settle();
      // Pengguna memilih lagu itu: tampilkan error + retry, jangan diam-diam
      // pindah lagu.
      expect(port.snapshot.status, PlayerStatus.error);
      expect(port.snapshot.currentTrack, same(tracks[0]));
      expect(resolver.resolveCalls, <String>['a']);
    });

    test('resolve timeout diklasifikasikan sebagai timeout', () async {
      resolver.results['a'] = const ExtractorException(
        ResolveFailureCause.emptyResponse,
        isTimeout: true,
      );
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(port.snapshot.status, PlayerStatus.error);
      expect(port.snapshot.lastError!.kind, PlaybackFailureKind.timeout);
    });

    test('resolve gagal jaringan diklasifikasikan sebagai jaringan', () async {
      resolver.results['a'] = const ExtractorException(
        ResolveFailureCause.emptyResponse,
        isNetworkError: true,
      );
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(port.snapshot.status, PlayerStatus.error);
      expect(port.snapshot.lastError!.kind, PlaybackFailureKind.network);
    });

    test('timeout didahulukan atas jaringan bila keduanya diset', () async {
      resolver.results['a'] = const ExtractorException(
        ResolveFailureCause.emptyResponse,
        isNetworkError: true,
        isTimeout: true,
      );
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(port.snapshot.lastError!.kind, PlaybackFailureKind.timeout);
    });

    test('setSources gagal -> error tidak bisa diputar', () async {
      engine.failNextCallWith = StateError('gagal memuat sumber');
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(port.snapshot.status, PlayerStatus.error);
      expect(port.snapshot.lastError!.kind, PlaybackFailureKind.unplayable);
      expect(port.snapshot.currentTrack, same(tracks[0]));
    });

    test('retry lewat play() memuat ulang dan berhasil', () async {
      resolver.scripted['a'] = <Object>[
        const ExtractorException(ResolveFailureCause.emptyResponse, isTimeout: true),
      ];
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(port.snapshot.status, PlayerStatus.error);
      expect(port.snapshot.lastError!.kind, PlaybackFailureKind.timeout);
      // Pengguna menekan "Coba lagi": resolve kedua sukses (skrip habis,
      // resolver kembali ke hasil default).
      await port.play();
      await settle();
      expect(port.snapshot.lastError, isNull);
      expect(engine.playCalls, 1);
      engine.emitPlaying();
      await settle();
      expect(port.snapshot.status, PlayerStatus.ready);
      expect(port.snapshot.playing, isTrue);
    });

    test('semua lagu gagal (error tengah lagu) -> error setelah rantai lewati', () async {
      // Pramuat 'b' gagal diam-diam (entri skrip pertama), lalu 'b' gagal
      // lagi saat gilirannya di rantai lewati (entri kedua).
      resolver.scripted['b'] = <Object>[
        const ExtractorException(ResolveFailureCause.httpForbidden),
        const ExtractorException(ResolveFailureCause.httpForbidden),
      ];
      resolver.scripted['c'] = <Object>[
        const ExtractorException(ResolveFailureCause.httpForbidden),
      ];
      await port.setQueue(tracks, autoplay: true);
      await settle();
      engine.emitPlaying();
      await settle();
      expect(port.snapshot.status, PlayerStatus.ready);
      // Mulai sekarang 'a' gagal di jaringan: re-resolve 3x gagal.
      resolver.results['a'] = const ExtractorException(
        ResolveFailureCause.emptyResponse,
        isNetworkError: true,
      );
      engine.emitError();
      await settle(100);
      // Rantai lewati mencoba b lalu c, keduanya gagal: status error.
      expect(port.snapshot.status, PlayerStatus.error);
      expect(port.snapshot.playing, isFalse);
      expect(resolver.resolveCalls, containsAll(<String>['a', 'b', 'c']));
      // Jenis error berasal dari kegagalan lagu yang sedang diputar.
      expect(port.snapshot.lastError!.kind, PlaybackFailureKind.network);
      // Lagu terakhir yang dicoba tetap menjadi lagu saat ini.
      expect(port.snapshot.currentTrack, same(tracks[2]));
    });
  });

  group('P0 jalur lokal (P5)', () {
    late FakeEngine engine;
    late FakeAudioResolver resolver;
    late FakeAudioSession session;
    late JustAudioPlayerPort port;

    Future<void> settle([int ms = 20]) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    const Track localTrack = Track(
      videoId: 'lokal-1',
      title: 'Lagu Lokal',
      artist: 'Artis Lokal',
      localPath: '/storage/emulated/0/Music/lagu.mp3',
    );

    setUp(() {
      engine = FakeEngine();
      resolver = FakeAudioResolver();
      session = FakeAudioSession();
      port = JustAudioPlayerPort(
        engine: engine,
        resolver: resolver,
        session: session,
      );
    });

    tearDown(() async {
      await port.dispose();
      await session.dispose();
    });

    test('file lokal diputar tanpa memanggil resolver sama sekali', () async {
      await port.setQueue(<Track>[localTrack], autoplay: true);
      await settle();
      expect(resolver.resolveCalls, isEmpty);
      expect(engine.setSourcesCalls, hasLength(1));
      final EngineSource source = engine.setSourcesCalls.single.$1.single;
      expect(source.uri, Uri.file('/storage/emulated/0/Music/lagu.mp3'));
      expect(source.tag, 'lokal-1');
      expect(engine.playCalls, 1);
      engine.emitPlaying();
      await settle();
      expect(port.snapshot.status, PlayerStatus.ready);
      expect(port.snapshot.playing, isTrue);
    });

    test('error engine lagu lokal tidak memicu resolve jaringan', () async {
      await port.setQueue(<Track>[localTrack], autoplay: true);
      await settle();
      engine.emitPlaying();
      await settle();
      engine.emitError();
      await settle(100);
      // Gagalnya lokal dilaporkan apa adanya; tidak ada re-resolve,
      // tidak ada retry klien, tidak ada panggilan jaringan.
      expect(resolver.resolveCalls, isEmpty);
      expect(port.snapshot.status, PlayerStatus.error);
      expect(port.snapshot.lastError!.kind, PlaybackFailureKind.unplayable);
    });
  });
}
