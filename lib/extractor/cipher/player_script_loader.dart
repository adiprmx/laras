/// Loader script player: HTML youtube.com -> jsUrl -> base.js -> ekstraksi.
///
/// Cache di memori: bila hash jsUrl dari HTML terbaru sama dengan yang
/// sudah dimuat, sumber base.js tidak diunduh ulang (hemat ~2,7 MB tiap
/// resolve). Cache memori hilang saat app ditutup; P2 boleh menambah cache
/// disk (base.js bukan URL stream, jadi boleh disimpan).
///
/// Fallback varian (P0, 16 Nov 2026): YouTube mulai melayani varian
/// `player_es6_tcl` yang memakai obfuscation baru (tabel string `g.d` +
/// indeks XOR) sehingga pola ekstraksi perilaku app tidak cocok lagi
/// (call site + tabel string tidak ketemu -> unknownPlayerHash). Varian
/// non-tcl dengan hash yang sama masih dilayani dan masih bisa diekstrak
/// (terbukti probe P0: HTTP 200, 2.677.001 byte, rantai signature utuh,
/// sts lama 20767 masih diterima request player). Bila ekstraksi varian
/// dari HTML gagal, loader mencoba varian non-tcl dengan hash yang sama
/// sebelum menyerah. Fallback ini hanya mengubah infiks path, tidak
/// menebak hash dan tidak memakai pola dari extractor lain.
library;

// ignore_for_file: prefer_initializing_formals - konstruktor publik memakai
// parameter bernama publik + field privat; initializing formal akan
// membuat nama parameter menjadi privat dan tidak bisa dipakai pemanggil.

import 'dart:async';

import '../errors.dart';
import '../innertube_client.dart';
import '../remote_config.dart';
import '../response_limits.dart';
import 'player_script.dart';

/// Mengunduh dan mengekstrak script player, dengan cache memori per hash.
class PlayerScriptLoader {
  PlayerScriptLoader({required InnertubeClient client}) : _client = client;

  final InnertubeClient _client;

  PlayerScript? _cached;
  Future<PlayerScript>? _inFlight;

  /// Script yang sudah dimuat di memori, bila ada (tanpa jaringan).
  ///
  /// Dipakai orkestrator untuk mengambil signatureTimestamp tanpa
  /// membayar fetch HTML di tiap resolve.
  PlayerScript? get cached => _cached;

  /// Muat script player yang berlaku saat ini.
  ///
  /// [forceRefresh] mengabaikan cache dan mengunduh ulang dari HTML.
  /// [allowedHashes] adalah allowlist hash player (dari config remote);
  /// null atau kosong berarti pakai hash bawaan ([kBuiltinPlayerHashes]).
  /// Hash yang tidak ada di allowlist DITOLAK SEBELUM base.js diunduh,
  /// apalagi dieksekusi (R1-M2, rencana §3.4): base.js dengan hash tak
  /// dikenal tidak pernah mencapai solver. Melempar [ExtractorException]
  /// penyebab unknownPlayerHash bila hash tidak dikenal atau ekstraksi
  /// gagal, atau emptyResponse bila jaringan gagal.
  Future<PlayerScript> load({
    bool forceRefresh = false,
    Set<String>? allowedHashes,
  }) {
    final Set<String> allowed = _effectiveAllowlist(allowedHashes);
    final Future<PlayerScript>? inFlight = _inFlight;
    if (inFlight != null) {
      // Single-flight: pemanggil lain menunggu job yang sama — tapi job
      // itu digerbang dengan allowlist pemanggil pertama, jadi hasilnya
      // diperiksa ulang terhadap allowlist pemanggil ini sebelum
      // dikembalikan.
      return inFlight.then((PlayerScript script) {
        _requireAllowed(script.hash, allowed);
        return script;
      });
    }
    final Future<PlayerScript> job = _load(
      forceRefresh: forceRefresh,
      allowedHashes: allowed,
    );
    _inFlight = job;
    // Single-flight: pemanggil lain menunggu job yang sama.
    // then<void> dengan badan blok (bukan whenComplete dan bukan arrow):
    // whenComplete mengembalikan Future baru yang ikut membawa error job
    // tanpa pendengar -> unhandled async error; arrow function akan
    // mengembalikan nilai `_inFlight = null` (null, aman) TAPI pola yang
    // sama di orkestrator terbukti berbahaya bila nilai yang dikembalikan
    // adalah Future yang error - jadi pakai badan blok secara konsisten.
    unawaited(
      job.then<void>(
        (_) {
          _inFlight = null;
        },
        onError: (_) {
          _inFlight = null;
        },
      ),
    );
    return job;
  }

