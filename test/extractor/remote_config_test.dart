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

  group('RemotePlayerConfig.tryParse batas ukuran (R1-L1)', () {
    Map<String, dynamic> clientJson({String? userAgent, String? name}) {
      return <String, dynamic>{
        'name': name ?? 'WEB_REMIX',
        'version': '1.0',
        'userAgent': userAgent ?? 'x',
        'clientId': '67',
      };
    }

    test('11 client -> seluruh config ditolak', () {
      expect(
        RemotePlayerConfig.tryParse(
          <String, dynamic>{
            'clients': <dynamic>[
              for (int i = 0; i < 11; i++) clientJson(name: 'C$i'),
            ],
          },
          fetchedAt: DateTime.now(),
        ),
        isNull,
      );
    });

    test('10 client (tepat di batas) diterima', () {
      final RemotePlayerConfig? config = RemotePlayerConfig.tryParse(
        <String, dynamic>{
          'clients': <dynamic>[
            for (int i = 0; i < 10; i++) clientJson(name: 'C$i'),
          ],
        },
        fetchedAt: DateTime.now(),
      );
      expect(config, isNotNull);
      expect(config!.clients.length, 10);
    });

    test('string client 201 karakter -> ditolak; 200 diterima', () {
      expect(
        RemotePlayerConfig.tryParse(
          <String, dynamic>{
            'clients': <dynamic>[
              clientJson(userAgent: 'a' * 201),
            ],
          },
          fetchedAt: DateTime.now(),
        ),
        isNull,
      );
      final RemotePlayerConfig? ok = RemotePlayerConfig.tryParse(
        <String, dynamic>{
          'clients': <dynamic>[
            clientJson(userAgent: 'a' * 200),
          ],
        },
        fetchedAt: DateTime.now(),
      );
      expect(ok, isNotNull);
    });

    test('101 hash player -> ditolak; 100 diterima', () {
      expect(
        RemotePlayerConfig.tryParse(
          <String, dynamic>{
            'clients': <dynamic>[clientJson()],
            'playerHashes': <String, dynamic>{
              for (int i = 0; i < 101; i++) 'hash$i': 1,
            },
          },
          fetchedAt: DateTime.now(),
        ),
        isNull,
      );
      final RemotePlayerConfig? ok = RemotePlayerConfig.tryParse(
        <String, dynamic>{
          'clients': <dynamic>[clientJson()],
          'playerHashes': <String, dynamic>{
            for (int i = 0; i < 100; i++) 'hash$i': 1,
          },
        },
        fetchedAt: DateTime.now(),
      );
      expect(ok, isNotNull);
      expect(ok!.playerHashes.length, 100);
    });

    test('60 ID kanari -> dipotong ke 50 (bukan ditolak)', () {
      final RemotePlayerConfig? config = RemotePlayerConfig.tryParse(
        <String, dynamic>{
          'clients': <dynamic>[clientJson()],
          'canaryVideoIds': <dynamic>[
            for (int i = 0; i < 60; i++) 'vid${i.toString().padLeft(8, '0')}',
          ],
        },
        fetchedAt: DateTime.now(),
      );
      expect(config, isNotNull);
      expect(config!.canaryVideoIds.length, 50);
      expect(config.canaryVideoIds.first, 'vid00000000');
      expect(config.canaryVideoIds.last, 'vid00000049');
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

    test('JSON List dari server -> fallback defaults, bukan TypeError',
        () async {
      // R1-L1: `jsonDecode(...) as Map` lama melempar TypeError yang
      // tidak ditangkap _fetchAndStore -> unhandled async error lewat
      // unawaited(_refresh(...)).
      final RemoteConfigLoader loader = RemoteConfigLoader(
        dio: dioWith(FakeAdapter(body: '[1, 2, 3]')),
        prefs: prefs,
      );
      final RemotePlayerConfig config = await loader.refresh(force: true);
      expect(config.isRemote, isFalse);
    });

    test('config valid tapi > 4 MB -> ditolak cap, fallback defaults',
        () async {
      // Diskriminan: tanpa cap streaming, config ini VALID (padding
      // diabaikan tryParse) dan isRemote akan true. Cap yang bekerja
      // menolaknya sebelum parse -> fallback bawaan.
      final Map<String, dynamic> big =
          jsonDecode(kValidConfigJson) as Map<String, dynamic>;
      big['padding'] = 'x' * (ResponseLimits.remoteConfigBytes + 1);
      final RemoteConfigLoader loader = RemoteConfigLoader(
        dio: dioWith(FakeAdapter(body: jsonEncode(big))),
        prefs: prefs,
      );
      final RemotePlayerConfig config = await loader.refresh(force: true);
      expect(config.isRemote, isFalse);
      expect(config.clients.first.name, 'WEB_REMIX');
    });
  });
}
