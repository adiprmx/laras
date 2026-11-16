/// Pengunduh dan pengekstrak script player YouTube (base.js).
///
/// Tugas modul ini:
/// 1. Ambil HTML `www.youtube.com`, ekstrak `jsUrl` (path base.js).
/// 2. Unduh base.js, ekstrak `signatureTimestamp` (sts) untuk request
///    player dan hash player (bagian path `/s/player/<hash>/...`).
/// 3. Ekstrak rantai signature dari call site di base.js: tiga nama fungsi
///    + parameter numeriknya (bentuk `LUAR(a,b,TENGAH(a,b,DALAM(a,b,X.s)))`
///    lalu `f.set(sp, AKHIR(a,b,hasil))`).
/// 4. Ekstrak info pemutar URL: nama kelas URL internal (`new g.XX(url)`),
///    nama metode set (lewat tabel string), dan nama metode serialisasi
///    (dari badan kelas). Ketiganya berputar per rilis player.
/// 5. Rakit prelude minimal solver: tabel string `w` + ketiga fungsi +
///    dependensi TRANSITIF rantai (objek/fungsi helper yang dirujuk
///    fungsi-fungsi itu, rekursif) + alias `g` ke `_yt_player`.
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
    required this.setMethodTableIndex,
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

  /// Indeks tabel string untuk nama metode set URL di call site
  /// (`f[w[N]](h, LUAR(...))` — `w[N]` adalah `'set'`). Indeksnya
  /// berputar per rilis (8 di fad7e4e9, 14 di ad8d59ae, 6 di b559f50c),
  /// jadi dibaca dari base.js, bukan di-hardcode.
  final int setMethodTableIndex;

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
    required this.urlClassName,
    required this.urlSetMethod,
    required this.urlSerializeMethod,
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

  /// Prelude minimal solver: tabel string + tiga fungsi signature +
  /// dependensi transitif rantai + alias `g`. Dievaluasi di runtime
  /// QuickJS yang sama dengan [source] (variabelnya global, tidak
  /// bentrok dengan salinan lokal di IIFE base.js).
  final String preludeCode;

  /// Nama kelas URL internal player (`_yt_player.<nama>`), dibaca dari
  /// base.js di dekat call site (`new g.bs(k.url,!0)`). Berputar per
  /// rilis: `tf` (fad7e4e9), `bs` (ad8d59ae), `JH` (b559f50c).
  final String urlClassName;

  /// Nama metode set parameter URL (`w[N]` di call site, `'set'` di
  /// ketiga hash yang diamati — tetap dibaca dari base.js).
  final String urlSetMethod;

  /// Nama metode serialisasi URL (yang menjalankan transform `n` saat
  /// membangun URL final): `gf` (fad7e4e9, b559f50c), `ff` (ad8d59ae).
  final String urlSerializeMethod;
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

/// Ekstrak tabel string `w` dari base.js.
///
/// Bentuk lama (s.d. fad7e4e9): `w='...'.split(";");` — kutip tunggal,
/// delimiter `;`. Bentuk baru (17 Nov 2026): `w="...".split("X");` —
/// kutip ganda, delimiter bervariasi per rilis (`;` di ad8d59ae, `{` di
/// b559f50c). Kedua bentuk diterima (lama dulu — rute tertentu masih
/// menyajikan fad7e4e9). Isi minimal 100 karakter supaya tidak salah
/// cocok dengan string pendek lain; `\"` di dalam isi ditangani.
/// Bila tidak ada yang cocok, kembalikan null (buildPlayerScript lalu
/// melempar unknownPlayerHash — gagal keras, bukan diam-diam).
String? extractStringTable(String baseJs) {
  final RegExpMatch? legacy = RegExp(
    "w='[^']*'\\.split\\(\";\"\\);",
  ).firstMatch(baseJs);
  if (legacy != null) return legacy.group(0);
  final RegExpMatch? current = RegExp(
    r'w="(?:\\.|[^"\\]){100,}"\.split\("[^"]{1,3}"\);',
  ).firstMatch(baseJs);
  return current?.group(0);
}

