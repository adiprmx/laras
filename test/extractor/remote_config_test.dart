import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adapter HTTP palsu: mengembalikan respons kalengan atau melempar.
/// [statusByUrl] memungkinkan perilaku berbeda per URL (untuk tes
/// fallback URL utama -> URL cadangan).
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter({this.body, this.statusCode = 200, this.error, this.statusByUrl});

  final String? body;
  final int statusCode;
  final DioException? error;
  final Map<String, int>? statusByUrl;
  int fetchCount = 0;
  final List<String> fetchedUrls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount++;
    fetchedUrls.add(options.uri.toString());
    if (error != null) throw error!;
    final int status = statusByUrl?[options.uri.toString()] ?? statusCode;
    final String text = body ?? '{}';
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

const String kValidConfigJson = '''
{
  "version": 1,
  "ttlSeconds": 21600,
  "clients": [
    {"name": "WEB_REMIX", "version": "1.20261110.04.00",
     "userAgent": "Mozilla/5.0-test", "clientId": "67"},
    {"name": "MWEB", "version": "2.20260708.05.00",
     "userAgent": "Mozilla/5.0-mobile-test", "clientId": "2"}
  ],
  "playerHashes": {"fad7e4e9": {"signatureTimestamp": 20767}},
  "canaryVideoIds": ["hhn-nGSuenM", "qkC4waEZVt4"]
}
''';