  Future<PlayerScript> _load({
    required bool forceRefresh,
    required Set<String> allowedHashes,
  }) async {
    final PlayerScript? cached = _cached;
    // HTML youtube.com memberi jsUrl terbaru (hash bisa berubah tiap rilis
    // player, biasanya beberapa hari sekali).
    // Timeout 60 detik (dinaikkan dari 30 di P0): fetch HTML yang sah
    // dari VM memakan 41,2 detik di probe 16 Nov 2026 - timeout 30 detik
    // akan membunuhnya.
    final String html = await _client.fetchText(
      'https://www.youtube.com/',
      maxBytes: ResponseLimits.youtubeHtmlBytes,
      timeout: const Duration(seconds: 60),
    );
    final String? jsUrl = extractJsUrl(html);
    if (jsUrl == null) {
      // Hash cache diperiksa ulang: hash yang sudah dicabut dari
      // allowlist (config remote terbaru) tidak boleh dipakai lagi
      // walau script-nya masih tersimpan di memori.
      if (cached != null && allowedHashes.contains(cached.hash)) {
        return cached;
      }
      throw const ExtractorException(
        ResolveFailureCause.unknownPlayerHash,
        detail: 'jsUrl tidak ketemu di HTML youtube.com',
      );
    }
    final String? hash = extractPlayerHash(jsUrl);
    if (!forceRefresh && cached != null && hash == cached.hash) {
      if (allowedHashes.contains(cached.hash)) return cached;
      // Cache-nya sudah tidak diizinkan: lanjut ke gerbang di bawah
      // (hash yang sama akan ditolak sebelum mengunduh).
    }
    // R1-M2 — GERBANG HASH: hash dari jsUrl diperiksa SEBELUM base.js
    // diunduh. Hash tak dikenal = player baru yang belum ditinjau =
    // tidak diunduh, tidak diekstrak, tidak dieksekusi. Hash baru masuk
    // lewat config remote (playerHashes), bukan lewat rilis app.
    // Konsisten dengan fallback non-tcl P0: varian tcl dan non-tcl
    // memakai hash yang SAMA, jadi gerbang ini tidak membedakan keduanya
    // — yang dieksekusi selalu varian non-tcl karena varian tcl gagal
    // di ekstraksi (di bawah) sebelum mencapai solver.
    if (hash == null || !allowedHashes.contains(hash)) {
      throw const ExtractorException(
        ResolveFailureCause.unknownPlayerHash,
        detail: 'hash player tidak ada di daftar yang dikenal',
      );
    }
    // Timeout 90 detik (dinaikkan dari 60 di P0): unduh base.js 2,9 MB
    // yang sah dari VM memakan 52 detik di probe 16 Nov 2026 - margin
    // timeout 60 detik terlalu tipis untuk jaringan lambat.
    final String baseJs = await _client.fetchText(
      'https://www.youtube.com$jsUrl',
      maxBytes: ResponseLimits.playerScriptBytes,
      timeout: const Duration(seconds: 90),
    );
    PlayerScript script;
    try {
      script = buildPlayerScript(jsUrl, baseJs);
    } on ExtractorException catch (e) {
      // Hanya kegagalan EKSTRAKSI yang memicu fallback varian. Kegagalan
      // jaringan tidak ditangkap di sini (fetchText sudah melempar
      // sebelum baris ini) dan langsung diteruskan sebagai error jaringan.
      if (e.cause != ResolveFailureCause.unknownPlayerHash) rethrow;
      final String? fallbackUrl = _nonTclVariantUrl(jsUrl);
      if (fallbackUrl == null) rethrow;
      final String fallbackJs = await _client.fetchText(
        'https://www.youtube.com$fallbackUrl',
        maxBytes: ResponseLimits.playerScriptBytes,
        timeout: const Duration(seconds: 90),
      );
      script = buildPlayerScript(fallbackUrl, fallbackJs);
    }
    // Defense in depth (di luar try fallback: gagal gerbang TIDAK boleh
    // memicu unduh varian — hash-nya sama, hasilnya akan sama): hash
    // hasil ekstraksi harus sama dengan hash yang sudah digerbang.
    _requireAllowed(script.hash, allowedHashes);
    _cached = script;
    return script;
  }

  /// Allowlist efektif: yang diberikan pemanggil bila tidak kosong,
  /// kalau tidak hash bawaan. Config remote yang tidak membawa hash
  /// (kolom kosong) tidak boleh mematikan semua pemutaran — bawaan
  /// adalah hash yang sudah ditinjau.
  static Set<String> _effectiveAllowlist(Set<String>? allowedHashes) {
    if (allowedHashes == null || allowedHashes.isEmpty) {
      return kBuiltinPlayerHashes.keys.toSet();
    }
    return allowedHashes;
  }

  /// Lempar unknownPlayerHash bila [hash] tidak ada di [allowed].
  static void _requireAllowed(String hash, Set<String> allowed) {
    if (!allowed.contains(hash)) {
      throw const ExtractorException(
        ResolveFailureCause.unknownPlayerHash,
        detail: 'hash player tidak ada di daftar yang dikenal',
      );
    }
  }

  /// Varian non-tcl dari [jsUrl], bila jsUrl adalah varian `tcl`.
  ///
  /// Hanya infiks `player_es6_tcl` yang diganti `player_es6`; hash dan
  /// sisa path tidak diubah. Null bila jsUrl bukan varian tcl (tidak ada
  /// fallback yang bisa dibangun).
  static String? _nonTclVariantUrl(String jsUrl) {
    if (!jsUrl.contains('player_es6_tcl')) return null;
    return jsUrl.replaceFirst('player_es6_tcl', 'player_es6');
  }
}