/// Uraikan pernyataan tabel string (`w='...'.split(";");` atau
/// `w="...".split("X");`, keluaran [extractStringTable]) menjadi daftar
/// token. Escape JS (`\"`, `\\`, `\n`, `\uXXXX`) diurai sebelum split.
/// Null bila bentuk tidak dikenali.
List<String>? parseStringTable(String tableStatement) {
  if (!tableStatement.startsWith('w=')) return null;
  if (tableStatement.length < 3) return null;
  final String quote = tableStatement[2];
  if (quote != '"' && quote != "'") return null;
  final StringBuffer content = StringBuffer();
  int i = 3;
  while (i < tableStatement.length) {
    final String ch = tableStatement[i];
    if (ch == r'\') {
      if (i + 1 >= tableStatement.length) return null;
      final String next = tableStatement[i + 1];
      if (next == 'n') {
        content.write('\n');
      } else if (next == 'r') {
        content.write('\r');
      } else if (next == 't') {
        content.write('\t');
      } else if (next == 'u' && i + 5 < tableStatement.length) {
        final int? codePoint = int.tryParse(
          tableStatement.substring(i + 2, i + 6),
          radix: 16,
        );
        if (codePoint == null) return null;
        content.write(String.fromCharCode(codePoint));
        i += 6;
        continue;
      } else {
        content.write(next);
      }
      i += 2;
    } else if (ch == quote) {
      break;
    } else {
      content.write(ch);
      i++;
    }
  }
  if (i >= tableStatement.length) return null;
  final String rest = tableStatement.substring(i + 1);
  final RegExpMatch? m = RegExp(
    r'^\.split\((.)(.{1,3})\1\);?$',
  ).firstMatch(rest);
  if (m == null) return null;
  return content.toString().split(m.group(2)!);
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

/// Pola rantai signature di call site: `TEMP = TENGAH(a,b,DALAM(a,b,X.s))`.
final RegExp _kSigChainPattern = RegExp(
  r'(?:var|let|const)\s+([A-Za-z0-9_$]+)\s*=\s*'
  r'([A-Za-z0-9_$]+)\((\d+),(\d+),'
  r'([A-Za-z0-9_$]+)\((\d+),(\d+),'
  r'[A-Za-z0-9_$]+\.s\)\)',
);

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
  final RegExpMatch? chain = _kSigChainPattern.firstMatch(baseJs);
  if (chain == null) return null;
  final String tempVar = chain.group(1)!;
  final String middleName = chain.group(2)!;
  final int middleA = int.parse(chain.group(3)!);
  final int middleB = int.parse(chain.group(4)!);
  final String innerName = chain.group(5)!;
  final int innerA = int.parse(chain.group(6)!);
  final int innerB = int.parse(chain.group(7)!);

  // Langkah 2: f[w[N]](h, AKHIR(a,b,tempVar)) di dekat call site (dalam
  // 500 karakter). Pembungkus `f[w[N]]` adalah pemanggilan metode set
  // URL — indeks N dibaca untuk [SigCallSite.setMethodTableIndex].
  final int searchEnd = (chain.end + 500).clamp(0, baseJs.length);
  final String window = baseJs.substring(chain.end, searchEnd);
  final RegExp outerPattern = RegExp(
    r'[A-Za-z0-9_$]+\[w\[(\d+)\]\]\([A-Za-z0-9_$]+,'
    r'([A-Za-z0-9_$]+)\((\d+),(\d+),'
    '${RegExp.escape(tempVar)}'
    r'\)\)',
  );
  final RegExpMatch? outer = outerPattern.firstMatch(window);
  if (outer == null) return null;
  final int setMethodTableIndex = int.parse(outer.group(1)!);
  final String outerName = outer.group(2)!;
  final int outerA = int.parse(outer.group(3)!);
  final int outerB = int.parse(outer.group(4)!);

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
    setMethodTableIndex: setMethodTableIndex,
  );
}

/// Cari objek helper di badan fungsi: identifier sebelum `[w[` yang bukan
/// parameter/lokal. Lokal dikumpulkan [_collectJsLocals] (parameter,
/// semua deklarator `var`/`let`/`const` termasuk yang sesudah koma,
/// parameter `catch`/arrow) — regex lama yang hanya mengambil deklarator
/// pertama sesudah `var` bisa salah mengira lokal `f` dari
/// `var e=...,f=[]` sebagai helper.
String? _findHelperObject(String functionBody) {
  final String blanked = _blankJsCode(functionBody);
  final Set<String> locals = _collectJsLocals(blanked);
  final RegExp usePattern = RegExp(r'([A-Za-z0-9_$]+)\[w\[');
  for (final RegExpMatch m in usePattern.allMatches(blanked)) {
    final String name = m.group(1)!;
    if (!locals.contains(name)) return name;
  }
  return null;
}

