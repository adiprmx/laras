// Tes live: memanggil InnerTube dan GitHub Releases nyata.
// Jalankan eksplisit: flutter test --tags live
// CI tidak menjalankan tes ini (lihat ci.yml).
@Tags(<String>['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mengembalikan HttpClient asli: TestWidgetsFlutterBinding memasang
/// HttpClient palsu yang menjawab 400 untuk semua request - tes live
/// butuh jaringan nyata, jadi override palsu diganti subclass ini yang
/// mendelegasikan ke perilaku standar. Override memang sengaja tidak
/// mengubah perilaku (tujuannya hanya menjadi subclass konkret yang
/// bisa dipasang sebagai HttpOverrides.global).
class _RealHttpOverrides extends HttpOverrides {
  @override
  // ignore: unnecessary_overrides - lihat komentar kelas di atas.
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

/// Loader config yang selalu mengembalikan nilai bawaan (tanpa fetch
/// remote): tes resolve end-to-end memakai urutan fallback bawaan
/// (WEB_REMIX -> MWEB -> ANDROID_VR) apa pun isi config remote saat ini.
class _DefaultsConfigLoader extends RemoteConfigLoader {
  _DefaultsConfigLoader({required super.prefs});

  @override
  Future<RemotePlayerConfig> current({bool forceRefresh = false}) async =>
      RemotePlayerConfig.defaults();

  @override
  Future<RemotePlayerConfig> refresh({bool force = false}) async =>
      RemotePlayerConfig.defaults();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Pasang SEBELUM tes berjalan: binding di atas memasang mock HTTP.
  HttpOverrides.global = _RealHttpOverrides();
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  group('live', () {
    test('player WEB_REMIX nyata mengembalikan format audio cipher', () async {
      final InnertubeClient client = InnertubeClient();
      // sts WAJIB di request pertama (tanpa sts: UNPLAYABLE - terbukti
      // diag-sts-vd.js 16 Nov 2026). Alur sama seperti StreamResolver:
      // muat script dulu, lalu player dengan sts.
      final PlayerScriptLoader scriptLoader = PlayerScriptLoader(
        client: client,
      );
      final PlayerScript script = await scriptLoader.load();
      final String? visitorData = await client.ensureVisitorData(
        kWebRemixClient,
      );
      final ParsedPlayerResponse parsed = await client.fetchPlayer(
        'hhn-nGSuenM',
        kWebRemixClient,
        signatureTimestamp: script.signatureTimestamp,
        visitorData: visitorData,
      );
      expect(parsed.playability, Playability.ok);
      final List<int> itags =
          parsed.audioFormats.map((f) => f.itag).toList();
      expect(itags, containsAll(<int>[140, 251]));
      expect(
        parsed.audioFormats.any((f) => f.needsSolver),
        isTrue,
        reason: 'WEB_REMIX mengembalikan format cipher',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('load script player nyata: hash + sts + call site terekstrak', () async {
      final PlayerScriptLoader loader = PlayerScriptLoader(
        client: InnertubeClient(),
      );
      final PlayerScript script = await loader.load();
      expect(script.hash, isNotEmpty);
      expect(script.signatureTimestamp, greaterThan(0));
      expect(script.sigCallSite.middleName, isNotEmpty);
      expect(script.preludeCode, contains('function'));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('player ANDROID_VR nyata mengembalikan URL langsung tanpa sts (P0)', () async {
      final InnertubeClient client = InnertubeClient();
      // Alur sama seperti StreamResolver mode terdegradasi: visitorData
      // dulu (dari client pertama), lalu player VR TANPA sts.
      final String? visitorData = await client.ensureVisitorData(
        kWebRemixClient,
      );
      final ParsedPlayerResponse parsed = await client.fetchPlayer(
        'k2XdBPv0D3Y',
        kAndroidVrClient,
        visitorData: visitorData,
      );
      expect(parsed.playability, Playability.ok);
      final List<int> itags =
          parsed.audioFormats.map((f) => f.itag).toList();
      expect(itags, containsAll(<int>[140, 251]));
      expect(
        parsed.audioFormats.any((f) => f.hasDirectUrl),
        isTrue,
        reason: 'ANDROID_VR mengembalikan URL audio langsung',
      );
      expect(
        parsed.audioFormats.any((f) => f.needsSolver),
        isFalse,
        reason: 'ANDROID_VR tidak mengembalikan format cipher',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('resolve end-to-end lagu insiden P0 (k2XdBPv0D3Y) berhasil', () async {
      final InnertubeClient client = InnertubeClient();
      final QuickJsSignatureSolver solver = QuickJsSignatureSolver();
      try {
        final StreamResolver resolver = StreamResolver(
          innertube: client,
          solver: solver,
          configLoader: _DefaultsConfigLoader(prefs: prefs),
          scriptLoader: PlayerScriptLoader(client: client),
        );
        // Lagu yang gagal total di HP owner 16 Nov 2026: resolve harus
        // berhasil lewat salah satu jalur (fallback varian non-tcl +
        // solver, atau mode terdegradasi ANDROID_VR).
        final ResolvedAudio result = await resolver.resolve('k2XdBPv0D3Y');
        expect(result.url, startsWith('https://'));
        expect(result.itag, isIn(<int>[139, 140, 249, 250, 251]));
      } finally {
        await solver.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('resolve 5/5 lagu kanari end-to-end (R1-H1: gg_quickjs)', () async {
      final InnertubeClient client = InnertubeClient();
      final QuickJsSignatureSolver solver = QuickJsSignatureSolver();
      try {
        final StreamResolver resolver = StreamResolver(
          innertube: client,
          solver: solver,
          configLoader: _DefaultsConfigLoader(prefs: prefs),
          scriptLoader: PlayerScriptLoader(client: client),
        );
        // Satu solver dipakai berurutan untuk kelimanya (mirip pemakaian
        // nyata: runtime + script player dimuat sekali, dipakai ulang).
        // Kegagalan JARINGAN (timeout/koneksi, flag isNetworkError)
        // dicoba ulang sekali — konsisten dengan semantik CanaryChecker
        // yang mengabaikan kegagalan jaringan saja. Kegagalan lain
        // (solver, parse, hash) adalah cacat nyata: tanpa retry.
        final List<String> failures = <String>[];
        for (final CanarySong song in kCanarySongs) {
          ExtractorException? lastError;
          for (var attempt = 0; attempt < 2; attempt++) {
            try {
              final ResolvedAudio result =
                  await resolver.resolve(song.videoId);
              expect(
                isAllowedStreamUrl(result.url),
                isTrue,
                reason: '${song.videoId}: URL hasil resolve di luar host '
                    'yang diizinkan',
              );
              expect(result.itag, isIn(<int>[139, 140, 249, 250, 251]));
              lastError = null;
              break;
            } on ExtractorException catch (e) {
              lastError = e;
              if (!e.isNetworkError) break;
            }
          }
          if (lastError != null) {
            failures.add(
              '${song.videoId}: ${lastError.cause} '
              '${lastError.detail ?? ''}',
            );
          }
        }
        expect(
          failures,
          isEmpty,
          reason: 'gagal resolve: ${failures.join('; ')}',
        );
      } finally {
        await solver.dispose();
      }
      // 30 menit: 5 lagu × egress VM yang lambat/flaky (resolve satu lagu
      // pernah 2+ menit) — batas lama 10 menit terbukti terlalu pendek
      // pada 16 Nov 2026 (tes kehabisan waktu, bukan gagal assert).
    }, timeout: const Timeout(Duration(minutes: 30)));

    test('fetch config remote nyata dari GitHub Releases', () async {
      final RemoteConfigLoader loader = RemoteConfigLoader(
        dio: Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
          ),
        ),
        prefs: prefs,
      );
      final RemotePlayerConfig config = await loader.refresh(force: true);
      expect(config.isRemote, isTrue);
      expect(config.clients, isNotEmpty);
      expect(config.clients.first.name, 'WEB_REMIX');
      expect(config.canaryVideoIds, contains('hhn-nGSuenM'));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
