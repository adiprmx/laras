/// Tes layanan status (P6, tugas 1/3/4): cek kanari harian, persistensi,
/// dan "Periksa pembaruan".
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/canary.dart';
import 'package:laras/extractor/errors.dart';
import 'package:laras/extractor/remote_config.dart';
import 'package:laras/resilience/service_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../player/fakes.dart';

/// 5 id kanari uji (ambang >50% butuh total >= 5 dalam 1 jam).
const List<String> kTestCanaryIds = <String>[
  'aaa111aaa11',
  'bbb222bbb22',
  'ccc333ccc33',
  'ddd444ddd44',
  'eee555eee55',
];

const String kConfigA = '''
{
  "version": 1,
  "ttlSeconds": 21600,
  "clients": [
    {"name": "WEB_REMIX", "version": "1.20261110.04.00",
     "userAgent": "Mozilla/5.0-test", "clientId": "67"}
  ],
  "playerHashes": {"fad7e4e9": {"signatureTimestamp": 20767}},
  "canaryVideoIds": ["aaa111aaa11"]
}
''';

/// Sama seperti A, tapi versi client berubah (= config benar-benar baru).
const String kConfigB = '''
{
  "version": 1,
  "ttlSeconds": 21600,
  "clients": [
    {"name": "WEB_REMIX", "version": "1.20261111.00.00",
     "userAgent": "Mozilla/5.0-test", "clientId": "67"}
  ],
  "playerHashes": {"fad7e4e9": {"signatureTimestamp": 20767}},
  "canaryVideoIds": ["aaa111aaa11"]
}
''';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.body});

  String? body;
  DioException? error;
  int fetchCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount++;
    if (error != null) throw error!;
    return ResponseBody.fromString(body ?? '', 200);
  }

  @override
  void close({bool force = false}) {}
}

ExtractorException _parseFail() =>
    const ExtractorException(ResolveFailureCause.parseFailed);