/// Global bawaan JavaScript yang tidak punya literal di base.js.
///
/// Bila helper call site adalah salah satunya (teramati: `String` di
/// base.js ad8d59ae, 17 Nov 2026 — cipher memakai `String[w[...]]`
/// seperti `String.fromCharCode`, dan metode string lewat parameter),
/// prelude tidak perlu memuat definisinya: QuickJS sudah
/// menyediakannya. Helper BUKAN builtin yang tidak ketemu literalnya
/// tetap gagal keras (kerusakan nyata).
///
/// Set yang sama dipakai kolektor dependensi transitif
/// ([_findJsReferences]): referensi ke nama-nama ini tidak dikejar ke
/// base.js. Baris kedua adalah global yang disediakan stub DOM
/// (`js_stubs.dart`) di runtime solver.
const Set<String> kJsBuiltinGlobals = <String>{
  'String',
  'Array',
  'Object',
  'Math',
  'Number',
  'Boolean',
  'JSON',
  'RegExp',
  'Date',
  'Map',
  'Set',
  'Symbol',
  'BigInt',
  'parseInt',
  'parseFloat',
  'isNaN',
  'isFinite',
  'decodeURIComponent',
  'encodeURIComponent',
  'decodeURI',
  'encodeURI',
  'eval',
  'escape',
  'unescape',
  'Error',
  'TypeError',
  'RangeError',
  'SyntaxError',
  'ReferenceError',
  'EvalError',
  'URIError',
  'AggregateError',
  'Promise',
  'Proxy',
  'Reflect',
  'WeakMap',
  'WeakSet',
  'WeakRef',
  'FinalizationRegistry',
  'ArrayBuffer',
  'SharedArrayBuffer',
  'DataView',
  'Int8Array',
  'Uint8Array',
  'Uint8ClampedArray',
  'Int16Array',
  'Uint16Array',
  'Int32Array',
  'Uint32Array',
  'Float32Array',
  'Float64Array',
  'BigInt64Array',
  'BigUint64Array',
  'Intl',
  'globalThis',
  'undefined',
  'NaN',
  'Infinity',
  // Stub DOM (js_stubs.dart).
  'window',
  'self',
  'top',
  'parent',
  'document',
  'navigator',
  'location',
  'history',
  'screen',
  'performance',
  'requestAnimationFrame',
  'cancelAnimationFrame',
  'setTimeout',
  'clearTimeout',
  'setInterval',
  'clearInterval',
  'localStorage',
  'sessionStorage',
  'console',
  'fetch',
  'XMLHttpRequest',
  'MutationObserver',
  'IntersectionObserver',
  'ResizeObserver',
  'CustomEvent',
  'Event',
  'Image',
  'Audio',
  'TextEncoder',
  'TextDecoder',
  'atob',
  'btoa',
  'crypto',
};

/// Kata kunci JS — bukan referensi variabel.
const Set<String> _kJsKeywords = <String>{
  'var',
  'let',
  'const',
  'function',
  'return',
  'if',
  'else',
  'for',
  'while',
  'do',
  'switch',
  'case',
  'default',
  'break',
  'continue',
  'new',
  'typeof',
  'void',
  'delete',
  'in',
  'of',
  'instanceof',
  'this',
  'true',
  'false',
  'null',
  'try',
  'catch',
  'finally',
  'throw',
  'with',
  'yield',
  'await',
  'async',
  'class',
  'extends',
  'super',
  'get',
  'set',
  'static',
};

final RegExp _kJsIdentifierPattern = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');

/// Indeks sesudah string berquote (`'`/`"`) yang dimulai di [start].
int _skipJsQuoted(String code, int start) {
  final String quote = code[start];
  int i = start + 1;
  while (i < code.length) {
    final String ch = code[i];
    if (ch == r'\') {
      i += 2;
    } else if (ch == quote) {
      return i + 1;
    } else {
      i++;
    }
  }
  return code.length;
}

/// Indeks sesudah literal regex yang dimulai di [start] (`/` pembuka).
int _skipJsRegex(String code, int start) {
  int i = start + 1;
  bool inClass = false;
  while (i < code.length) {
    final String ch = code[i];
    if (ch == r'\') {
      i += 2;
    } else if (ch == '[') {
      inClass = true;
      i++;
    } else if (ch == ']') {
      inClass = false;
      i++;
    } else if (ch == '/' && !inClass) {
      i++;
      break;
    } else if (ch == '\n') {
      break;
    } else {
      i++;
    }
  }
  while (i < code.length && 'dgimsuvy'.contains(code[i])) {
    i++;
  }
  return i;
}

