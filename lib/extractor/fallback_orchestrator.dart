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
/// Mode terdegradasi juga bisa masuk di TENGAH loop (P0-2): bila load
/// script gagal saat jalur cipher sesudah load awal berhasil (mis. hash
/// player baru muncul saat load ulang), orkestrator TIDAK berhenti -
/// client butuh-script yang tersisa dilewati dan client bebas-script
/// tetap dicoba. Versi lama `break` dari loop di titik ini dan VR tidak
/// pernah dicoba walau VR tidak butuh script sama sekali.
///
/// Jaring pengaman VR tinggal di [RemoteConfigLoader] (P0-2): loader
/// menjamin daftar client yang dipakai selalu membawa minimal satu
/// client bebas-script (ANDROID_VR bawaan ditambahkan bila config —
/// remote atau cache lama — tidak membawanya). Orkestrator sendiri tetap
/// menangani daftar tanpa client bebas-script dengan benar (mode
/// terdegradasi + error script) bila itu pernah terjadi.
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
import 'url_allowlist.dart';

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

  /// Foto kegagalan resolve terakhir (P0-2): dibaca layar "Laporkan
  /// kerusakan" (P6) untuk kode diagnostik. Dibersihkan saat sebuah
  /// resolve sukses. Lihat [ResolveFailureSnapshot] untuk kontraknya.
  ResolveFailureSnapshot? _lastFailure;

  /// Foto kegagalan resolve terakhir, null bila belum pernah gagal atau
  /// resolve terakhir sukses.
  ResolveFailureSnapshot? get lastFailure => _lastFailure;

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
    // Upaya resolve INI saja (bukan seluruh _log yang dipakai bersama
    // resolve lain): jadi isi snapshot kegagalan terakhir (P0-2).
    final List<ResolveLogEntry> attempts = <ResolveLogEntry>[];
    final RemotePlayerConfig config = await _configLoader.current();
    final List<ClientDefinition> clients = config.clients;
    if (clients.isEmpty) {
      const ExtractorException failure = ExtractorException(
        ResolveFailureCause.parseFailed,
        detail: 'config remote tidak membawa client',
      );
      _lastFailure = ResolveFailureSnapshot(
        videoId: videoId,
        timestamp: DateTime.now(),
        cause: failure.cause,
        isNetworkError: false,
        isTimeout: false,
        attempts: List<ResolveLogEntry>.unmodifiable(attempts),
        hadVisitorData: _innertube.hasVisitorData,
      );
      throw failure;
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
    // R1-M2: allowlist hash player dari config remote (atau bawaan bila
    // config tidak membawa hash) — diteruskan ke semua pemuatan script.
    final Set<String> allowedHashes = config.playerHashes.keys.toSet();
    if (signatureTimestamp == null) {
      try {
        final PlayerScript script = await _scriptLoader.load(
          allowedHashes: allowedHashes,
        );
        signatureTimestamp = script.signatureTimestamp;
      } on ExtractorException catch (e) {
        scriptError = e;
        attempts.add(
          _appendLog(
            videoId: videoId,
            clientName: 'SCRIPT',
            outcome: 'GAGAL ${e.cause}',
            durationMs: DateTime.now().difference(start).inMilliseconds,
            cause: e.cause,
            isNetworkError: e.isNetworkError,
            isTimeout: e.isTimeout,
          ),
        );
      }
    }

    // Urutan client diputar sesuai rotasi (P0): resolve sebelumnya yang
    // gagal total menggeser client awal ke berikutnya.
    final List<ClientDefinition> ordered = _rotatedOrder(clients, videoId);
    ExtractorException? lastError;
    ExtractorException? lastNonNetworkError;
    bool anyClientTried = false;
    // P0-2: mode terdegradasi bisa masuk di tengah loop (lihat catatan
    // kelas) — flag ini, bukan scriptError saja, yang menggerakkan
    // lewati client butuh-script.
    bool degraded = scriptError != null;
    for (final ClientDefinition client in ordered) {
      if (degraded && client.requiresScript) {
        // Mode terdegradasi: tanpa sts + tanpa solver, client ini tidak
        // mungkin berhasil (UNPLAYABLE dijamin + cipher tak terpecahkan).
        // Lewati tanpa membuang satu request player pun.
        attempts.add(
          _appendLog(
            videoId: videoId,
            clientName: client.name,
            outcome: 'LEWATI (butuh script)',
            durationMs: 0,
            skipped: true,
          ),
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
          allowedHashes: allowedHashes,
        );
        attempts.add(
          _appendLog(
            videoId: videoId,
            clientName: client.name,
            outcome: 'OK itag ${result.itag}',
            durationMs: DateTime.now().difference(clientStart).inMilliseconds,
          ),
        );
        // Sukses: rotasi dihapus, resolve berikutnya mulai dari urutan
        // default lagi. Snapshot kegagalan terakhir dibersihkan: tidak
        // ada lagi kegagalan yang belum disusul sukses (P0-2).
        _rotationStart.remove(videoId);
        _lastFailure = null;
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
        attempts.add(
          _appendLog(
            videoId: videoId,
            clientName: client.name,
            outcome: 'GAGAL ${e.cause}',
            durationMs: DateTime.now().difference(clientStart).inMilliseconds,
            cause: e.cause,
            isNetworkError: e.isNetworkError,
            isTimeout: e.isTimeout,
          ),
        );
        // Hash player tak dikenal adalah masalah script, bukan client:
        // client butuh-script lain tidak akan membantu — tapi client
        // bebas-script (VR) tidak butuh script sama sekali, jadi loop
        // TIDAK berhenti: masuk mode terdegradasi dan lanjut (P0-2).
        // Versi lama `break` di sini dan VR tidak pernah dicoba.
        if (e.cause == ResolveFailureCause.unknownPlayerHash) {
          degraded = true;
          scriptError ??= e;
        }
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
    final ExtractorException failure =
        (!anyClientTried && scriptError != null)
        ? scriptError
        : lastNonNetworkError ??
              lastError ??
              scriptError ??
              const ExtractorException(
                ResolveFailureCause.emptyResponse,
                detail: 'semua client gagal tanpa penyebab tercatat',
              );
    // Foto kegagalan terakhir untuk kode diagnostik (P0-2): disimpan
    // SEBELUM throw supaya "Laporkan kerusakan" (P6) bisa membacanya.
    _lastFailure = ResolveFailureSnapshot(
      videoId: videoId,
      timestamp: DateTime.now(),
      cause: failure.cause,
      isNetworkError: failure.isNetworkError,
      isTimeout: failure.isTimeout,
      attempts: List<ResolveLogEntry>.unmodifiable(attempts),
      hadVisitorData: _innertube.hasVisitorData,
    );
    throw failure;
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
    required Set<String> allowedHashes,
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
        final PlayerScript script = await _scriptLoader.load(
          allowedHashes: allowedHashes,
        );
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
        // Hanya Playability.error yang membuktikan lagu tidak bisa
        // diputar (dihapus/privat/dibatasi wilayah, P6 B4.7).
        isPlayabilityFailure: parsed.playability == Playability.error,
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
      // R1-M1: URL langsung dari respons player adalah data jaringan —
      // tolak sebelum masuk ResolvedAudio bila host-nya bukan
      // googlevideo.com (client berikutnya dicoba lewat exception ini).
      final String directUrl = format.url!;
      if (!isAllowedStreamUrl(directUrl)) {
        throw ExtractorException(
          ResolveFailureCause.parseFailed,
          clientName: client.name,
          detail: 'URL langsung di luar host yang diizinkan',
        );
      }
      return ResolvedAudio(
        videoId: videoId,
        url: directUrl,
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
    final PlayerScript script = await _scriptLoader.load(
      allowedHashes: allowedHashes,
    );
    final String finalUrl = await _solver.solve(
      script: script,
      format: format,
    );
    // R1-M1 (titik cek kedua, defense in depth): solver sudah memvalidasi
    // hasilnya sendiri, tapi orkestrator adalah satu-satunya pintu
    // pembuatan ResolvedAudio — validasi ulang di sini supaya solver
    // pengganti di masa depan tidak bisa meloloskan host liar.
    if (!isAllowedStreamUrl(finalUrl)) {
      throw ExtractorException(
        ResolveFailureCause.parseFailed,
        clientName: client.name,
        detail: 'URL hasil solver di luar host yang diizinkan',
      );
    }
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

  /// Tambah satu entri ke log resolve dan kembalikan entri itu (pemanggil
  /// mengumpulkannya sebagai `attempts` resolve ini untuk snapshot
  /// kegagalan terakhir). Tanpa URL.
  ResolveLogEntry _appendLog({
    required String videoId,
    required String clientName,
    required String outcome,
    required int durationMs,
    ResolveFailureCause? cause,
    bool isNetworkError = false,
    bool isTimeout = false,
    bool skipped = false,
  }) {
    final ResolveLogEntry entry = ResolveLogEntry(
      timestamp: DateTime.now(),
      videoId: videoId,
      clientName: clientName,
      outcome: outcome,
      durationMs: durationMs,
      cause: cause,
      isNetworkError: isNetworkError,
      isTimeout: isTimeout,
      skipped: skipped,
    );
    _log.add(entry);
    if (_log.length > 50) _log.removeRange(0, _log.length - 50);
    return entry;
  }
}
