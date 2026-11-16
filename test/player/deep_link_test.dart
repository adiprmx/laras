/// Tes tautan dalam (P7, MUST #13): parsing videoId dari berbagai pola
/// URL + service membuka lagu lewat resolver dan port.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/player/player.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseYouTubeVideoId', () {
    test('youtu.be/<id>', () {
      expect(
        parseYouTubeVideoId(Uri.parse('https://youtu.be/dQw4w9WgXcQ')),
        'dQw4w9WgXcQ',
      );
    });

    test('youtu.be dengan query tambahan', () {
      expect(
        parseYouTubeVideoId(
          Uri.parse('https://youtu.be/dQw4w9WgXcQ?si=abc123&t=42'),
        ),
        'dQw4w9WgXcQ',
      );
    });

    test('youtube.com/watch?v=', () {
      expect(
        parseYouTubeVideoId(
          Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        ),
        'dQw4w9WgXcQ',
      );
      expect(
        parseYouTubeVideoId(
          Uri.parse('https://youtube.com/watch?v=dQw4w9WgXcQ&list=PL123'),
        ),
        'dQw4w9WgXcQ',
      );
    });

    test('music.youtube.com/watch?v=', () {
      expect(
        parseYouTubeVideoId(
          Uri.parse('https://music.youtube.com/watch?v=dQw4w9WgXcQ'),
        ),
        'dQw4w9WgXcQ',
      );
    });

    test('youtube.com/shorts/<id>', () {
      expect(
        parseYouTubeVideoId(
          Uri.parse('https://youtube.com/shorts/dQw4w9WgXcQ'),
        ),
        'dQw4w9WgXcQ',
      );
    });

    test('id 11 karakter dengan - dan _ valid', () {
      expect(
        parseYouTubeVideoId(Uri.parse('https://youtu.be/Ab-_-Cd_Ef1')),
        'Ab-_-Cd_Ef1',
      );
    });

    test('host lain ditolak', () {
      expect(
        parseYouTubeVideoId(Uri.parse('https://example.com/watch?v=dQw4w9WgXcQ')),
        isNull,
      );
      expect(
        parseYouTubeVideoId(Uri.parse('https://youtu.be.evil.com/dQw4w9WgXcQ')),
        isNull,
      );
    });

    test('id terlalu pendek/panjang ditolak', () {
      expect(parseYouTubeVideoId(Uri.parse('https://youtu.be/abc')), isNull);
      expect(
        parseYouTubeVideoId(Uri.parse('https://youtu.be/dQw4w9WgXcQ12')),
        isNull,
      );
    });

    test('watch tanpa v ditolak', () {
      expect(
        parseYouTubeVideoId(Uri.parse('https://youtube.com/watch')),
        isNull,
      );
      expect(
        parseYouTubeVideoId(Uri.parse('https://youtube.com/playlist?list=PL1')),
        isNull,
      );
    });

    test('youtu.be tanpa segmen ditolak', () {
      expect(parseYouTubeVideoId(Uri.parse('https://youtu.be/')), isNull);
      expect(parseYouTubeVideoId(Uri.parse('https://youtu.be')), isNull);
    });

    test('skema non-http ditolak', () {
      expect(
        parseYouTubeVideoId(Uri.parse('ftp://youtu.be/dQw4w9WgXcQ')),
        isNull,
      );
    });
  });

  group('DeepLinkService', () {
    test('tautan valid membuka lagu + autoplay', () async {
      final FakeAudioResolver resolver = FakeAudioResolver();
      final FakeAudioPlayerPort port = FakeAudioPlayerPort();
      final StreamController<String> links = StreamController<String>();
      final DeepLinkService service = DeepLinkService(
        links: links.stream,
        resolver: resolver,
        port: port,
      );
      final List<DeepLinkOutcome> outcomes = <DeepLinkOutcome>[];
      service.outcomes.listen(outcomes.add);
      service.start();

      links.add('https://youtu.be/dQw4w9WgXcQ');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(resolver.resolveCalls, <String>['dQw4w9WgXcQ']);
      expect(port.setQueueCalls, hasLength(1));
      final (List<Track>, int, bool) call = port.setQueueCalls.single;
      expect(call.$1, hasLength(1));
      expect(call.$1.single.videoId, 'dQw4w9WgXcQ');
      expect(call.$1.single.title, 'Lagu dQw4w9WgXcQ');
      expect(call.$2, 0);
      expect(call.$3, isTrue);
      expect(outcomes, <DeepLinkOutcome>[DeepLinkOutcome.opened]);
      expect(service.lastOutcome, DeepLinkOutcome.opened);
      await service.dispose();
      await links.close();
      await port.dispose();
    });

    test('tautan tidak valid menghasilkan failed tanpa resolve', () async {
      final FakeAudioResolver resolver = FakeAudioResolver();
      final FakeAudioPlayerPort port = FakeAudioPlayerPort();
      final DeepLinkService service = DeepLinkService(
        links: const Stream<String>.empty(),
        resolver: resolver,
        port: port,
      );
      final List<DeepLinkOutcome> outcomes = <DeepLinkOutcome>[];
      service.outcomes.listen(outcomes.add);

      final DeepLinkOutcome result = await service.handleLink(
        'https://example.com/bukan-youtube',
      );
      expect(result, DeepLinkOutcome.failed);
      expect(resolver.resolveCalls, isEmpty);
      expect(port.setQueueCalls, isEmpty);
      expect(outcomes, <DeepLinkOutcome>[DeepLinkOutcome.failed]);
      await service.dispose();
      await port.dispose();
    });

    test('resolve gagal menghasilkan failed', () async {
      final FakeAudioResolver resolver = FakeAudioResolver();
      resolver.results['dQw4w9WgXcQ'] = Exception('jaringan putus');
      final FakeAudioPlayerPort port = FakeAudioPlayerPort();
      final DeepLinkService service = DeepLinkService(
        links: const Stream<String>.empty(),
        resolver: resolver,
        port: port,
      );
      final DeepLinkOutcome result = await service.handleLink(
        'https://youtu.be/dQw4w9WgXcQ',
      );
      expect(result, DeepLinkOutcome.failed);
      expect(port.setQueueCalls, isEmpty);
      await service.dispose();
      await port.dispose();
    });

    test('judul resolve null jatuh ke videoId (jujur, bukan karangan)',
        () async {
      final FakeAudioResolver resolver = FakeAudioResolver();
      resolver.results['dQw4w9WgXcQ'] = ResolvedAudio(
        videoId: 'dQw4w9WgXcQ',
        url: 'https://example.invalid/audio',
        itag: 140,
        mimeType: 'audio/mp4',
        bitrate: 128000,
        clientName: 'WEB_REMIX',
        resolveDuration: const Duration(milliseconds: 10),
      );
      final FakeAudioPlayerPort port = FakeAudioPlayerPort();
      final DeepLinkService service = DeepLinkService(
        links: const Stream<String>.empty(),
        resolver: resolver,
        port: port,
      );
      await service.handleLink('https://youtu.be/dQw4w9WgXcQ');
      expect(port.setQueueCalls.single.$1.single.title, 'dQw4w9WgXcQ');
      await service.dispose();
      await port.dispose();
    });
  });
}