/// Indeks sesudah kurung [close] yang menutup [open] di [start], sadar
/// string/template di dalamnya (dipakai untuk `${...}` dan daftar
/// parameter).
int _skipJsBalanced(String code, int start, String open, String close) {
  int depth = 0;
  int i = start;
  while (i < code.length) {
    final String ch = code[i];
    if (ch == '"' || ch == "'") {
      i = _skipJsQuoted(code, i);
    } else if (ch == '`') {
      i = _skipJsTemplate(code, i);
    } else if (ch == open) {
      depth++;
      i++;
    } else if (ch == close) {
      depth--;
      i++;
      if (depth == 0) return i;
    } else {
      i++;
    }
  }
  return code.length;
}

/// Indeks sesudah template literal yang dimulai di [start] (backtick).
int _skipJsTemplate(String code, int start) {
  int i = start + 1;
  while (i < code.length) {
    final String ch = code[i];
    if (ch == r'\') {
      i += 2;
    } else if (ch == '`') {
      return i + 1;
    } else if (ch == r'$' && i + 1 < code.length && code[i + 1] == '{') {
      i = _skipJsBalanced(code, i + 1, '{', '}');
    } else {
      i++;
    }
  }
  return code.length;
}

/// Blank-kan isi string/komentar/regex dari [code] dengan spasi
/// (panjang dipertahankan supaya posisi tidak bergeser). Isi interpolasi
/// `${...}` template literal TETAP kode (diblank-kan rekursif) karena
/// bisa memuat referensi variabel.
///
/// Tanpa blanking ini, pemindai referensi bisa salah mengira isi string
/// (`"Vm("` di pesan error) atau isi regex sebagai dependensi.
String _blankJsCode(String code) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  String prevSig = '';
  while (i < code.length) {
    final String ch = code[i];
    if (ch == '"' || ch == "'") {
      final int end = _skipJsQuoted(code, i);
      out.write(' ' * (end - i));
      i = end;
      prevSig = 's';
    } else if (ch == '`') {
      i = _blankJsTemplate(code, i, out);
      prevSig = 's';
    } else if (ch == '/' && i + 1 < code.length && code[i + 1] == '/') {
      int end = code.indexOf('\n', i);
      if (end < 0) end = code.length;
      out.write(' ' * (end - i));
      i = end;
    } else if (ch == '/' && i + 1 < code.length && code[i + 1] == '*') {
      int end = code.indexOf('*/', i + 2);
      end = end < 0 ? code.length : end + 2;
      out.write(' ' * (end - i));
      i = end;
    } else if (ch == '/' &&
        (prevSig.isEmpty || '(,=:[!&|?{};'.contains(prevSig))) {
      // Literal regex: '/' sesudah operator/pembuka (heuristik standar;
      // '/' sesudah nilai adalah pembagian).
      final int end = _skipJsRegex(code, i);
      out.write(' ' * (end - i));
      i = end;
      prevSig = 's';
    } else {
      out.write(ch);
      if (ch.trim().isNotEmpty) prevSig = ch;
      i++;
    }
  }
  return out.toString();
}

/// Blank-kan satu template literal (mulai di backtick [start]) ke [out]:
/// bagian literal jadi spasi, isi `${...}` diblank-kan rekursif sebagai
/// kode. Mengembalikan indeks sesudah backtick penutup.
int _blankJsTemplate(String code, int start, StringBuffer out) {
  out.write(' ');
  int i = start + 1;
  while (i < code.length) {
    final String ch = code[i];
    if (ch == r'\') {
      out.write('  ');
      i += 2;
    } else if (ch == '`') {
      out.write(' ');
      return i + 1;
    } else if (ch == r'$' && i + 1 < code.length && code[i + 1] == '{') {
      final int end = _skipJsBalanced(code, i + 1, '{', '}');
      out.write('  ');
      out.write(_blankJsCode(code.substring(i + 2, end - 1)));
      out.write(' ');
      i = end;
    } else {
      out.write(' ');
      i++;
    }
  }
  return code.length;
}

void _addJsParamList(Set<String> locals, String params) {
  for (final String part in params.split(',')) {
    final String name = part.split('=')[0].trim();
    if (name.isNotEmpty &&
        _kJsIdentifierPattern.stringMatch(name) == name) {
      locals.add(name);
    }
  }
}

