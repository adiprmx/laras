/// Resolve URL unduhan per kualitas.
///
/// `AudioResolver` milik lapisan ekstraksi hanya punya dua mode
/// (kualitas terbaik / hemat data) dan tidak bisa meminta itag 140
/// ("Seimbang") secara spesifik. Karena `lib/extractor` milik tim Blue 1
/// dan tidak boleh diubah di P5, resolver unduhan ini dibangun di atas
/// API PUBLIK ekstraksi (`InnertubeClient.fetchPlayer`,
/// `SignatureSolver.solve`, `PlayerScriptLoader`, `RemoteConfigLoader`)
/// dengan pemilih itag sendiri per kualitas.
///
/// Loop fallback antar client di sini adalah CERMIN dari
/// `StreamResolver._resolve`/`_tryClient` (urutan config, sts di request
/// pertama, ulangi sekali saat LOGIN_REQUIRED, lewati client yang butuh
/// script saat script gagal dimuat). Bila Blue 1 nanti membuka resolve
/// dengan urutan itag kustom, kelas ini harus diganti dengan pemakaian
/// resolver itu (catatan konvergensi untuk P6+).
///
/// Aturan yang sama dengan lapisan ekstraksi berlaku di sini: URL stream
/// hanya hidup di memori, tidak pernah ditulis ke database, file, atau
/// log; format SABR tidak pernah dipilih.
library;

// ignore_for_file: prefer_initializing_formals - konstruktor publik memakai
// parameter bernama publik + field privat; initializing formal akan
// membuat nama parameter menjadi privat dan tidak bisa dipakai pemanggil.


import 'package:laras/extractor/extractor.dart';

import 'download_quality.dart';

/// URL unduhan hasil resolve (memori saja, kedaluwarsa).
class DownloadUrl {
  const DownloadUrl({
    required this.url,
    required this.itag,
    required this.mimeType,
    required this.bitrate,
    required this.clientName,
    this.contentLength,
  });

  /// URL stream audio. Jangan dicetak ke log.
  final String url;
  final int itag;
  final String mimeType;
  final int bitrate;
  final String clientName;

  /// Ukuran file dalam byte, bila server menyebutkannya.
  final int? contentLength;

  @override
  String toString() =>
      'DownloadUrl(itag: $itag, client: $clientName, '
      'bytes: $contentLength)';
}

/// Sumber URL unduhan: satu lagu + kualitas menjadi URL siap unduh.
abstract class DownloadUrlSource {
  /// Resolve [videoId] dengan [quality].
  ///
  /// Melempar [ExtractorException] bila semua client gagal.
  Future<DownloadUrl> resolve(String videoId, DownloadQuality quality);
}

/// Pilih satu format audio untuk [quality] dari daftar format.
///
/// Aturan "bisa dipakai" sama dengan `pickAudioFormat` (bukan SABR dan
/// punya URL langsung atau cipher lengkap). Bila tidak ada itag di
/// urutan kualitas yang tersedia, pakai bitrate tertinggi sebagai jalan
/// terakhir supaya format audio baru dari YouTube tetap bisa diunduh.
/// Fungsi murni (tanpa I/O) supaya mudah dites.
AudioFormat? pickFormatForQuality(
  List<AudioFormat> formats,
  DownloadQuality quality,
) {
  final List<AudioFormat> usable = formats
      .where((AudioFormat f) => !f.isSabr && (f.hasDirectUrl || f.needsSolver))
      .toList(growable: false);
  if (usable.isEmpty) return null;
  for (final int itag in quality.itagOrder) {
    for (final AudioFormat format in usable) {
      if (format.itag == itag) return format;
    }
  }
  usable.sort((AudioFormat a, AudioFormat b) => b.bitrate.compareTo(a.bitrate));
  return usable.first;
}

