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
      expect(site.setMethodTableIndex, 8);
    });

  });

  group('extractStringTable bentuk baru (rotasi 17 Nov 2026)', () {
    test('kutip ganda + delimiter ";" (ad8d59ae)', () {
      const String snippet =
          'var a=1;w="length;url;mZ;rr?[1-9].*\\.c\\.youtube\\.com\$/videoplayback;'
          'split;;r;,;scheme;path;reverse;cmo=pf;C;set;WAaZk4;replacer;'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaa".split(";");var b=2;';
      final String? table = extractStringTable(snippet);
      expect(table, isNotNull);
      expect(table, startsWith('w="length;'));
      expect(table, endsWith('.split(";");'));
    });

    test('kutip ganda + delimiter "{" (b559f50c)', () {
      const String snippet =
          'w="/initplayback{/file/index.m3u8{A{path{length{call{set{{indexOf{'
          'toString{n{join{/videoplayback{/{B{mn{j{file{www.youtube.com{&{http:'
          '//local{split{startsWith{splaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaa".split("{");';
      final String? table = extractStringTable(snippet);
      expect(table, isNotNull);
      expect(table, startsWith('w="/initplayback{'));
      expect(table, endsWith('.split("{");'));
    });

    test('kutip ganda + escape \\" di dalam isi tetap cocok', () {
      const String snippet =
          'w="tokenA;tokenB;teks\\"dengan\\"kutip;tokenC;tokenD;tokenE;tokenF;'
          'tokenG;tokenH;tokenI;tokenJ;tokenK;tokenL;tokenM;tokenN;tokenO;'
          'tokenP;tokenQ;tokenR;tokenS;tokenT;tokenU;tokenV".split(";");';
      final String? table = extractStringTable(snippet);
      expect(table, isNotNull);
      expect(table, contains('teks\\"dengan\\"kutip'));
    });

    test('tanpa tabel -> null', () {
      expect(extractStringTable('var x = 1; function f() { return 2; }'),
          isNull);
      expect(extractStringTable('w="pendek".split(";");'), isNull);
    });
  });

  group('ekstraksi dari cuplikan base.js fad7e4e9 (lanjutan)', () {
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
      // Info URL (kelas tf + set + gf dari cuplikan fad7e4e9).
      expect(script.urlClassName, 'tf');
      expect(script.urlSetMethod, 'set');
      expect(script.urlSerializeMethod, 'gf');
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

  group('buildPlayerScript helper global bawaan (rotasi 17 Nov 2026)', () {
    // Call site + fungsi minimal; helper-nya `String` (global bawaan,
    // tanpa literal `String={`) seperti di base.js ad8d59ae. Konteks URL
    // (new g.tf + kelas minimal) memakai jalur eliminasi untuk metode
    // serialisasi (gf) karena badannya trivial.
    const String kBuiltinHelperJs = '''
signatureTimestamp:20768,
c=new g.tf(k.url,!0);if(k.s){var f=c,h=k.sp;
let l=Xm(46,8518,Ip(4,6503,k.s));
f[w[8]](h,ld(8,476,l))
w='length;url;split;reverse;join;fromCharCode;slice;splice;set;'.split(";");
Ip=function(a,b,c){return c;}
Xm=function(a,b,c){var d=b^a;return String[w[0]](d);}
ld=function(a,b,c){return c;}
g.tf=class{constructor(a,b=!1){this.u=a;}set(a,b){}get(a){return null;}gf(){return this.u;}clone(){return this;}};
''';
    const String kJsUrlAd8 =
        '/s/player/ad8d59ae/player_es6.vflset/en_US/base.js';

    test('helper String (builtin) tanpa literal -> prelude tanpa helper', () {
      final PlayerScript script =
          buildPlayerScript(kJsUrlAd8, kBuiltinHelperJs);
      expect(script.hash, 'ad8d59ae');
      expect(script.signatureTimestamp, 20768);
      expect(script.sigCallSite.helperObjectName, 'String');
      expect(script.preludeCode, contains('Xm=function'));
      expect(script.preludeCode, contains('Ip=function'));
      expect(script.preludeCode, contains('ld=function'));
      expect(script.preludeCode, isNot(contains('String={')));
    });

    test('helper kustom tanpa literal -> tetap gagal keras', () {
      final String js =
          kBuiltinHelperJs.replaceAll('String[w[0]]', 'ZZ[w[0]]');
      expect(
        () => buildPlayerScript(kJsUrlAd8, js),
        throwsA(
          isA<ExtractorException>().having(
            (e) => e.cause,
            'cause',
            ResolveFailureCause.unknownPlayerHash,
          ),
        ),
      );
    });
  });

  group('buildPlayerScript dependensi transitif (rotasi 17 Nov 2026)', () {
    test('prelude ad8d59ae memuat Vm + rantai transitif', () {
      final PlayerScript script = buildPlayerScript(
        '/s/player/ad8d59ae/player_es6.vflset/en_US/base.js',
        File('test/fixtures/base-js-snippet-ad8d59ae.js')
            .readAsStringSync(),
      );
      expect(script.hash, 'ad8d59ae');
      expect(script.signatureTimestamp, 20768);
      expect(script.sigCallSite.innerName, 'Ip');
      expect(script.sigCallSite.middleName, 'Xm');
      expect(script.sigCallSite.outerName, 'ld');
      expect(script.sigCallSite.helperObjectName, 'String');
      // Ring 1: dependensi langsung rantai. Vm adalah akar bug 17 Nov:
      // Xm memanggil Vm[w[...]] tapi prelude lama tidak memuatnya.
      expect(script.preludeCode, contains('Vm={'));
      expect(script.preludeCode, contains('bk=function'));
      expect(script.preludeCode, contains('Wm=function'));
      expect(script.preludeCode, contains('kd=function'));
      // Ring 2+: transitif — Wm butuh Gn/Vz/hB, kd butuh Bp/Bd.
      expect(script.preludeCode, contains('Gn=function'));
      expect(script.preludeCode, contains('Vz=function'));
      expect(script.preludeCode, contains('hB=function'));
      expect(script.preludeCode, contains('Bp=function'));
      expect(script.preludeCode, contains('Bd=function'));
      // Ring 3+: Vz butuh Tz/Uz, Bp butuh zp, zp butuh Ela/yp.
      expect(script.preludeCode, contains('Tz=function'));
      expect(script.preludeCode, contains('Uz=function'));
      expect(script.preludeCode, contains('zp=function'));
      expect(script.preludeCode, contains('Ela=function'));
      expect(script.preludeCode, contains('yp=function'));
      // Alias parameter IIFE untuk g.jr/g.Um/g.O di Wm/kd.
      expect(script.preludeCode, contains('var g = _yt_player;'));
      // Decoy cabang mati tanpa definisi tidak ikut dimuat.
      expect(script.preludeCode, isNot(contains('Taa=function')));
      expect(script.preludeCode, isNot(contains('Taa={')));
      // Info URL ad8d59ae: kelas bs (bukan tf), serialisasi ff.
      expect(script.urlClassName, 'bs');
      expect(script.urlSetMethod, 'set');
      expect(script.urlSerializeMethod, 'ff');
      expect(script.sigCallSite.setMethodTableIndex, 14);
    });

    test('prelude b559f50c memuat rantai transitif + helper mV', () {
      final PlayerScript script = buildPlayerScript(
        '/s/player/b559f50c/player_es6.vflset/en_US/base.js',
        File('test/fixtures/base-js-snippet-b559f50c.js')
            .readAsStringSync(),
      );
      expect(script.hash, 'b559f50c');
      expect(script.signatureTimestamp, 20770);
      expect(script.sigCallSite.innerName, 'IH');
      expect(script.sigCallSite.middleName, 'dy');
      expect(script.sigCallSite.outerName, 'dy');
      expect(script.sigCallSite.helperObjectName, 'mV');
      expect(script.preludeCode, contains('mV={'));
      expect(script.preludeCode, contains('ay=function'));
      expect(script.preludeCode, contains('by=function'));
      expect(script.preludeCode, contains('cy=function'));
      expect(script.preludeCode, contains('ey=function'));
      expect(script.preludeCode, contains('Iz=function'));
      expect(script.preludeCode, contains('Jz=function'));
      expect(script.preludeCode, contains('lc=function'));
      expect(script.preludeCode, contains('hha=function'));
      // Fungsi yang dipakai ganda (tengah + luar) cukup sekali.
      expect('\ndy=function'.allMatches(script.preludeCode).length, 1);
      // Info URL b559f50c: kelas JH, serialisasi gf (seperti tf lama).
      expect(script.urlClassName, 'JH');
      expect(script.urlSetMethod, 'set');
      expect(script.urlSerializeMethod, 'gf');
      expect(script.sigCallSite.setMethodTableIndex, 6);
    });

    test('buildSolveDriver memakai nama URL hasil ekstraksi', () {
      final PlayerScript script = buildPlayerScript(
        '/s/player/ad8d59ae/player_es6.vflset/en_US/base.js',
        File('test/fixtures/base-js-snippet-ad8d59ae.js')
            .readAsStringSync(),
      );
      final String driver = buildSolveDriver(
        script,
        cipherUrl: 'https://rr1---sn-x.googlevideo.com/videoplayback?n=abc',
        cipheredS: 's-ciphered',
        sigParam: 'sig',
      );
      expect(driver, contains('new _yt_player.bs('));
      expect(driver, contains('__u.set('));
      expect(driver, contains('__u.ff();'));
      expect(driver, isNot(contains('_yt_player.tf')));
      expect(driver, isNot(contains('__u.gf();')));
    });

    test('parseStringTable mengurai kedua bentuk + escape', () {
      expect(
        parseStringTable("w='a;b;c;'.split(\";\");"),
        <String>['a', 'b', 'c', ''],
      );
      expect(
        parseStringTable('w="a{b{c".split("{");'),
        <String>['a', 'b', 'c'],
      );
      expect(
        parseStringTable(r'w="teks\"dengan\"kutip;x".split(";");'),
        <String>['teks"dengan"kutip', 'x'],
      );
      expect(parseStringTable('var x = 1;'), isNull);
      expect(parseStringTable('w="tanpa split";'), isNull);
    });

    test('pemindai referensi: lokal koma, string, properti bukan dep', () {
      // Fungsi tengah memakai: array lokal `f` (deklarator kedua
      // `var e=...,f=[]`), string berisi `ZZ(`, panggilan properti
      // `g.jr(`, helper asli Qq, dan panggilan Rr -> Ss (transitif).
      // Decoy `f`/`ZZ`/`jr` punya definisi di cuplikan — prelude WAJIB
      // tidak memuatnya.
      const String js = '''
signatureTimestamp:20799,
c=new g.tf(k.url,!0);if(k.s){var f=c,h=k.sp;
let l=Mm(10,20,Ii(3,4,k.s));
f[w[8]](h,Oo(5,6,l))
w='length;url;split;reverse;join;fromCharCode;x;y;set;'.split(";");
Ii=function(a,b,c){return c;}
Mm=function(a,b,c){var d=b^a;var e=d^1,f=[];f[w[0]](Qq[w[1]](d));var s="ZZ(1,2)";g.jr(d);return Rr(e);}
Oo=function(a,b,c){return c;}
Qq={m:function(a){return a;}};
Rr=function(a){return Ss(a);};
Ss=function(a){return a;};
f=function(a){return a;};
ZZ=function(a){return a;};
jr=function(a){return a;};
g.tf=class{constructor(a,b=!1){this.u=a;}set(a,b){}get(a){return null;}gf(){return this.u;}clone(){return this;}};
''';
      final PlayerScript script = buildPlayerScript(
        '/s/player/abcdef01/player_es6.vflset/en_US/base.js',
        js,
      );
      expect(script.sigCallSite.helperObjectName, 'Qq');
      expect(script.preludeCode, contains('Qq={'));
      expect(script.preludeCode, contains('Rr=function'));
      expect(script.preludeCode, contains('Ss=function'));
      expect(script.preludeCode, isNot(contains('f=function')));
      expect(script.preludeCode, isNot(contains('ZZ=function')));
      expect(script.preludeCode, isNot(contains('jr=function')));
    });
  });
}
