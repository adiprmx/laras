/// Tes client LRCLIB (P7): /get, fallback /search, 404, 429, error
/// jaringan, dan respons rusak. Tanpa jaringan nyata: Dio memakai
/// adapter palsu dengan respons kalengan.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/features/lyrics/lrclib_client.dart';

/// Adapter HTTP palsu: respons kalengan per path, atau error.
class FakeLrclibAdapter implements HttpClientAdapter {
  FakeLrclibAdapter({this.bodyByPath = const <String, String>{}, this.error});

  final Map<String, String> bodyByPath;
  final DioException? error;

  /// Status per path (default 200 untuk path yang ada bodinya, 404 bila
  /// tidak ada).
  final Map<String, int> statusByPath = <String, int>{};

  final List<String> fetchedUrls = <String>[];
  final List<String> fetchedAgents = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchedUrls.add(options.uri.toString());
    fetchedAgents.add(
      options.headers['User-Agent'] as String? ?? '',
    );
    if (error != null) throw error!;
    final String path = options.uri.path;
    final int status = statusByPath[path] ??
        (bodyByPath.containsKey(path) ? 200 : 404);
    final String text = bodyByPath[path] ?? '{"message":"Not found"}';
    return ResponseBody.fromString(
      text,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const String kGetJson = '''
{
  "id": 123,
  "trackName": "Yellow",
  "artistName": "Coldplay",
  "albumName": "Parachutes",
  "duration": 266,
  "instrumental": false,
  "plainLyrics": "Look at the stars",
  "syncedLyrics": "[00:01.00]Look at the stars"
}
''';

const String kSearchJson = '''
[
  {"id": 1, "trackName": "Yellow", "artistName": "Coldplay",
   "duration": 100, "instrumental": false,
   "plainLyrics": "Salah durasi", "syncedLyrics": null},
  {"id": 2, "trackName": "Yellow", "artistName": "Coldplay",
   "duration": 266, "instrumental": false,
   "plainLyrics": "Durasi cocok", "syncedLyrics": null}
]
''';

Dio dioWith(FakeLrclibAdapter adapter) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://lrclib.net/api'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LrclibTrack.fromJson', () {
    test('record lengkap ter-parse', () {
      final LrclibTrack track = LrclibTrack.fromJson(
        jsonDecode(kGetJson) as Map<String, dynamic>,
      );
      expect(track.id, 123);
      expect(track.plainLyrics, 'Look at the stars');
      expect(track.syncedLyrics, '[00:01.00]Look at the stars');
      expect(track.instrumental, isFalse);
      expect(track.duration, const Duration(seconds: 266));
      expect(track.hasLyrics, isTrue);
    });

    test('lirik kosong dianggap tidak ada', () {
      final LrclibTrack track = LrclibTrack.fromJson(<String, dynamic>{
        'id': 9,
        'plainLyrics': '   ',
        'syncedLyrics': '',
        'instrumental': false,
      });
      expect(track.plainLyrics, isNull);
      expect(track.syncedLyrics, isNull);
      expect(track.hasLyrics, isFalse);
    });

    test('instrumental terbaca', () {
      final LrclibTrack track = LrclibTrack.fromJson(<String, dynamic>{
        'id': 9,
        'instrumental': true,
      });
      expect(track.instrumental, isTrue);
    });
  });

  group('LrclibClient.fetchLyrics', () {
    test('/get sukses mengembalikan lirik + mengirim User-Agent', () async {
      final FakeLrclibAdapter adapter = FakeLrclibAdapter(
        bodyByPath: <String, String>{'/api/get': kGetJson},
      );
      final LrclibClient client = LrclibClient(dio: dioWith(adapter));
      final LrclibTrack? track = await client.fetchLyrics(
        artist: 'Coldplay',
        title: 'Yellow',
        album: 'Parachutes',
        duration: const Duration(seconds: 266),
      );
      expect(track, isNotNull);
      expect(track!.id, 123);
      expect(track.plainLyrics, 'Look at the stars');
      expect(adapter.fetchedUrls.single, contains('artist_name=Coldplay'));
      expect(adapter.fetchedUrls.single, contains('track_name=Yellow'));
      expect(adapter.fetchedUrls.single, contains('album_name=Parachutes'));
      expect(adapter.fetchedUrls.single, contains('duration=266'));
      expect(adapter.fetchedAgents.single, kLrclibUserAgent);
    });

    test('/get 404 lalu /search memilih hasil yang durasinya cocok',
        () async {
      final FakeLrclibAdapter adapter = FakeLrclibAdapter(
        bodyByPath: <String, String>{'/api/search': kSearchJson},
      );
      adapter.statusByPath['/api/get'] = 404;
      final LrclibClient client = LrclibClient(dio: dioWith(adapter));
      final LrclibTrack? track = await client.fetchLyrics(
        artist: 'Coldplay',
        title: 'Yellow',
        duration: const Duration(seconds: 266),
      );
      expect(track, isNotNull);
      expect(track!.id, 2);
      expect(track.plainLyrics, 'Durasi cocok');
      expect(adapter.fetchedUrls, hasLength(2));
      expect(adapter.fetchedUrls[1], contains('/api/search'));
    });

    test('/get 404 + /search kosong mengembalikan null', () async {
      final FakeLrclibAdapter adapter = FakeLrclibAdapter(
        bodyByPath: <String, String>{'/api/search': '[]'},
      );
      adapter.statusByPath['/api/get'] = 404;
      final LrclibClient client = LrclibClient(dio: dioWith(adapter));
      expect(
        await client.fetchLyrics(artist: 'Tidak Ada', title: 'Tidak Ada'),
        isNull,
      );
    });

    test('429 melempar rateLimited', () async {
      final FakeLrclibAdapter adapter = FakeLrclibAdapter(
        bodyByPath: <String, String>{'/api/get': '{}'},
      );
      adapter.statusByPath['/api/get'] = 429;
      final LrclibClient client = LrclibClient(dio: dioWith(adapter));
      expect(
        () => client.fetchLyrics(artist: 'A', title: 'B'),
        throwsA(
          isA<LrclibException>().having(
            (LrclibException e) => e.kind,
            'kind',
            LrclibFailureKind.rateLimited,
          ),
        ),
      );
    });

    test('error koneksi melempar network', () async {
      final FakeLrclibAdapter adapter = FakeLrclibAdapter(
        error: DioException(
          requestOptions: RequestOptions(path: '/get'),
          type: DioExceptionType.connectionError,
          error: 'tidak ada internet',
        ),
      );
      final LrclibClient client = LrclibClient(dio: dioWith(adapter));
      expect(
        () => client.fetchLyrics(artist: 'A', title: 'B'),
        throwsA(
          isA<LrclibException>().having(
            (LrclibException e) => e.kind,
            'kind',
            LrclibFailureKind.network,
          ),
        ),
      );
    });

    test('respons /get bukan objek melempar invalidResponse', () async {
      final FakeLrclibAdapter adapter = FakeLrclibAdapter(
        bodyByPath: <String, String>{'/api/get': '[]'},
      );
      final LrclibClient client = LrclibClient(dio: dioWith(adapter));
      expect(
        () => client.fetchLyrics(artist: 'A', title: 'B'),
        throwsA(
          isA<LrclibException>().having(
            (LrclibException e) => e.kind,
            'kind',
            LrclibFailureKind.invalidResponse,
          ),
        ),
      );
    });
  });
}