/// Implementasi [DownloadUrlSource] di atas API publik ekstraksi.
class ExtractorDownloadUrlSource implements DownloadUrlSource {
  ExtractorDownloadUrlSource({
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

  @override
  Future<DownloadUrl> resolve(String videoId, DownloadQuality quality) async {
    final RemotePlayerConfig config = await _configLoader.current();
    final List<ClientDefinition> clients = config.clients;
    if (clients.isEmpty) {
      throw const ExtractorException(
        ResolveFailureCause.parseFailed,
        detail: 'config remote tidak membawa client',
      );
    }
    await _innertube.ensureVisitorData(clients.first);

    // R2-L5: allowlist hash player dari config remote (atau bawaan bila
    // config tidak membawa hash — loader yang memutuskan), diteruskan ke
    // semua pemuatan script, sama seperti orkestrator pemutar. Tanpa ini,
    // hash player baru yang masuk lewat config berlaku untuk pemutaran
    // tapi tidak untuk unduhan.
    final Set<String> allowedHashes = config.playerHashes.keys.toSet();

    // signatureTimestamp WAJIB di request player pertama client web
    // (tanpa sts, server membalas UNPLAYABLE — bukti P1). Gagal memuat
    // script tidak langsung menggagalkan resolve: masuk mode terdegradasi
    // (client yang butuh script dilewati, client bebas-script dicoba).
    int? signatureTimestamp = _scriptLoader.cached?.signatureTimestamp;
    ExtractorException? scriptError;
    if (signatureTimestamp == null) {
      try {
        final PlayerScript script = await _scriptLoader.load(
          allowedHashes: allowedHashes,
        );
        signatureTimestamp = script.signatureTimestamp;
      } on ExtractorException catch (e) {
        scriptError = e;
      }
    }

    ExtractorException? lastError;
    ExtractorException? lastNonNetworkError;
    bool anyClientTried = false;
    // R2-L5 (pola P0-2 orkestrator): mode terdegradasi bisa masuk di
    // tengah loop — flag ini, bukan scriptError saja, yang menggerakkan
    // lewati client butuh-script. Versi lama `break` saat hash tak
    // dikenal dan client bebas-script (VR) tidak pernah dicoba.
    bool degraded = scriptError != null;
    for (final ClientDefinition client in clients) {
      if (degraded && client.requiresScript) continue;
      anyClientTried = true;
      try {
        return await _tryClient(
          videoId,
          client,
          quality: quality,
          signatureTimestamp: signatureTimestamp,
          allowedHashes: allowedHashes,
        );
      } on ExtractorException catch (e) {
        lastError = e;
        if (!e.isNetworkError) lastNonNetworkError = e;
        // Hash player tak dikenal adalah masalah script, bukan client:
        // client butuh-script lain tidak akan membantu — tapi client
        // bebas-script (VR) tidak butuh script sama sekali, jadi loop
        // TIDAK berhenti: masuk mode terdegradasi dan lanjut (P0-2).
        if (e.cause == ResolveFailureCause.unknownPlayerHash) {
          degraded = true;
          scriptError ??= e;
        }
      }
    }
    if (!anyClientTried && scriptError != null) throw scriptError;
    throw lastNonNetworkError ??
        lastError ??
        scriptError ??
        const ExtractorException(
          ResolveFailureCause.emptyResponse,
          detail: 'semua client gagal tanpa penyebab tercatat',
        );
  }

  Future<DownloadUrl> _tryClient(
    String videoId,
    ClientDefinition client, {
    required DownloadQuality quality,
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
    final AudioFormat? format = pickFormatForQuality(
      parsed.audioFormats,
      quality,
    );
    if (format == null) {
      throw ExtractorException(
        ResolveFailureCause.parseFailed,
        clientName: client.name,
        detail: 'tidak ada format audio yang bisa dipakai',
      );
    }
    if (format.hasDirectUrl) {
      // R2-M1: URL langsung dari respons player WAJIB lolos allowlist
      // host sebelum dikembalikan — tanpa ini, respons yang dimanipulasi
      // bisa mengarahkan pengunduh ke host arbitrer (R1-M1 terulang di
      // kode cermin). Jalur ini adalah jalur client bebas-script (VR),
      // yang justru paling sering dipakai saat mode terdegradasi.
      if (!isAllowedStreamUrl(format.url!)) {
        throw ExtractorException(
          ResolveFailureCause.parseFailed,
          clientName: client.name,
          detail: 'URL langsung di luar host yang diizinkan',
        );
      }
      return DownloadUrl(
        url: format.url!,
        itag: format.itag,
        mimeType: format.mimeType,
        bitrate: format.bitrate,
        clientName: client.name,
        contentLength: format.contentLength,
      );
    }
    final PlayerScript script = await _scriptLoader.load(
      allowedHashes: allowedHashes,
    );
    final String finalUrl = await _solver.solve(script: script, format: format);
    // Defense in depth (cermin orkestrator): solver sendiri sudah
    // memvalidasi hasilnya, tapi periksa ulang di sini supaya satu
    // regresi di solver tidak membuka lagi jalur unduhan.
    if (!isAllowedStreamUrl(finalUrl)) {
      throw ExtractorException(
        ResolveFailureCause.parseFailed,
        clientName: client.name,
        detail: 'URL hasil solver di luar host yang diizinkan',
      );
    }
    return DownloadUrl(
      url: finalUrl,
      itag: format.itag,
      mimeType: format.mimeType,
      bitrate: format.bitrate,
      clientName: client.name,
      contentLength: format.contentLength,
    );
  }
}
