/// Pengunduh dan pengekstrak script player YouTube (base.js).
///
/// Tugas modul ini:
/// 1. Ambil HTML `www.youtube.com`, ekstrak `jsUrl` (path base.js).
/// 2. Unduh base.js, ekstrak `signatureTimestamp` (sts) untuk request
///    player dan hash player (bagian path `/s/player/<hash>/...`).
/// 3. Ekstrak rantai signature dari call site di base.js: tiga nama fungsi
///    + parameter numeriknya (bentuk `LUAR(a,b,TENGAH(a,b,DALAM(a,b,X.s)))`
///    lalu `f.set(sp, AKHIR(a,b,hasil))`).
/// 4. Rakit prelude minimal solver: tabel string `w` + ketiga fungsi +
///    objek helper yang dipakai fungsi tengah.
///
/// Semua ekstraksi di sini memakai pola perilaku (regex + pencocokan
/// kurung) yang ditulis sendiri dari pengamatan struktur base.js. Tidak ada
/// kode yang disalin dari repo extractor lain; nama fungsi dan parameter
/// dibaca dari base.js saat berjalan, bukan di-hardcode - karena YouTube
/// memutar nama dan parameter itu tiap rilis player.
///
/// Bila pola tidak cocok (YouTube mengubah struktur player), loader
/// melempar [ExtractorException] penyebab
/// [ResolveFailureCause.unknownPlayerHash]; orkestrator memetakan itu ke
/// status layanan dan config remote yang bisa mendorong pola baru.
library;

import 'dart:convert';

import '../errors.dart';
import 'js_stubs.dart';

/// Rantai tiga fungsi signature dari call site.
class SigCallSite {
  const SigCallSite({
    required this.innerName,
    required this.innerA,
    required this.innerB,
    required this.middleName,
    required this.middleA,
    required this.middleB,
    required this.outerName,
    required this.outerA,
    required this.outerB,
    required this.helperObjectName,
  });

  /// Fungsi dalam: menerima `s` ciphered (mis. `uf(9,8472,s)`).
  final String innerName;
  final int innerA;
  final int innerB;

  /// Fungsi tengah: transform signature utama (mis. `Ne(56,7789,...)`).
  final String middleName;
  final int middleA;
  final int middleB;

  /// Fungsi luar: pengodean akhir (mis. `vf(2,6827,...)`).
  final String outerName;
  final int outerA;
  final int outerB;

  /// Objek helper yang dipakai fungsi tengah (mis. `jB`).
  final String helperObjectName;

  /// Ekspresi JS untuk menghitung signature dari variabel [cipheredVar].
  String solveExpression(String cipheredVar) =>
      '$outerName($outerA,$outerB,'
      '$middleName($middleA,$middleB,'
      '$innerName($innerA,$innerB,$cipheredVar)))';

  @override
  String toString() =>
      'SigCallSite($outerName($outerA,$outerB,'
      '$middleName($middleA,$middleB,'
      '$innerName($innerA,$innerB,s))))';
}

/// Script player yang sudah diekstrak dan siap dipakai solver.
class PlayerScript {
  const PlayerScript({
    required this.jsUrl,
    required this.hash,
    required this.signatureTimestamp,
    required this.source,
    required this.sigCallSite,
    required this.preludeCode,
  });

  /// Path jsUrl, mis. `/s/player/fad7e4e9/player_es6.vflset/en_US/base.js`.
  final String jsUrl;

  /// Hash player dari path (mis. `fad7e4e9`).
  final String hash;

  /// `signatureTimestamp` (sts) dari base.js untuk request player.
  final int signatureTimestamp;

  /// Seluruh sumber base.js (dipakai solver QuickJS untuk transform `n`
  /// lewat kelas URL internal player).
  final String source;

  /// Rantai signature dari call site.
  final SigCallSite sigCallSite;

  /// Prelude minimal solver: tabel string + tiga fungsi signature + objek
  /// helper. Dievaluasi di runtime QuickJS yang sama dengan [source]
  /// (variabelnya global, tidak bentrok dengan salinan lokal di IIFE
  /// base.js).
  final String preludeCode;
}

/// Ekstrak `jsUrl` dari HTML youtube.com.
///
/// Mengembalikan path, mis. `/s/player/fad7e4e9/player_es6.vflset/en_US/base.js`.
String? extractJsUrl(String html) {
  final RegExpMatch? match = RegExp(
    r'"jsUrl"\s*:\s*"([^"]+)"',
  ).firstMatch(html);
  return match?.group(1);
}

