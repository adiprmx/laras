/// Orkestrator fallback antar client: [StreamResolver].
///
/// Alur resolve satu lagu:
/// 1. Ambil config remote (urutan client + versi).
/// 2. Muat script player (cache memori; unduh bila belum ada) untuk
///    signatureTimestamp (sts). sts WAJIB di request player PERTAMA
///    untuk client web: terbukti 16 Nov 2026, request tanpa sts dibalas
///    UNPLAYABLE ("The page needs to be reloaded.") walau visitorData ada.
///    Bila script gagal dimuat, resolve TIDAK langsung gagal: masuk mode
///    terdegradasi (lihat bawah).
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
/// Mode terdegradasi (P0): bila script player gagal dimuat (ekstraksi
/// base.js gagal / jaringan putus saat unduh), client yang butuh script
/// ([ClientDefinition.requiresScript]) DILEWATI tanpa request player -
/// tanpa sts mereka DIJAMIN UNPLAYABLE, dan format cipher mereka tidak
/// bisa dipecahkan tanpa solver. Client bebas-script (saat ini hanya
/// ANDROID_VR, terbukti probe P0f lolos tanpa sts dan memberi URL
/// langsung) tetap dicoba. Bila tidak ada client bebas-script yang
/// berhasil, error script yang dilempar (bila tidak ada client yang
/// dicoba sama sekali) atau error client terakhir yang paling informatif.
/// Tanpa mode ini, satu perubahan base.js YouTube mematikan SEMUA putar
/// - persis insiden P0 16 Nov 2026.
///
/// Rotasi client antar percobaan (P0): bila satu resolve menghabiskan
/// semua client dan gagal, resolve BERIKUTNYA untuk lagu yang sama mulai
/// dari client berikutnya dalam urutan fallback, bukan mengulang urutan
/// yang sama dari awal. Retry pengguna dan re-resolve otomatis jadi
/// mencoba client lain dulu. Sukses menghapus rotasi (urutan default
/// lagi untuk resolve berikutnya).
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
import 'resolver.dart';

/// Orkestrator resolve + fallback.
class StreamResolver implements AudioResolver {
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

  /// Rotasi client per videoId: nama client yang harus dicoba PERTAMA
  /// pada resolve berikutnya untuk lagu itu (lihat catatan kelas).
  /// Dibatasi 50 entri; rotasi adalah best-effort, kehilangannya hanya
  /// berarti urutan kembali default.
  final Map<String, String> _rotationStart = <String, String>{};

  /// Log resolve terakhir (maks 50 baris, tanpa URL).
  @override
  List<ResolveLogEntry> get recentLog => List<ResolveLogEntry>.unmodifiable(_log);

  /// Resolve satu lagu menjadi URL audio siap putar.
  @override
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

    // signatureTimestamp WAJIB di request player pertama client web
    // (tanpa sts, YouTube membalas UNPLAYABLE - terbukti 4/4 kombinasi
    // di P1 dan dikonfirmasi ulang probe P0 16 Nov 2026). Ambil dari
    // cache memori bila sudah ada; bila belum, muat script sekarang
    // (sekali, lalu ter-cache).
    //
    // Gagal memuat script TIDAK langsung menggagalkan resolve (mode
    // terdegradasi, P0): errornya dicatat, dan loop client di bawah
    // melewati client yang butuh script sambil tetap mencoba client
    // bebas-script (ANDROID_VR, terbukti probe P0f lolos tanpa sts).
    // Loader sendiri sudah mengembalikan script cache bila unduhan gagal
    // dan cache ada, jadi sampai di sini berarti benar-benar tidak ada
    // script yang bisa dipakai saat ini.
    int? signatureTimestamp = _scriptLoader.cached?.signatureTimestamp;
    ExtractorException? scriptError;
    if (signatureTimestamp == null) {
      try {
        final PlayerScript script = await _scriptLoader.load();
        signatureTimestamp = script.signatureTimestamp;
      } on ExtractorException catch (e) {
        scriptError = e;
        _appendLog(
          videoId: videoId,
          clientName: 'SCRIPT',
          outcome: 'GAGAL ${e.cause}',
          durationMs: DateTime.now().difference(start).inMilliseconds,
        );
      }
    }

