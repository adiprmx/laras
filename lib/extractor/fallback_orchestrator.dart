/// Orkestrator fallback antar client: [StreamResolver].
///
/// Alur resolve satu lagu:
/// 1. Ambil config remote (urutan client + versi).
/// 2. Muat script player (cache memori; unduh bila belum ada) untuk
///    signatureTimestamp (sts). sts WAJIB di request player PERTAMA:
///    terbukti 16 Nov 2026, request tanpa sts dibalas UNPLAYABLE
///    ("The page needs to be reloaded.") walau visitorData ada.
/// 3. Untuk tiap client dalam urutan fallback:
///    a. Request player DENGAN sts (bila LOGIN_REQUIRED, refresh
///       visitorData + muat ulang script dan ulangi sekali).
///    b. Parse respons; pilih format audio (pemilih itag, urutan kualitas
///       atau hemat data).
///    c. Format URL langsung -> selesai. Format cipher -> solver QuickJS
///       -> selesai.
///    d. Kegagalan apa pun -> client berikutnya.
/// 4. Semua client habis -> lempar [ExtractorException] dengan penyebab
///    yang paling informatif (bukan jaringan bila ada penyebab lain).
///
/// Single-flight per videoId: dua resolve bersamaan untuk lagu yang sama
/// memakai satu pekerjaan. Log resolve (tanpa URL) disimpan di memori
/// untuk layar demo dan diagnosis.
library;

// ignore_for_file: prefer_initializing_formals - konstruktor publik memakai
// parameter bernama publik + field privat; initializing formal akan
// membuat nama parameter menjadi privat dan tidak bisa dipakai pemanggil.

import 'dart:async';

import 'cipher/player_script.dart';
import 'cipher/player_script_loader.dart';
import 'cipher/signature_solver.dart';
import 'client_definitions.dart';
import 'errors.dart';
import 'innertube_client.dart';
import 'itag_picker.dart';
import 'models.dart';
import 'remote_config.dart';

/// Satu baris log resolve (tanpa URL stream).
class ResolveLogEntry {
  const ResolveLogEntry({
    required this.timestamp,
    required this.videoId,
    required this.clientName,
    required this.outcome,
    required this.durationMs,
  });

  final DateTime timestamp;
  final String videoId;
  final String clientName;
  final String outcome;
  final int durationMs;

  @override
  String toString() =>
      '${timestamp.toIso8601String()} $videoId [$clientName] '
      '$outcome ${durationMs}ms';
}

/// Orkestrator resolve + fallback.
class StreamResolver {
  StreamResolver({
    required InnertubeClient innertube,
    required SignatureSolver solver,
    required RemoteConfigLoader configLoader,
    required PlayerScriptLoader scriptLoader,
  }) : _innertube = innertube,
       _solver = solver,
       _configLoader = configLoader,
       _scriptLoader = scriptLoader;

  final InnertubeClient _innertube;
  final SignatureSolver _solver;
  final RemoteConfigLoader _configLoader;
  final PlayerScriptLoader _scriptLoader;

  final Map<String, Future<ResolvedAudio>> _inFlight = <String, Future<ResolvedAudio>>{};
  final List<ResolveLogEntry> _log = <ResolveLogEntry>[];

  /// Log resolve terakhir (maks 50 baris, tanpa URL).
  List<ResolveLogEntry> get recentLog => List<ResolveLogEntry>.unmodifiable(_log);

  /// Resolve satu lagu menjadi URL audio siap putar.
  Future<ResolvedAudio> resolve(String videoId, {bool dataSaver = false}) {
    final Future<ResolvedAudio>? existing = _inFlight[videoId];
    if (existing != null) return existing;
    final Future<ResolvedAudio> job = _resolve(
      videoId,
      dataSaver: dataSaver,
    );
    _inFlight[videoId] = job;
    // Bersihkan entri single-flight saat job selesai, sukses maupun gagal.
    // Pakai then<void> dengan onError: whenComplete mengembalikan Future
    // baru yang ikut membawa error job, dan tanpa penangan error, error
    // itu menjadi unhandled async error. Error job tetap disampaikan ke
    // pemanggil lewat `job` yang dikembalikan.
    // PENTING: callback WAJIB badan blok (bukan arrow) - `Map.remove`
    // mengembalikan nilai yang dihapus (yakni `job` itu sendiri); bila
    // nilai itu dikembalikan dari onError, Future turunan MENGADOPSI job
    // dan ikut error tanpa pendengar -> unhandled async error (terbukti
    // di tes: arrow function membuat tes ini gagal walau catch berjalan).
    unawaited(
      job.then<void>(
        (_) {
          _inFlight.remove(videoId);
        },
        onError: (_) {
          _inFlight.remove(videoId);
        },
      ),
    );
    return job;
  }