/// Kumpulkan deklarator `var`/`let`/`const` dari [blanked] (kode yang
/// sudah diblank-kan string-nya) ke [locals]. Parser mini ini menangani
/// daftar koma (`var e=...,f=[]` — `f` adalah lokal) dan destructuring
/// (`var {a, b: c} = ...` — lokalnya `a` dan `c`, bukan kunci `b`),
/// yang dilewatkan regex sederhana.
void _collectJsDeclarators(String blanked, Set<String> locals) {
  final RegExp decl = RegExp(r'(?:^|[^A-Za-z0-9_$])(?:var|let|const)\s+');
  for (final RegExpMatch m in decl.allMatches(blanked)) {
    int i = m.end;
    while (i < blanked.length) {
      while (i < blanked.length && blanked[i].trim().isEmpty) {
        i++;
      }
      if (i >= blanked.length) break;
      if (blanked[i] == '{' || blanked[i] == '[') {
        final String open = blanked[i];
        final String close = open == '{' ? '}' : ']';
        final int end = _skipJsBalanced(blanked, i, open, close);
        final String inner = blanked.substring(i + 1, end - 1);
        for (final RegExpMatch im in
            _kJsIdentifierPattern.allMatches(inner)) {
          int k = im.end;
          while (k < inner.length && inner[k].trim().isEmpty) {
            k++;
          }
          if (k >= inner.length || inner[k] != ':') {
            locals.add(im.group(0)!);
          }
        }
        i = end;
      } else {
        final Match? im =
            _kJsIdentifierPattern.matchAsPrefix(blanked, i);
        if (im == null) break;
        locals.add(im.group(0)!);
        i = im.end;
      }
      while (i < blanked.length && blanked[i].trim().isEmpty) {
        i++;
      }
      if (i < blanked.length && blanked[i] == '=') {
        // Lewati initializer sampai ',' / ';' / ')' di kedalaman 0.
        i++;
        int depth = 0;
        while (i < blanked.length) {
          final String ch = blanked[i];
          if (ch == '(' || ch == '[' || ch == '{') {
            depth++;
          } else if (ch == ')' || ch == ']' || ch == '}') {
            if (depth == 0) break;
            depth--;
          } else if (depth == 0 && (ch == ',' || ch == ';')) {
            break;
          }
          i++;
        }
      }
      while (i < blanked.length && blanked[i].trim().isEmpty) {
        i++;
      }
      if (i < blanked.length && blanked[i] == ',') {
        i++;
        continue;
      }
      break;
    }
  }
}

/// Kumpulkan nama lokal dari badan definisi yang SUDAH diblank-kan
/// ([_blankJsCode]): parameter fungsi/arrow, nama fungsi/class,
/// parameter `catch`, dan semua deklarator `var`/`let`/`const`.
///
/// Batasan: nama di dalam parameter destructuring
/// (`function({a}){}`) tidak dikumpulkan — pola itu tidak muncul di
/// fungsi cipher ter-minifikasi yang diamati.
Set<String> _collectJsLocals(String blanked) {
  final Set<String> locals = <String>{};
  for (final RegExpMatch m in RegExp(
    r'(?:^|[^A-Za-z0-9_$])function(?:\s+([A-Za-z_$][A-Za-z0-9_$]*))?'
    r'\s*\(([^)]*)\)',
  ).allMatches(blanked)) {
    final String? name = m.group(1);
    if (name != null) locals.add(name);
    _addJsParamList(locals, m.group(2)!);
  }
  for (final RegExpMatch m in RegExp(
    r'\(([^)]*)\)\s*=>',
  ).allMatches(blanked)) {
    _addJsParamList(locals, m.group(1)!);
  }
  for (final RegExpMatch m in RegExp(
    r'(?:^|[^A-Za-z0-9_$])([A-Za-z_$][A-Za-z0-9_$]*)\s*=>',
  ).allMatches(blanked)) {
    locals.add(m.group(1)!);
  }
  for (final RegExpMatch m in RegExp(
    r'(?:^|[^A-Za-z0-9_$])catch\s*\(\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*\)',
  ).allMatches(blanked)) {
    locals.add(m.group(1)!);
  }
  for (final RegExpMatch m in RegExp(
    r'(?:^|[^A-Za-z0-9_$])class\s+([A-Za-z_$][A-Za-z0-9_$]*)',
  ).allMatches(blanked)) {
    locals.add(m.group(1)!);
  }
  _collectJsDeclarators(blanked, locals);
  return locals;
}