Dio dioWith(FakeAdapter adapter) {
  final Dio dio = Dio();
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  group('RemotePlayerConfig.tryParse', () {
    test('config valid ter-parse lengkap', () {
      final RemotePlayerConfig? config = RemotePlayerConfig.tryParse(
        jsonDecode(kValidConfigJson) as Map<String, dynamic>,
        fetchedAt: DateTime.now(),
      );
      expect(config, isNotNull);
      expect(config!.clients.length, 2);
      expect(config.clients.first.name, 'WEB_REMIX');
      expect(config.clients.first.version, '1.20261110.04.00');
      expect(config.clients.first.clientId, '67');
      expect(config.playerHashes['fad7e4e9'], 20767);
      expect(config.canaryVideoIds, <String>['hhn-nGSuenM', 'qkC4waEZVt4']);
      expect(config.isRemote, isTrue);
    });

    test('tanpa clients -> null', () {
      expect(
        RemotePlayerConfig.tryParse(
          <String, dynamic>{'version': 1},
          fetchedAt: DateTime.now(),
        ),
        isNull,
      );
    });

    test('client tanpa version -> null', () {
      expect(
        RemotePlayerConfig.tryParse(
          <String, dynamic>{
            'clients': <dynamic>[
              <String, dynamic>{'name': 'WEB_REMIX', 'userAgent': 'x', 'clientId': '67'},
            ],
          },
          fetchedAt: DateTime.now(),
        ),
        isNull,
      );
    });

    test('canary kosong -> pakai daftar bawaan', () {
      final RemotePlayerConfig? config = RemotePlayerConfig.tryParse(
        <String, dynamic>{
          'clients': <dynamic>[
            <String, dynamic>{
              'name': 'WEB_REMIX',
              'version': '1.0',
              'userAgent': 'x',
              'clientId': '67',
            },
          ],
        },
        fetchedAt: DateTime.now(),
      );
      expect(config!.canaryVideoIds.length, 5);
    });

    test('defaults() memakai nilai hasil probe', () {
      final RemotePlayerConfig config = RemotePlayerConfig.defaults();
      expect(config.isRemote, isFalse);
      expect(config.clients.first.name, 'WEB_REMIX');
      expect(config.clients.first.version, '1.20261110.04.00');
      expect(config.clients[1].name, 'MWEB');
      expect(config.clients[2].name, 'ANDROID_VR');
      expect(config.clients[2].requiresScript, isFalse);
      expect(config.playerHashes['fad7e4e9'], 20767);
      expect(config.canaryVideoIds, contains('hhn-nGSuenM'));
    });

    test('requiresScript ter-parse; hilang berarti true (P0)', () {
      final RemotePlayerConfig? config = RemotePlayerConfig.tryParse(
        <String, dynamic>{
          'clients': <dynamic>[
            <String, dynamic>{
              'name': 'WEB_REMIX',
              'version': '1.0',
              'userAgent': 'x',
              'clientId': '67',
            },
            <String, dynamic>{
              'name': 'ANDROID_VR',
              'version': '1.65.10',
              'userAgent': 'y',
              'clientId': '14',
              'requiresScript': false,
            },
          ],
        },
        fetchedAt: DateTime.now(),
      );
      expect(config, isNotNull);
      expect(config!.clients[0].requiresScript, isTrue);
      expect(config.clients[1].requiresScript, isFalse);
    });
  });

  group('RemoteConfigLoader', () {
    test('fetch sukses -> config remote + tersimpan di cache', () async {
      final FakeAdapter adapter = FakeAdapter(body: kValidConfigJson);
      final RemoteConfigLoader loader = RemoteConfigLoader(
        dio: dioWith(adapter),
        prefs: prefs,
      );
      final RemotePlayerConfig config = await loader.refresh(force: true);
      expect(config.isRemote, isTrue);
      expect(config.clients.first.version, '1.20261110.04.00');
      expect(prefs.getString(kRemoteConfigCacheKey), isNotNull);
      expect(adapter.fetchCount, 1);
    });

    test('fetch gagal -> fallback cache terakhir', () async {
      // Isi cache dulu.
      final RemoteConfigLoader seeder = RemoteConfigLoader(
        dio: dioWith(FakeAdapter(body: kValidConfigJson)),
        prefs: prefs,
      );
      await seeder.refresh(force: true);
      // Lalu fetch gagal.
      final DioException networkError = DioException(
        requestOptions: RequestOptions(path: kRemoteConfigUrl),
        type: DioExceptionType.connectionError,
      );
      final RemoteConfigLoader loader = RemoteConfigLoader(
        dio: dioWith(FakeAdapter(error: networkError)),
        prefs: prefs,
      );
      final RemotePlayerConfig config = await loader.refresh(force: true);
      expect(config.isRemote, isTrue);
      expect(config.clients.first.version, '1.20261110.04.00');
    });

    test('fetch gagal tanpa cache -> defaults', () async {
      final DioException networkError = DioException(
        requestOptions: RequestOptions(path: kRemoteConfigUrl),
        type: DioExceptionType.connectionError,
      );
      final RemoteConfigLoader loader = RemoteConfigLoader(
        dio: dioWith(FakeAdapter(error: networkError)),
        prefs: prefs,
      );
      final RemotePlayerConfig config = await loader.refresh(force: true);
      expect(config.isRemote, isFalse);
      expect(config.clients.first.name, 'WEB_REMIX');
    });

    test('respons bukan JSON valid -> fallback defaults', () async {
      final RemoteConfigLoader loader = RemoteConfigLoader(
        dio: dioWith(FakeAdapter(body: '{"clients": "bukan list"}')),
        prefs: prefs,
      );
      final RemotePlayerConfig config = await loader.refresh(force: true);
      expect(config.isRemote, isFalse);
    });

    test('URL utama 404 -> pakai URL cadangan tag', () async {
      final FakeAdapter adapter = FakeAdapter(
        body: kValidConfigJson,
        statusByUrl: <String, int>{kRemoteConfigUrl: 404},
      );
      final RemoteConfigLoader loader = RemoteConfigLoader(
        dio: dioWith(adapter),
        prefs: prefs,
      );
      final RemotePlayerConfig config = await loader.refresh(force: true);
      expect(config.isRemote, isTrue);
      expect(config.clients.first.version, '1.20261110.04.00');
      expect(adapter.fetchedUrls, <String>[
        kRemoteConfigUrl,
        kRemoteConfigFallbackUrl,
      ]);
    });

    test('kedua URL gagal -> fallback cache lalu bawaan', () async {
      final DioException networkError = DioException(
        requestOptions: RequestOptions(path: kRemoteConfigUrl),
        type: DioExceptionType.connectionError,
      );
      final RemoteConfigLoader loader = RemoteConfigLoader(
        dio: dioWith(FakeAdapter(error: networkError)),
        prefs: prefs,
      );
      final RemotePlayerConfig config = await loader.refresh(force: true);
      expect(config.isRemote, isFalse);
    });

    test('single-flight: dua refresh bersamaan -> satu fetch', () async {
      final FakeAdapter adapter = FakeAdapter(body: kValidConfigJson);
      final RemoteConfigLoader loader = RemoteConfigLoader(
        dio: dioWith(adapter),
        prefs: prefs,
      );
      await Future.wait(<Future<RemotePlayerConfig>>[
        loader.refresh(force: true),
        loader.refresh(force: true),
      ]);
      expect(adapter.fetchCount, 1);
    });
  });
}
