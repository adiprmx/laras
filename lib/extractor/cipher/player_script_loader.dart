/// Loader script player: HTML youtube.com -> jsUrl -> base.js -> ekstraksi.
///
/// Cache di memori: bila hash jsUrl dari HTML terbaru sama dengan yang
/// sudah dimuat, sumber base.js tidak diunduh ulang (hemat 2,6 MB tiap
/// resolve). Cache memori hilang saat app ditutup; P2 boleh menambah cache
/// disk (base.js bukan URL stream, jadi boleh disimpan).
library;

// ignore_for_file: prefer_initializing_formals - konstruktor publik memakai
// parameter bernama publik + field privat; initializing formal akan
// membuat nama parameter menjadi privat dan tidak bisa dipakai pemanggil.

import 'dart:async';

import '../errors.dart';
import '../innertube_client.dart';
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
  /// Melempar [ExtractorException] penyebab unknownPlayerHash bila
  /// ekstraksi gagal, atau emptyResponse bila jaringan gagal.
  Future<PlayerScript> load({bool forceRefresh = false}) {
    final Future<PlayerScript>? inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final Future<PlayerScript> job = _load(forceRefresh: forceRefresh);
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

  Future<PlayerScript> _load({required bool forceRefresh}) async {
    final PlayerScript? cached = _cached;
    // HTML youtube.com memberi jsUrl terbaru (hash bisa berubah tiap rilis
    // player, biasanya beberapa hari sekali).
    final String html = await _client.fetchText(
      'https://www.youtube.com/',
      maxBytes: 4 * 1024 * 1024,
      timeout: const Duration(seconds: 30),
    );
    final String? jsUrl = extractJsUrl(html);
    if (jsUrl == null) {
      if (cached != null) return cached;
      throw const ExtractorException(
        ResolveFailureCause.unknownPlayerHash,
        detail: 'jsUrl tidak ketemu di HTML youtube.com',
      );
    }
    final String? hash = extractPlayerHash(jsUrl);
    if (!forceRefresh && cached != null && hash == cached.hash) {
      return cached;
    }
    final String baseJs = await _client.fetchText(
      'https://www.youtube.com$jsUrl',
      maxBytes: 8 * 1024 * 1024,
      timeout: const Duration(seconds: 60),
    );
    final PlayerScript script = buildPlayerScript(jsUrl, baseJs);
    _cached = script;
    return script;
  }
}