/// Referensi global dari satu definisi (fungsi/objek): identifier yang
/// dipakai sebagai `IDENT[w[...]]` (objek helper) atau `IDENT(...)`
/// (panggilan fungsi, termasuk `?.(`), BUKAN properti (`.IDENT`),
/// bukan lokal/parameter, bukan keyword, bukan global bawaan, dan bukan
/// tabel `w`.
///
/// Definisi metode shorthand (`m(a){...}`) dikecualikan: `IDENT(...)`
/// yang langsung diikuti `{` adalah definisi, bukan panggilan (di kode
/// ter-minifikasi, panggilan selalu diikuti `;`/operator).
/// Referensi telanjang (`return Foo`) sengaja TIDAK dikejar: di badan
/// fungsi cipher, identifier telanjang adalah decoy cabang mati
/// (`Baa..Taa` di `ld` ad8d59ae) yang definisinya tidak pernah dipakai
/// jalur hidup — mengejarnya menggelembungkan prelude dari 20 menjadi
/// 95 definisi (terukur di ad8d59ae) tanpa manfaat.
Set<String> _findJsReferences(String definition) {
  final String blanked = _blankJsCode(definition);
  final Set<String> locals = _collectJsLocals(blanked);
  final Set<String> refs = <String>{};
  final RegExp usePattern = RegExp(
    r'([A-Za-z_$][A-Za-z0-9_$]*)\s*(?:\[w\[|\?\.\[w\[|\(|\?\.\()',
  );
  for (final RegExpMatch m in usePattern.allMatches(blanked)) {
    final String name = m.group(1)!;
    if (_kJsKeywords.contains(name) ||
        kJsBuiltinGlobals.contains(name) ||
        locals.contains(name) ||
        name == 'w') {
      continue;
    }
    if (m.start > 0 && blanked[m.start - 1] == '.') continue;
    final String tail = m.group(0)!;
    if (tail.endsWith('(')) {
      final int paren = m.end - 1;
      final int end = _skipJsBalanced(blanked, paren, '(', ')');
      int k = end;
      while (k < blanked.length && blanked[k].trim().isEmpty) {
        k++;
      }
      if (k < blanked.length && blanked[k] == '{') continue;
    }
    refs.add(name);
  }
  return refs;
}

/// Definisi top-level `NAME`: fungsi `NAME=function...` dulu, lalu
/// literal objek `NAME={...}`. Null bila tidak ada keduanya.
String? _extractDefinition(String baseJs, String name) =>
    extractFunction(baseJs, name) ?? extractObjectLiteral(baseJs, name);

/// Batas jumlah definisi prelude (pengaman terhadap base.js patologis
/// yang rantainya meledak; terukur: ad8d59ae 20, b559f50c 13,
/// fad7e4e9 4). BFS menjamin dependensi terdekat dari rantai
/// didahulukan, jadi pemotongan hanya membuang cincin terjauh.
const int kMaxPreludeDependencies = 64;

/// Kumpulkan dependensi TRANSITIF rantai signature (BFS dari [seeds]):
/// untuk tiap definisi, cari referensi globalnya ([_findJsReferences])
/// lalu ambil definisinya dari [baseJs]. Nama tanpa definisi di base.js
/// (decoy cabang mati seperti `Taa`, parameter IIFE `g`) dilewati —
/// tidak ada yang bisa dimuat untuknya.
///
/// Mengembalikan definisi dalam urutan penemuan BFS (seed dulu).
Map<String, String> _collectTransitiveDependencies(
  String baseJs,
  Map<String, String> seeds,
) {
  final Map<String, String> collected = Map<String, String>.from(seeds);
  final List<String> queue = seeds.keys.toList();
  int head = 0;
  while (head < queue.length &&
      collected.length < kMaxPreludeDependencies) {
    final String definition = collected[queue[head++]]!;
    for (final String ref in _findJsReferences(definition)) {
      if (collected.containsKey(ref)) continue;
      final String? refDef = _extractDefinition(baseJs, ref);
      if (refDef == null) continue;
      collected[ref] = refDef;
      queue.add(ref);
      if (collected.length >= kMaxPreludeDependencies) break;
    }
  }
  return collected;
}

/// Ekstrak definisi kelas top-level `g.NAME=class{...}` dengan
/// pencocokan kurung kurawal (sadar string).
String? extractClassDefinition(String baseJs, String name) {
  final RegExp pattern = RegExp(
    '(?:^|[^A-Za-z0-9_\$])g\\.${RegExp.escape(name)}=class',
  );
  final RegExpMatch? match = pattern.firstMatch(baseJs);
  if (match == null) return null;
  final int start = match.start + match.group(0)!.indexOf('g.');
  return _extractBraced(baseJs, start);
}

