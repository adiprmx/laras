import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';

String loadSnippet() =>
    File('test/fixtures/base-js-snippet.js').readAsStringSync();

const String kJsUrl = '/s/player/fad7e4e9/player_es6.vflset/en_US/base.js';

void main() {
  group('ekstraksi dari cuplikan base.js fad7e4e9 (asli, 15 Nov 2026)', () {
    test('extractJsUrl dari HTML', () {
      const String html =
          '<html><head></head><body>{"jsUrl":"/s/player/fad7e4e9/player_es6.vflset/en_US/base.js","other":1}</body></html>';
      expect(extractJsUrl(html), kJsUrl);
      expect(extractJsUrl('<html>tanpa jsUrl</html>'), isNull);
    });

    test('extractPlayerHash dari jsUrl', () {
      expect(extractPlayerHash(kJsUrl), 'fad7e4e9');
      expect(extractPlayerHash('/s/player/abc123/player.js'), 'abc123');
      expect(extractPlayerHash('/tanpa/hash'), isNull);
    });

    test('extractSignatureTimestamp = 20767', () {
      expect(extractSignatureTimestamp(loadSnippet()), 20767);
    });

    test('extractStringTable menemukan tabel w', () {
      final String? table = extractStringTable(loadSnippet());
      expect(table, isNotNull);
      expect(table, startsWith("w='length;"));
      expect(table, contains('signatureCipher'));
      expect(table, contains('_w8_'));
    });

    test('extractSigCallSite: uf / Ne / vf + parameter call site', () {
      final SigCallSite? site = extractSigCallSite(loadSnippet());
      expect(site, isNotNull);
      expect(site!.innerName, 'uf');
      expect(site.innerA, 9);
      expect(site.innerB, 8472);
      expect(site.middleName, 'Ne');
      expect(site.middleA, 56);
      expect(site.middleB, 7789);
      expect(site.outerName, 'vf');
      expect(site.outerA, 2);
      expect(site.outerB, 6827);
      expect(site.helperObjectName, 'jB');
    });

    test('solveExpression merangkai rantai dengan benar', () {
      final SigCallSite? site = extractSigCallSite(loadSnippet());
      expect(
        site!.solveExpression('__s'),
        'vf(2,6827,Ne(56,7789,uf(9,8472,__s)))',
      );
    });

    test('extractFunction mengambil badan fungsi utuh', () {
      final String snippet = loadSnippet();
      final String? uf = extractFunction(snippet, 'uf');
      expect(uf, isNotNull);
      expect(uf, startsWith('uf=function(a,b,c,d){'));
      expect(uf, endsWith('}'));
      expect(uf, contains('decodeURIComponent'));
      final String? ne = extractFunction(snippet, 'Ne');
      expect(ne, isNotNull);
      expect(ne, contains('jB['));
      expect(extractFunction(snippet, 'tidakAda'), isNull);
    });

    test('extractObjectLiteral mengambil jB utuh', () {
      final String? jb = extractObjectLiteral(loadSnippet(), 'jB');
      expect(jb, isNotNull);
      expect(jb, startsWith('jB={'));
      expect(jb, contains('FG:function'));
      expect(jb, contains('Gz:function'));
      expect(jb, contains('Fe:function'));
    });

    test('buildPlayerScript merakit prelude lengkap', () {
      final PlayerScript script = buildPlayerScript(kJsUrl, loadSnippet());
      expect(script.hash, 'fad7e4e9');
      expect(script.signatureTimestamp, 20767);
      expect(script.sigCallSite.middleName, 'Ne');
      expect(script.preludeCode, contains("w='length;"));
      expect(script.preludeCode, contains('uf=function'));
      expect(script.preludeCode, contains('Ne=function'));
      expect(script.preludeCode, contains('vf=function'));
      expect(script.preludeCode, contains('jB={'));
    });

    test('buildPlayerScript gagal bila pola tidak cocok', () {
      expect(
        () => buildPlayerScript(kJsUrl, 'var x = 1; // bukan base.js'),
        throwsA(
          isA<ExtractorException>().having(
            (e) => e.cause,
            'cause',
            ResolveFailureCause.unknownPlayerHash,
          ),
        ),
      );
    });

    test('buildSolveDriver menyisipkan nilai sebagai literal JSON', () {
      final PlayerScript script = buildPlayerScript(kJsUrl, loadSnippet());
      final String driver = buildSolveDriver(
        script,
        cipherUrl: 'https://rr1---sn-x.googlevideo.com/videoplayback?n=abc',
        cipheredS: 's-ciphered";berbahaya',
        sigParam: 'sig',
      );
      // Nilai berbahaya harus terkode JSON (tanda kutip di-escape),
      // bukan tersisip mentah ke skrip.
      expect(driver, contains(r'\";berbahaya'));
      expect(driver, contains('vf(2,6827,Ne(56,7789,uf(9,8472,__s)))'));
      expect(driver, contains('new _yt_player.tf('));
      expect(driver, contains('__u.gf();'));
    });

    test('buildSolverInitScript menggabung stub + sumber + prelude', () {
      final PlayerScript script = buildPlayerScript(kJsUrl, loadSnippet());
      final String init = buildSolverInitScript(script);
      expect(init, contains('globalThis.document = documentStub'));
      expect(init, contains('signatureTimestamp:20767'));
      expect(init, contains('uf=function'));
    });
  });
}