/// Ekstrak hash player dari path jsUrl (`/s/player/<hash>/...`).
String? extractPlayerHash(String jsUrl) {
  final RegExpMatch? match = RegExp(
    r'/s/player/([A-Za-z0-9]+)/',
  ).firstMatch(jsUrl);
  return match?.group(1);
}

/// Ekstrak `signatureTimestamp` dari sumber base.js.
int? extractSignatureTimestamp(String baseJs) {
  final RegExpMatch? match = RegExp(
    r'signatureTimestamp\s*:\s*(\d+)',
  ).firstMatch(baseJs);
  final String? value = match?.group(1);
  return value == null ? null : int.tryParse(value);
}

/// Ekstrak tabel string `w` dari base.js (`w='...'.split(";");`).
String? extractStringTable(String baseJs) {
  final RegExpMatch? match = RegExp(
    "w='[^']*'\\.split\\(\";\"\\);",
  ).firstMatch(baseJs);
  return match?.group(0);
}

/// Ekstrak definisi fungsi top-level `NAME=function(...)` dengan
/// pencocokan kurung kurawal (sadar string).
String? extractFunction(String baseJs, String name) {
  final RegExp pattern = RegExp(
    '(?:^|[^A-Za-z0-9_\$])${RegExp.escape(name)}=function\\(',
  );
  final RegExpMatch? match = pattern.firstMatch(baseJs);
  if (match == null) return null;
  final int start = match.start + match.group(0)!.indexOf(name);
  return _extractBraced(baseJs, start);
}

/// Ekstrak literal objek top-level `NAME={...}` dengan pencocokan kurung.
String? extractObjectLiteral(String baseJs, String name) {
  final RegExp pattern = RegExp(
    '(?:^|[^A-Za-z0-9_\$])${RegExp.escape(name)}=\\{',
  );
  final RegExpMatch? match = pattern.firstMatch(baseJs);
  if (match == null) return null;
  final int start = match.start + match.group(0)!.indexOf(name);
  return _extractBraced(baseJs, start);
}

