import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';

String loadSnippet() =>
    File('test/fixtures/base-js-snippet.js').readAsStringSync();

String htmlWithJsUrl(String jsUrl) =>
    '<html><body>{"jsUrl":"$jsUrl"}</body></html>';

const String kKnownJsUrl =
    '/s/player/fad7e4e9/player_es6.vflset/en_US/base.js';
const String kUnknownJsUrl =
    '/s/player/zzztidakdikenal/player_es6.vflset/en_US/base.js';
const String kNewJsUrl =
    '/s/player/abc123baru/player_es6.vflset/en_US/base.js';
const String kTclJsUrl =
    '/s/player/fad7e4e9/player_es6_tcl.vflset/en_US/base.js';
const String kNonTclJsUrl =
    '/s/player/fad7e4e9/player_es6.vflset/en_US/base.js';

/// Client palsu: HTML + base.js kalengan, mencatat URL yang di-fetch.
class FakeFetchClient extends InnertubeClient {
  FakeFetchClient({required this.html, this.baseJsByUrl = const <String, String>{}});

  final String html;

  /// URL base.js -> isi base.js. Bila URL tidak ada di peta, kembalikan
  /// cuplikan base.js fad7e4e9 (bisa diekstrak).
  final Map<String, String> baseJsByUrl;

  final List<String> fetchedUrls = <String>[];

  @override
  Future<String> fetchText(
    String url, {
    int maxBytes = ResponseLimits.playerScriptBytes,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    fetchedUrls.add(url);
    if (url == 'https://www.youtube.com/') return html;
    return baseJsByUrl[url] ?? loadSnippet();
  }
}

Matcher isUnknownPlayerHashError() => isA<ExtractorException>().having(
  (ExtractorException e) => e.cause,
  'cause',
  ResolveFailureCause.unknownPlayerHash,
);

void main() {
  group('PlayerScriptLoader gerbang hash (R1-M2)', () {
    test('hash bawaan yang dikenal lolos dan terekstrak', () async {
      final FakeFetchClient client = FakeFetchClient(
        html: htmlWithJsUrl(kKnownJsUrl),
      );
      final PlayerScriptLoader loader = PlayerScriptLoader(client: client);
      final PlayerScript script = await loader.load();
      expect(script.hash, 'fad7e4e9');
      expect(script.signatureTimestamp, 20767);
      expect(script.sigCallSite.middleName, 'Ne');
    });

    test('hash tak dikenal ditolak SEBELUM base.js diunduh', () async {
      final FakeFetchClient client = FakeFetchClient(
        html: htmlWithJsUrl(kUnknownJsUrl),
      );
      final PlayerScriptLoader loader = PlayerScriptLoader(client: client);
      await expectLater(loader.load(), throwsA(isUnknownPlayerHashError()));
      // Bukti gerbang berjalan sebelum unduh: hanya HTML yang di-fetch,
      // base.js (2,7 MB JS asing) tidak pernah disentuh.
      expect(client.fetchedUrls, <String>['https://www.youtube.com/']);
    });

    test('hash baru lolos bila ada di allowlist config remote', () async {
      final FakeFetchClient client = FakeFetchClient(
        html: htmlWithJsUrl(kNewJsUrl),
      );
      final PlayerScriptLoader loader = PlayerScriptLoader(client: client);
      // Tanpa allowlist: ditolak (bukan hash bawaan).
      await expectLater(loader.load(), throwsA(isUnknownPlayerHashError()));
      // Dengan allowlist dari config remote: lolos — jalur update hash
      // tanpa rilis app tetap jalan.
      final PlayerScript script = await loader.load(
        allowedHashes: <String>{'abc123baru'},
        forceRefresh: true,
      );
      expect(script.hash, 'abc123baru');
    });

    test('allowlist kosong berarti pakai hash bawaan', () async {
      final FakeFetchClient client = FakeFetchClient(
        html: htmlWithJsUrl(kKnownJsUrl),
      );
      final PlayerScriptLoader loader = PlayerScriptLoader(client: client);
      final PlayerScript script = await loader.load(
        allowedHashes: <String>{},
      );
      expect(script.hash, 'fad7e4e9');
    });

    test('varian tcl: gerbang lolos (hash sama), yang dieksekusi non-tcl',
        () async {
      // P0: varian tcl memakai hash yang sama dengan non-tcl tapi tidak
      // bisa diekstrak. Gerbang memeriksa hash (sama -> lolos), lalu
      // ekstraksi tcl gagal dan fallback non-tcl yang dieksekusi.
      final FakeFetchClient client = FakeFetchClient(
        html: htmlWithJsUrl(kTclJsUrl),
        baseJsByUrl: <String, String>{
          'https://www.youtube.com$kTclJsUrl':
              'var x = 1; // varian tcl, pola tidak cocok',
          'https://www.youtube.com$kNonTclJsUrl': loadSnippet(),
        },
      );
      final PlayerScriptLoader loader = PlayerScriptLoader(client: client);
      final PlayerScript script = await loader.load();
      expect(script.hash, 'fad7e4e9');
      expect(script.jsUrl, kNonTclJsUrl);
      expect(script.signatureTimestamp, 20767);
    });

    test('cache tidak dipakai bila hash-nya dicabut dari allowlist',
        () async {
      final FakeFetchClient client = FakeFetchClient(
        html: htmlWithJsUrl(kKnownJsUrl),
      );
      final PlayerScriptLoader loader = PlayerScriptLoader(client: client);
      final PlayerScript first = await loader.load();
      expect(first.hash, 'fad7e4e9');
      // Config remote terbaru mencabut fad7e4e9 (hanya hash lain yang
      // diizinkan): cache tidak boleh dipakai lagi.
      await expectLater(
        loader.load(allowedHashes: <String>{'hashlain'}),
        throwsA(isUnknownPlayerHashError()),
      );
    });
  });
}