ExtractorException _networkFail() => const ExtractorException(
  ResolveFailureCause.emptyResponse,
  isNetworkError: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FakeAudioResolver resolver;
  late _FakeAdapter adapter;
  late RemoteConfigLoader configLoader;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    resolver = FakeAudioResolver();
    adapter = _FakeAdapter(body: kConfigA);
    final Dio dio = Dio()..httpClientAdapter = adapter;
    configLoader = RemoteConfigLoader(prefs: prefs, dio: dio);
    now = DateTime(2026, 11, 16, 10, 0);
  });

  ServiceStatusService makeService({DateTime Function()? clock}) {
    return ServiceStatusService(
      canary: CanaryChecker(
        resolver: resolver,
        prefs: prefs,
        videoIds: kTestCanaryIds,
      ),
      config: configLoader,
      prefs: prefs,
      now: clock ?? () => now,
    );
  }

  /// Tanam cache config A yang masih segar (supaya current() tidak fetch).
  /// fetchedAt memakai waktu NYATA (string ISO-8601, sesuai
  /// _parseAndCache): loader membandingkan dengan DateTime.now(),
  /// bukan jam suntik layanan.
  Future<void> seedConfigCache() async {
    await prefs.setString(kRemoteConfigCacheKey, kConfigA);
    await prefs.setString(
      kRemoteConfigFetchedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  test('status awal ok + belum pernah diperiksa (prefs kosong)', () {
    final ServiceStatusService service = makeService();
    expect(service.status.value.status, CanaryStatus.ok);
    expect(service.status.value.checkedAt, isNull);
    expect(service.isBroken, isFalse);
  });

  test('checkIfDue: cek pertama jalan, status + waktu tersimpan', () async {
    final ServiceStatusService service = makeService();
    await service.checkIfDue();
    expect(resolver.resolveCalls, hasLength(5));
    expect(service.status.value.status, CanaryStatus.ok);
    expect(service.status.value.checkedAt, now);
    expect(prefs.getString('laras.service_status'), 'ok');
    expect(
      prefs.getInt('laras.service_checked_at_ms'),
      now.millisecondsSinceEpoch,
    );
  });

  test('checkIfDue: dalam 24 jam tidak cek lagi', () async {
    final ServiceStatusService service = makeService();
    await service.checkIfDue();
    resolver.resolveCalls.clear();
    await service.checkIfDue();
    expect(resolver.resolveCalls, isEmpty);
  });

  test('checkIfDue: sesudah 24 jam cek lagi', () async {
    DateTime clock = now;
    final ServiceStatusService service = makeService(clock: () => clock);
    await service.checkIfDue();
    expect(resolver.resolveCalls, hasLength(5));
    resolver.resolveCalls.clear();
    clock = now.add(const Duration(hours: 25));
    await service.checkIfDue();
    expect(resolver.resolveCalls, hasLength(5));
  });

  test('checkIfDue: 1-2 gagal non-jaringan = degraded', () async {
    resolver.results[kTestCanaryIds[0]] = _parseFail();
    final ServiceStatusService service = makeService();
    await service.checkIfDue();
    expect(service.status.value.status, CanaryStatus.degraded);
    expect(service.isBroken, isFalse);
  });

  test('checkIfDue: 3 gagal penyebab sama = broken', () async {
    resolver.results[kTestCanaryIds[0]] = _parseFail();
    resolver.results[kTestCanaryIds[1]] = _parseFail();
    resolver.results[kTestCanaryIds[2]] = _parseFail();
    final ServiceStatusService service = makeService();
    await service.checkIfDue();
    expect(service.status.value.status, CanaryStatus.broken);
    expect(service.isBroken, isTrue);
  });

  test('checkIfDue: semua gagal jaringan TIDAK mengubah status', () async {
    // Status awal broken dari prefs (seolah cek sebelumnya rusak).
    await prefs.setString('laras.service_status', 'broken');
    await prefs.setInt(
      'laras.service_checked_at_ms',
      now
          .subtract(const Duration(hours: 25))
          .millisecondsSinceEpoch,
    );
    for (final String id in kTestCanaryIds) {
      resolver.results[id] = _networkFail();
    }
    final ServiceStatusService service = makeService();
    expect(service.status.value.status, CanaryStatus.broken);
    await service.checkIfDue();
    // Status tetap broken (bukan ok, bukan makin rusak) dan waktu
    // periksa TIDAK dimajukan (cek berikutnya mencoba lagi).
    expect(service.status.value.status, CanaryStatus.broken);
    expect(
      service.status.value.checkedAt,
      now.subtract(const Duration(hours: 25)),
    );
  });

  test('checkIfDue: cek bersih sesudah broken memulihkan status ok',
      () async {
    await prefs.setString('laras.service_status', 'broken');
    final ServiceStatusService service = makeService();
    await service.checkIfDue();
    expect(service.status.value.status, CanaryStatus.ok);
    expect(service.isBroken, isFalse);
  });

  test('status bertahan antar instance (dibaca dari prefs)', () async {
    resolver.results[kTestCanaryIds[0]] = _parseFail();
    resolver.results[kTestCanaryIds[1]] = _parseFail();
    resolver.results[kTestCanaryIds[2]] = _parseFail();
    final ServiceStatusService first = makeService();
    await first.checkIfDue();
    expect(first.status.value.status, CanaryStatus.broken);
    final ServiceStatusService second = makeService();
    expect(second.status.value.status, CanaryStatus.broken);
    expect(second.status.value.checkedAt, now);
  });

  group('checkForUpdates', () {
    test('config sama + kanari ok = upToDateOk', () async {
      await seedConfigCache();
      adapter.body = kConfigA;
      final ServiceStatusService service = makeService();
      final UpdateCheckResult result = await service.checkForUpdates();
      expect(result, UpdateCheckResult.upToDateOk);
      expect(adapter.fetchCount, 1);
      expect(service.status.value.status, CanaryStatus.ok);
    });

    test('config berubah + kanari ok = updatedOk', () async {
      await seedConfigCache();
      adapter.body = kConfigB;
      final ServiceStatusService service = makeService();
      final UpdateCheckResult result = await service.checkForUpdates();
      expect(result, UpdateCheckResult.updatedOk);
    });

    test('kanari broken = stillBroken walau config baru', () async {
      await seedConfigCache();
      adapter.body = kConfigB;
      resolver.results[kTestCanaryIds[0]] = _parseFail();
      resolver.results[kTestCanaryIds[1]] = _parseFail();
      resolver.results[kTestCanaryIds[2]] = _parseFail();
      final ServiceStatusService service = makeService();
      final UpdateCheckResult result = await service.checkForUpdates();
      expect(result, UpdateCheckResult.stillBroken);
      expect(service.status.value.status, CanaryStatus.broken);
    });

    test('semua probe gagal jaringan = noInternet', () async {
      await seedConfigCache();
      adapter.error = DioException(
        requestOptions: RequestOptions(path: 'https://example.invalid'),
        type: DioExceptionType.connectionError,
      );
      for (final String id in kTestCanaryIds) {
        resolver.results[id] = _networkFail();
      }
      final ServiceStatusService service = makeService();
      final UpdateCheckResult result = await service.checkForUpdates();
      expect(result, UpdateCheckResult.noInternet);
      // Status tidak berubah (tetap ok awal).
      expect(service.status.value.status, CanaryStatus.ok);
      expect(service.status.value.checkedAt, isNull);
    });

    test('config gagal diambil tapi kanari ok = upToDateOk', () async {
      await seedConfigCache();
      adapter.error = DioException(
        requestOptions: RequestOptions(path: 'https://example.invalid'),
        type: DioExceptionType.connectionError,
      );
      final ServiceStatusService service = makeService();
      final UpdateCheckResult result = await service.checkForUpdates();
      // Refresh gagal -> loader memakai cache; isi sama -> upToDate.
      expect(result, UpdateCheckResult.upToDateOk);
    });

    test('panggilan bersamaan digabung (satu cek)', () async {
      await seedConfigCache();
      final ServiceStatusService service = makeService();
      final List<UpdateCheckResult> results = await Future.wait(
        <Future<UpdateCheckResult>>[
          service.checkForUpdates(),
          service.checkForUpdates(),
        ],
      );
      expect(results, <UpdateCheckResult>[
        UpdateCheckResult.upToDateOk,
        UpdateCheckResult.upToDateOk,
      ]);
      expect(adapter.fetchCount, 1);
      expect(resolver.resolveCalls, hasLength(5));
    });

    test('checking true selama cek berjalan', () async {
      await seedConfigCache();
      resolver = FakeAudioResolver(delay: const Duration(milliseconds: 50));
      final ServiceStatusService service = makeService();
      final Future<UpdateCheckResult> job = service.checkForUpdates();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.status.value.checking, isTrue);
      await job;
      expect(service.status.value.checking, isFalse);
    });
  });
}