/// Potong teks dari [start] sampai kurung kurawal penutup yang seimbang.
String? _extractBraced(String source, int start) {
  final int braceStart = source.indexOf('{', start);
  if (braceStart < 0) return null;
  int depth = 0;
  String? inString;
  bool escaped = false;
  for (int i = braceStart; i < source.length; i++) {
    final String ch = source[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (ch == r'\') {
      if (inString != null) escaped = true;
      continue;
    }
    if (inString != null) {
      if (ch == inString) inString = null;
      continue;
    }
    if (ch == '"' || ch == "'" || ch == '`') {
      inString = ch;
      continue;
    }
    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  return null;
}

/// Ekstrak rantai signature dari call site di base.js.
///
/// Bentuk yang dicari (diamati di base.js fad7e4e9):
/// ```js
/// let l=Ne(56,7789,uf(9,8472,k.s));
/// f[w[8]](h,vf(2,6827,l))
/// ```
/// Mengembalikan null bila pola tidak cocok (player berubah).
SigCallSite? extractSigCallSite(String baseJs) {
  // Langkah 1: temp = TENGAH(a,b,DALAM(a,b,X.s))
  final RegExp chainPattern = RegExp(
    r'(?:var|let|const)\s+([A-Za-z0-9_$]+)\s*=\s*'
    r'([A-Za-z0-9_$]+)\((\d+),(\d+),'
    r'([A-Za-z0-9_$]+)\((\d+),(\d+),'
    r'[A-Za-z0-9_$]+\.s\)\)',
  );
  final RegExpMatch? chain = chainPattern.firstMatch(baseJs);
  if (chain == null) return null;
  final String tempVar = chain.group(1)!;
  final String middleName = chain.group(2)!;
  final int middleA = int.parse(chain.group(3)!);
  final int middleB = int.parse(chain.group(4)!);
  final String innerName = chain.group(5)!;
  final int innerA = int.parse(chain.group(6)!);
  final int innerB = int.parse(chain.group(7)!);

  // Langkah 2: AKHIR(a,b,tempVar) di dekat call site (dalam 500 karakter).
  final int searchEnd = (chain.end + 500).clamp(0, baseJs.length);
  final String window = baseJs.substring(chain.end, searchEnd);
  final RegExp outerPattern = RegExp(
    r'([A-Za-z0-9_$]+)\((\d+),(\d+),'
    '${RegExp.escape(tempVar)}\\)',
  );
  final RegExpMatch? outer = outerPattern.firstMatch(window);
  if (outer == null) return null;
  final String outerName = outer.group(1)!;
  final int outerA = int.parse(outer.group(2)!);
  final int outerB = int.parse(outer.group(3)!);

  // Langkah 3: objek helper dari badan fungsi tengah - identifier yang
  // dipakai sebagai `IDENT[w[...]]` dan bukan parameter/lokal.
  final String? middleBody = extractFunction(baseJs, middleName);
  if (middleBody == null) return null;
  final String? helper = _findHelperObject(middleBody);
  if (helper == null) return null;

  return SigCallSite(
    innerName: innerName,
    innerA: innerA,
    innerB: innerB,
    middleName: middleName,
    middleA: middleA,
    middleB: middleB,
    outerName: outerName,
    outerA: outerA,
    outerB: outerB,
    helperObjectName: helper,
  );
}

/// Cari objek helper di badan fungsi: identifier sebelum `[w[` yang bukan
/// parameter (a,b,c,d) dan bukan variabel lokal (var/let/const).
String? _findHelperObject(String functionBody) {
  final Set<String> locals = <String>{'a', 'b', 'c', 'd', 'e', 'f', 'h', 'k'};
  final RegExp localPattern = RegExp(
    r'(?:var|let|const)\s+([A-Za-z0-9_$]+)',
  );
  for (final RegExpMatch m in localPattern.allMatches(functionBody)) {
    locals.add(m.group(1)!);
  }
  final RegExp usePattern = RegExp(r'([A-Za-z0-9_$]+)\[w\[');
  for (final RegExpMatch m in usePattern.allMatches(functionBody)) {
    final String name = m.group(1)!;
    if (!locals.contains(name)) return name;
  }
  return null;
}

/// Rakit [PlayerScript] dari sumber base.js + jsUrl.
///
/// Melempar [ExtractorException] penyebab unknownPlayerHash bila ada
/// ekstraksi yang gagal.
PlayerScript buildPlayerScript(String jsUrl, String baseJs) {
  final String? hash = extractPlayerHash(jsUrl);
  final int? sts = extractSignatureTimestamp(baseJs);
  final SigCallSite? callSite = extractSigCallSite(baseJs);
  final String? table = extractStringTable(baseJs);
  if (hash == null || sts == null || callSite == null || table == null) {
    throw ExtractorException(
      ResolveFailureCause.unknownPlayerHash,
      detail:
          'ekstraksi base.js gagal '
          '(hash: ${hash != null}, sts: ${sts != null}, '
          'callSite: ${callSite != null}, table: ${table != null})',
    );
  }
  final String? innerFn = extractFunction(baseJs, callSite.innerName);
  final String? middleFn = extractFunction(baseJs, callSite.middleName);
  final String? outerFn = extractFunction(baseJs, callSite.outerName);
  final String? helperObj = extractObjectLiteral(
    baseJs,
    callSite.helperObjectName,
  );
  if (innerFn == null ||
      middleFn == null ||
      outerFn == null ||
      helperObj == null) {
    throw const ExtractorException(
      ResolveFailureCause.unknownPlayerHash,
      detail: 'definisi fungsi signature tidak ketemu di base.js',
    );
  }
  final String prelude = <String>[
    table,
    '$innerFn;',
    '$middleFn;',
    '$outerFn;',
    '$helperObj;',
  ].join('\n');
  return PlayerScript(
    jsUrl: jsUrl,
    hash: hash,
    signatureTimestamp: sts,
    source: baseJs,
    sigCallSite: callSite,
    preludeCode: prelude,
  );
}

/// Skrip driver solver: hitung signature dari cipher lalu bangun URL final
/// lewat kelas URL internal player (`_yt_player.tf`), yang sekaligus
/// menjalankan transform `n` saat serialisasi.
///
/// [script] menyediakan rantai signature; [cipherUrl], [cipheredS], dan
/// [sigParam] disisipkan sebagai literal JSON agar aman dari injeksi.
String buildSolveDriver(
  PlayerScript script, {
  required String cipherUrl,
  required String cipheredS,
  required String sigParam,
}) {
  final String sigExpr = script.sigCallSite.solveExpression('__s');
  return '''
var __s = ${jsonEncode(cipheredS)};
var __sig = $sigExpr;
var __u = new _yt_player.tf(${jsonEncode(cipherUrl)}, true);
__u.set(${jsonEncode(sigParam)}, decodeURIComponent(__sig));
__u.gf();
''';
}

/// Seluruh skrip yang dievaluasi sekali saat inisialisasi solver:
/// stub DOM + sumber base.js + prelude signature.
String buildSolverInitScript(PlayerScript script) =>
    '$kJsDomStubs\n${script.source}\n${script.preludeCode}\n';