/// Nama metode serialisasi URL dari badan kelas URL.
///
/// Pola utama (diamati di bs/JH/tf): metode tanpa parameter yang
/// menghitung sekali lalu mengembalikan string cache —
/// `ff(){this[w[1]]||(this[w[1]]=mB(19,1665,this));return this[w[1]]}`.
/// Cadangan: satu-satunya metode di luar {constructor, set, get, clone,
/// ...} — nama-nama yang sudah pasti bukan serializer.
String? _findUrlSerializeMethod(String classBody) {
  final RegExpMatch? cached = RegExp(
    r'([A-Za-z0-9_$]+)\(\)\{this\[w\[(\d+)\]\]\|\|'
    r'\(this\[w\[\2\]\]=[A-Za-z0-9_$]+\(\d+,\d+,this\)\);'
    r'return this\[w\[\2\]\]\}',
  ).firstMatch(classBody);
  if (cached != null) return cached.group(1);
  const Set<String> notSerializer = <String>{
    'constructor',
    'set',
    'get',
    'clone',
    'toString',
    'has',
    'delete',
    'keys',
    'values',
    'entries',
    'forEach',
    'clear',
  };
  final String blanked = _blankJsCode(classBody);
  final Set<String> candidates = <String>{};
  final RegExp methodPattern =
      RegExp(r'([A-Za-z_$][A-Za-z0-9_$]*)\s*\(');
  for (final RegExpMatch m in methodPattern.allMatches(blanked)) {
    final String name = m.group(1)!;
    if (_kJsKeywords.contains(name) || notSerializer.contains(name)) {
      continue;
    }
    if (m.start > 0 && blanked[m.start - 1] == '.') continue;
    // Definisi metode: `NAMA(...)` langsung diikuti `{` (panggilan
    // diikuti `;`/operator/).
    final int paren = m.end - 1;
    final int end = _skipJsBalanced(blanked, paren, '(', ')');
    int k = end;
    while (k < blanked.length && blanked[k].trim().isEmpty) {
      k++;
    }
    if (k < blanked.length && blanked[k] == '{') candidates.add(name);
  }
  if (candidates.length == 1) return candidates.single;
  return null;
}

