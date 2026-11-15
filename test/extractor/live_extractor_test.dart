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
