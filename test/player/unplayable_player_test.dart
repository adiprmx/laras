/// Tes penandaan lagu tidak bisa diputar di pemutar (P6, B4.7) +
/// penerusan saklar Hemat data (B8.1).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/l10n/generated/app_localizations_id.dart';
import 'package:laras/player/player.dart';
import 'package:laras/resilience/unplayable_marking.dart';

import 'fakes.dart';

class _FakeMarker implements UnplayableMarker {
  final Set<String> marked = <String>{};
  final List<String> markCalls = <String>[];
  final List<String> clearCalls = <String>[];

  @override
  Future<bool> isMarked(String songId) async => marked.contains(songId);

  @override
  Future<void> mark(String songId) async {
    markCalls.add(songId);
    marked.add(songId);
  }

  @override
  Future<void> clear(String songId) async {
    clearCalls.add(songId);
    marked.remove(songId);
  }
}

void main() {
  group('JustAudioPlayerPort unplayable (P6)', () {
    late FakeEngine engine;
    late FakeAudioResolver resolver;
    late FakeAudioSession session;
    late JustAudioPlayerPort port;
    late _FakeMarker marker;
    late List<Track> tracks;

    Future<void> settle([int ms = 20]) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    setUp(() {
      engine = FakeEngine();
      resolver = FakeAudioResolver();
      session = FakeAudioSession();
      marker = _FakeMarker();
      port = JustAudioPlayerPort(
        engine: engine,
        resolver: resolver,
        session: session,
      );
      port.unplayableMarker = marker;
      tracks = <Track>[testTrack('a'), testTrack('b'), testTrack('c')];
    });

    tearDown(() async {
      await port.dispose();
      await session.dispose();
    });

    test('gagal playability menandai lagu + error membawa cause', () async {
      resolver.scripted['a'] = <Object>[
        const ExtractorException(
          ResolveFailureCause.emptyResponse,
          isPlayabilityFailure: true,
        ),
      ];
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(marker.markCalls, contains('a'));
      expect(port.snapshot.status, PlayerStatus.error);
      expect(port.snapshot.lastError, isNotNull);
      expect(
        port.snapshot.lastError!.cause,
        ResolveFailureCause.emptyResponse,
      );
      expect(port.snapshot.lastError!.kind, PlaybackFailureKind.unplayable);
    });

    test('pesan error memakai pemetaan penyebab bila cause diketahui',
        () async {
      final AppLocalizations strings = AppLocalizationsId();
      resolver.scripted['a'] = <Object>[
        const ExtractorException(
          ResolveFailureCause.unknownPlayerHash,
          isPlayabilityFailure: true,
        ),
      ];
      await port.setQueue(tracks, autoplay: true);
      await settle();
      final PlaybackFailure failure = port.snapshot.lastError!;
      expect(
        playbackFailureMessage(strings, failure),
        strings.causeUnknownPlayerHash,
      );
    });

    test('gagal jaringan TIDAK menandai lagu', () async {
      resolver.scripted['a'] = <Object>[
        const ExtractorException(
          ResolveFailureCause.emptyResponse,
          isNetworkError: true,
        ),
      ];
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(marker.markCalls, isEmpty);
      expect(port.snapshot.lastError!.kind, PlaybackFailureKind.network);
    });

    test('gagal non-playability (parse) TIDAK menandai lagu', () async {
      resolver.scripted['a'] = <Object>[
        const ExtractorException(ResolveFailureCause.parseFailed),
      ];
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(marker.markCalls, isEmpty);
    });

    test('resolve berhasil membersihkan tanda', () async {
      marker.marked.add('a');
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(marker.clearCalls, contains('a'));
      expect(marker.marked, isNot(contains('a')));
    });

    test('rantai otomatis melewati lagu bertanda TANPA resolve', () async {
      marker.marked.add('b');
      await port.setQueue(tracks, autoplay: true);
      await settle();
      // Pramuat juga tidak me-resolve 'b'.
      expect(resolver.resolveCalls, isNot(contains('b')));
      expect(
        engine.sources.map((EngineSource s) => s.tag).toList(),
        <String>['a'],
      );
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
      expect(resolver.resolveCalls, isNot(contains('b')));
    });

    test('ketukan pengguna pada lagu bertanda TETAP mencoba resolve',
        () async {
      marker.marked.add('a');
      await port.setQueue(tracks, initialIndex: 0, autoplay: true);
      await settle();
      expect(resolver.resolveCalls, contains('a'));
      // Resolve berhasil -> tanda dibersihkan.
      expect(marker.clearCalls, contains('a'));
      expect(port.snapshot.currentTrack, same(tracks[0]));
    });

    test('saklar Hemat data diteruskan ke resolver', () async {
      port.dataSaver = true;
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(resolver.dataSaverFlags, isNotEmpty);
      expect(resolver.dataSaverFlags.every((bool f) => f), isTrue);
      port.dataSaver = false;
      resolver.dataSaverFlags.clear();
      resolver.resolveCalls.clear();
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(resolver.dataSaverFlags.every((bool f) => !f), isTrue);
    });

    test('tanpa marker, pemutar jalan normal (tanpa crash)', () async {
      port.unplayableMarker = null;
      resolver.scripted['a'] = <Object>[
        const ExtractorException(
          ResolveFailureCause.emptyResponse,
          isPlayabilityFailure: true,
        ),
      ];
      await port.setQueue(tracks, autoplay: true);
      await settle();
      expect(port.snapshot.status, PlayerStatus.error);
    });
  });
}