    // Urutan client diputar sesuai rotasi (P0): resolve sebelumnya yang
    // gagal total menggeser client awal ke berikutnya.
    final List<ClientDefinition> ordered = _rotatedOrder(clients, videoId);
    ExtractorException? lastError;
    ExtractorException? lastNonNetworkError;
    bool anyClientTried = false;
    for (final ClientDefinition client in ordered) {
      if (scriptError != null && client.requiresScript) {
        // Mode terdegradasi: tanpa sts + tanpa solver, client ini tidak
        // mungkin berhasil (UNPLAYABLE dijamin + cipher tak terpecahkan).
        // Lewati tanpa membuang satu request player pun.
        _appendLog(
          videoId: videoId,
          clientName: client.name,
          outcome: 'LEWATI (butuh script)',
          durationMs: 0,
        );
        continue;
      }
      anyClientTried = true;
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
        // Sukses: rotasi dihapus, resolve berikutnya mulai dari urutan
        // default lagi.
        _rotationStart.remove(videoId);
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
    // Semua client habis: geser rotasi supaya resolve berikutnya untuk
    // lagu ini mulai dari client berikutnya, bukan mengulang urutan sama.
    _advanceRotation(videoId, clients, ordered);
    // Bila tidak ada satu pun client yang dicoba (semua dilewati karena
    // butuh script), penyebab sebenarnya adalah error script itu sendiri
    // - melemparnya menjaga klasifikasi + deteksi kanari tetap menunjuk
    // akar yang benar. Bila ada client yang dicoba, pakai aturan biasa
    // (error non-jaringan terakhir lebih informatif).
    if (!anyClientTried && scriptError != null) throw scriptError;
    throw lastNonNetworkError ??
        lastError ??
        scriptError ??
        const ExtractorException(
          ResolveFailureCause.emptyResponse,
          detail: 'semua client gagal tanpa penyebab tercatat',
        );
  }

  /// Urutan client untuk resolve ini: urutan config diputar supaya client
  /// yang tersimpan di rotasi menjadi yang pertama. Tanpa rotasi tersimpan
  /// (atau nama tersimpan tidak ada lagi di config), urutan config dipakai
  /// apa adanya.
  List<ClientDefinition> _rotatedOrder(
    List<ClientDefinition> clients,
    String videoId,
  ) {
    final String? startName = _rotationStart[videoId];
    if (startName == null) return clients;
    final int startIndex = clients.indexWhere(
      (ClientDefinition c) => c.name == startName,
    );
    if (startIndex <= 0) return clients;
    return <ClientDefinition>[
      ...clients.sublist(startIndex),
      ...clients.sublist(0, startIndex),
    ];
  }

  /// Geser rotasi satu langkah: resolve berikutnya untuk [videoId] mulai
  /// dari client sesudah client pertama yang dicoba di resolve ini
  /// (melingkar dalam urutan config). Dengan 2 client, ini berarti urutan
  /// bertukar setiap kegagalan total: [W, M] -> [M, W] -> [W, M].
  void _advanceRotation(
    String videoId,
    List<ClientDefinition> clients,
    List<ClientDefinition> ordered,
  ) {
    if (clients.length < 2 || ordered.isEmpty) return;
    final String firstTried = ordered.first.name;
    final int firstIndex = clients.indexWhere(
      (ClientDefinition c) => c.name == firstTried,
    );
    if (firstIndex < 0) return;
    final String nextName = clients[(firstIndex + 1) % clients.length].name;
    if (_rotationStart.length >= 50) _rotationStart.clear();
    _rotationStart[videoId] = nextName;
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