/// Ekstrak info pemutar URL dari base.js: nama kelas URL internal,
/// nama metode set, dan nama metode serialisasi. Null bila ada bagian
/// yang tidak ketemu (player berubah).
///
/// - Kelas: `new g.XX(var.url)` TERAKHIR sebelum call site rantai
///   (di fungsi yang sama dengan pemanggilan cipher — jarak 42 karakter
///   di ad8d59ae dan b559f50c).
/// - Metode set: `w[N]` dari [SigCallSite.setMethodTableIndex], diurai
///   lewat [table] (harus identifier JS yang valid).
/// - Serialisasi: [_findUrlSerializeMethod] pada badan kelas.
({String className, String setMethod, String serializeMethod})?
    _extractUrlInfo(
  String baseJs,
  SigCallSite callSite,
  List<String> table,
) {
  final int setIndex = callSite.setMethodTableIndex;
  if (setIndex < 0 || setIndex >= table.length) return null;
  final String setMethod = table[setIndex];
  if (_kJsIdentifierPattern.stringMatch(setMethod) != setMethod) {
    return null;
  }
  final RegExpMatch? chain = _kSigChainPattern.firstMatch(baseJs);
  if (chain == null) return null;
  final RegExp urlClassPattern =
      RegExp(r'new g\.([A-Za-z0-9_$]+)\([A-Za-z0-9_$]+\.url');
  String? className;
  for (final RegExpMatch m in urlClassPattern
      .allMatches(baseJs.substring(0, chain.start))) {
    className = m.group(1);
  }
  if (className == null) return null;
  final String? classBody = extractClassDefinition(baseJs, className);
  if (classBody == null) return null;
  final String? serializeMethod = _findUrlSerializeMethod(classBody);
  if (serializeMethod == null) return null;
  return (
    className: className,
    setMethod: setMethod,
    serializeMethod: serializeMethod,
  );
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
  final List<String>? tableTokens =
      table == null ? null : parseStringTable(table);
  if (hash == null ||
      sts == null ||
      callSite == null ||
      table == null ||
      tableTokens == null) {
    throw ExtractorException(
      ResolveFailureCause.unknownPlayerHash,
      detail:
          'ekstraksi base.js gagal '
          '(hash: ${hash != null}, sts: ${sts != null}, '
          'callSite: ${callSite != null}, table: ${table != null}, '
          'tableTokens: ${tableTokens != null})',
    );
  }
  final String? innerFn = extractFunction(baseJs, callSite.innerName);
  final String? middleFn = extractFunction(baseJs, callSite.middleName);
  final String? outerFn = extractFunction(baseJs, callSite.outerName);
  final String? helperObj = extractObjectLiteral(
    baseJs,
    callSite.helperObjectName,
  );
  if (innerFn == null || middleFn == null || outerFn == null) {
    throw const ExtractorException(
      ResolveFailureCause.unknownPlayerHash,
      detail: 'definisi fungsi signature tidak ketemu di base.js',
    );
  }
  if (helperObj == null &&
      !kJsBuiltinGlobals.contains(callSite.helperObjectName)) {
    throw ExtractorException(
      ResolveFailureCause.unknownPlayerHash,
      detail: 'literal objek helper ${callSite.helperObjectName} '
          'tidak ketemu di base.js',
    );
  }
  final ({String className, String setMethod, String serializeMethod})?
      urlInfo = _extractUrlInfo(baseJs, callSite, tableTokens);
  if (urlInfo == null) {
    throw const ExtractorException(
      ResolveFailureCause.unknownPlayerHash,
      detail: 'info kelas URL (g.XX/set/serialisasi) tidak ketemu '
          'di base.js',
    );
  }
  // Dependensi TRANSITIF: prelude lama hanya memuat 3 fungsi + 1 objek
  // helper, sehingga rantai cipher yang memakai helper lain (teramati:
  // `Vm` di ad8d59ae, 17 Nov 2026 — `Xm` memanggil `Vm[w[...]]` tapi
  // prelude hanya memuat helper pertama yang ketemu, `String`) gagal
  // `ReferenceError` saat solve. Kumpulkan semua definisi yang dirujuk
  // rantai, rekursif — bukan hanya helper pertama.
  final Map<String, String> seeds = <String, String>{
    callSite.innerName: innerFn,
    callSite.middleName: middleFn,
    callSite.outerName: outerFn,
  };
  if (helperObj != null) seeds[callSite.helperObjectName] = helperObj;
  final Map<String, String> definitions =
      _collectTransitiveDependencies(baseJs, seeds);
  final String prelude = <String>[
    table,
    // Alias parameter IIFE: base.js berjalan sebagai
    // `(function(g){...})(_yt_player)` — dependensi rantai memakai
    // `g.jr`/`g.Um`/`g.O` (properti `_yt_player` yang sudah terisi saat
    // sumber dievaluasi, sebelum prelude). Tanpa alias ini definisi
    // tersebut gagal `ReferenceError: g is not defined` bila cabangnya
    // hidup di hash mendatang. Dilewati bila `g` ternyata nama definisi
    // rantai (tabrakan — definisi asli menang).
    if (!definitions.containsKey('g')) 'var g = _yt_player;',
    for (final String definition in definitions.values) '$definition;',
  ].join('\n');
  return PlayerScript(
    jsUrl: jsUrl,
    hash: hash,
    signatureTimestamp: sts,
    source: baseJs,
    sigCallSite: callSite,
    preludeCode: prelude,
    urlClassName: urlInfo.className,
    urlSetMethod: urlInfo.setMethod,
    urlSerializeMethod: urlInfo.serializeMethod,
  );
}

/// Skrip driver solver: hitung signature dari cipher lalu bangun URL final
/// lewat kelas URL internal player (`_yt_player.<urlClassName>`), yang
/// sekaligus menjalankan transform `n` saat serialisasi.
///
/// Nama kelas/metode dibaca dari base.js per hash ([PlayerScript.urlClassName]
/// dkk.) — ketiganya identifier JS valid hasil pencocokan pola ketat,
/// jadi aman diinterpolasi ke skrip. [cipherUrl], [cipheredS], dan
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
var __u = new _yt_player.${script.urlClassName}(${jsonEncode(cipherUrl)}, true);
__u.${script.urlSetMethod}(${jsonEncode(sigParam)}, decodeURIComponent(__sig));
__u.${script.urlSerializeMethod}();
''';
}

/// Seluruh skrip yang dievaluasi sekali saat inisialisasi solver:
/// stub DOM + sumber base.js + prelude signature.
String buildSolverInitScript(PlayerScript script) =>
    '$kJsDomStubs\n${script.source}\n${script.preludeCode}\n';