  Future<ResolvedAudio> _resolve(String videoId, {required bool dataSaver}) async {
    final DateTime start = DateTime.now();
    final RemotePlayerConfig config = await _configLoader.current();
    final List<ClientDefinition> clients = config.clients;
    if (clients.isEmpty) {
      throw const ExtractorException(
        ResolveFailureCause.parseFailed,
        detail: 'config remote tidak membawa client',
      );
    }

    // visitorData segar menaikkan peluang lolos cek bot (bukti probe:
    // tanpa visitorData semua client LOGIN_REQUIRED saat reputasi IP
    // rendah; dengan visitorData segar WEB_REMIX lolos).
    await _innertube.ensureVisitorData(clients.first);

    // signatureTimestamp WAJIB di request player pertama (tanpa sts,
    // YouTube membalas UNPLAYABLE). Ambil dari cache memori bila sudah
    // ada; bila belum, muat script sekarang (sekali, lalu ter-cache).
    // Hash player tak dikenal = fail-fast (solver tidak akan bisa jalan);
    // kegagalan jaringan = lanjut tanpa sts (best effort).
    int? signatureTimestamp = _scriptLoader.cached?.signatureTimestamp;
    if (signatureTimestamp == null) {
      try {
        final PlayerScript script = await _scriptLoader.load();
        signatureTimestamp = script.signatureTimestamp;
      } on ExtractorException catch (e) {
        if (e.cause == ResolveFailureCause.unknownPlayerHash) rethrow;
      }
    }

    ExtractorException? lastError;
    ExtractorException? lastNonNetworkError;
    for (final ClientDefinition client in clients) {
      final DateTime clientStart = DateTime.now();
      try {
        final ResolvedAudio result = await _tryClient(
          videoId,
          client,
          dataSaver: dataSaver,
          signatureTimestamp: signatureTimestamp,
        );
        _appendLog(
          videoId: videoId,
          clientName: client.name,
          outcome: 'OK itag ${result.itag}',
          durationMs: DateTime.now().difference(clientStart).inMilliseconds,
        );
        return ResolvedAudio(
          videoId: result.videoId,
          url: result.url,
          itag: result.itag,
          mimeType: result.mimeType,
          bitrate: result.bitrate,
          clientName: result.clientName,
          resolveDuration: DateTime.now().difference(start),
          title: result.title,
          lengthSeconds: result.lengthSeconds,
        );
      } on ExtractorException catch (e) {
        lastError = e;
        if (!e.isNetworkError) lastNonNetworkError = e;
        _appendLog(
          videoId: videoId,
          clientName: client.name,
          outcome: 'GAGAL ${e.cause}',
          durationMs: DateTime.now().difference(clientStart).inMilliseconds,
        );
        // Hash player tak dikenal adalah masalah script, bukan client:
        // client lain tidak akan membantu.
        if (e.cause == ResolveFailureCause.unknownPlayerHash) break;
      }
    }
    throw lastNonNetworkError ??
        lastError ??
        const ExtractorException(
          ResolveFailureCause.emptyResponse,
          detail: 'semua client gagal tanpa penyebab tercatat',
        );
  }

  Future<ResolvedAudio> _tryClient(
    String videoId,
    ClientDefinition client, {
    required bool dataSaver,
    required int? signatureTimestamp,
  }) async {
    ParsedPlayerResponse parsed = await _innertube.fetchPlayer(
      videoId,
      client,
      signatureTimestamp: signatureTimestamp,
    );
    // LOGIN_REQUIRED: coba sekali lagi dengan sts + visitorData segar.
    if (parsed.playability == Playability.loginRequired) {
      final String? freshVd = await _innertube.refreshVisitorData(client);
      int? sts = signatureTimestamp;
      try {
        final PlayerScript script = await _scriptLoader.load();
        sts = script.signatureTimestamp;
      } on ExtractorException {
        // Script gagal dimuat: ulangi dengan sts lama (atau tanpa sts).
      }
      parsed = await _innertube.fetchPlayer(
        videoId,
        client,
        signatureTimestamp: sts,
        visitorData: freshVd,
      );
    }
    if (parsed.playability != Playability.ok) {
      throw ExtractorException(
        parsed.playability == Playability.loginRequired
            ? ResolveFailureCause.httpForbidden
            : ResolveFailureCause.emptyResponse,
        clientName: client.name,
        detail:
            'playability ${parsed.playability}'
            '${parsed.reason != null ? ': ${parsed.reason}' : ''}',
      );
    }
    if (parsed.isSabrOnly) {
      throw ExtractorException(
        ResolveFailureCause.sabrOnly,
        clientName: client.name,
        detail: 'semua format audio adalah SABR',
      );
    }
    final AudioFormat? format = pickAudioFormat(
      parsed.audioFormats,
      dataSaver: dataSaver,
    );
    if (format == null) {
      throw ExtractorException(
        ResolveFailureCause.parseFailed,
        clientName: client.name,
        detail: 'tidak ada format audio yang bisa dipakai',
      );
    }
    if (format.hasDirectUrl) {
      return ResolvedAudio(
        videoId: videoId,
        url: format.url!,
        itag: format.itag,
        mimeType: format.mimeType,
        bitrate: format.bitrate,
        clientName: client.name,
        resolveDuration: Duration.zero,
        title: parsed.title,
        lengthSeconds: parsed.lengthSeconds,
      );
    }
    // Format cipher: muat script player lalu solver QuickJS.
    final PlayerScript script = await _scriptLoader.load();
    final String finalUrl = await _solver.solve(
      script: script,
      format: format,
    );
    return ResolvedAudio(
      videoId: videoId,
      url: finalUrl,
      itag: format.itag,
      mimeType: format.mimeType,
      bitrate: format.bitrate,
      clientName: client.name,
      resolveDuration: Duration.zero,
      title: parsed.title,
      lengthSeconds: parsed.lengthSeconds,
    );
  }

  void _appendLog({
    required String videoId,
    required String clientName,
    required String outcome,
    required int durationMs,
  }) {
    _log.add(
      ResolveLogEntry(
        timestamp: DateTime.now(),
        videoId: videoId,
        clientName: clientName,
        outcome: outcome,
        durationMs: durationMs,
      ),
    );
    if (_log.length > 50) _log.removeRange(0, _log.length - 50);
  }
}
