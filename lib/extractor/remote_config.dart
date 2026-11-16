/// Loader config remote player (GitHub Releases, tag `config-v1`).
///
/// Config berisi daftar client + versi, pemetaan hash player, dan daftar
/// video kanari. Nilainya dipakai tanpa install ulang: app memeriksa
/// config baru tiap TTL 6 jam (dan saat start dingin), lalu memakai
/// nilai baru untuk resolve berikutnya.
///
/// Aturan (arsitektur 3.4):
/// - Timeout fetch 5 detik, respons maksimum 4 MB.
/// - Single-flight: bila satu fetch sedang berjalan, pemanggil lain
///   menunggu Future yang sama.
/// - Rate limit: fetch tidak diulang dalam 5 menit kecuali dipaksa
///   (tombol "Periksa pembaruan").
/// - Fallback: bila fetch gagal, pakai cache terakhir yang valid; bila
///   belum pernah ada cache, pakai nilai bawaan dari
///   [client_definitions.dart].
///
/// URL asset: `https://github.com/adiprmx/laras/releases/download/config-v1/player-config.json`
/// (rilis pre-release tag `config-v1`, BUKAN tag `v*` supaya tidak memicu
/// workflow rilis). Repo publik, tanpa auth.
library;

// ignore_for_file: prefer_initializing_formals - konstruktor publik memakai
// parameter bernama publik + field privat; initializing formal akan
// membuat nama parameter menjadi privat dan tidak bisa dipakai pemanggil.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'client_definitions.dart';
import 'errors.dart';
import 'response_limits.dart';

/// URL asset config di GitHub Releases.
const String kRemoteConfigUrl =
    'https://github.com/adiprmx/laras/releases/download/'
    'config-v1/player-config.json';

/// URL cadangan: file yang sama di tree tag `config-v1`
/// (commit khusus config, bukan di main).
///
/// Alasan cadangan ini ada: upload aset rilis lewat API butuh
/// `uploads.github.com` dengan auth, dan kredensial GitHub di lingkungan
/// ini hanya berlaku untuk `api.github.com` (surrogate ditolak 401 di
/// uploads.github.com, terbukti 16 Nov 2026). Sampai aset diunggah lewat
/// browser, file config dilayani dari tree tag - URL ini yang membuat
/// config remote benar-benar bisa dipakai tanpa install ulang.
/// Bila aset rilis sudah ada, URL utama dipakai dan cadangan tidak
/// pernah disentuh.
const String kRemoteConfigFallbackUrl =
    'https://raw.githubusercontent.com/adiprmx/laras/'
    'config-v1/player-config.json';

/// Kunci cache SharedPreferences.
const String kRemoteConfigCacheKey = 'laras.remote_player_config';
const String kRemoteConfigFetchedAtKey = 'laras.remote_player_config_fetched_at';

/// Pemetaan hash player bawaan (nilai hasil probe 15 Nov 2026).
///
/// Satu-satunya sumber kebenaran untuk nilai bawaan: dipakai
/// [RemotePlayerConfig.defaults] DAN sebagai allowlist cadangan
/// [PlayerScriptLoader] bila config remote tidak membawa hash
/// (R1-M2). Hash `fad7e4e9` dipakai dua varian player (non-tcl sts 20767
/// yang bisa diekstrak + tcl sts 20767001 yang tidak bisa); gerbang hash
/// hanya memeriksa hash-nya — varian yang dieksekusi selalu non-tcl
/// karena varian tcl gagal di ekstraksi sebelum mencapai solver
/// (fallback P0 di loader).
const Map<String, int> kBuiltinPlayerHashes = <String, int>{'fad7e4e9': 20767};

/// Config player yang sudah di-parse (dari remote atau bawaan).
class RemotePlayerConfig {
  const RemotePlayerConfig({
    required this.clients,
    required this.playerHashes,
    required this.canaryVideoIds,
    required this.fetchedAt,
    required this.isRemote,
  });

  /// Urutan fallback client (pertama = utama).
  final List<ClientDefinition> clients;

  /// hash player -> signatureTimestamp yang diketahui baik.
  final Map<String, int> playerHashes;

  /// videoId kanari.
  final List<String> canaryVideoIds;

  /// Waktu config ini diambil (remote) atau waktu app dibangun (bawaan).
  final DateTime fetchedAt;

  /// Benar bila config berasal dari remote (bukan nilai bawaan).
  final bool isRemote;

  /// Batas ukuran config remote (R1-L1): config adalah data dari jaringan,
  /// jadi ukurannya dibatasi supaya config yang dipalsukan tidak bisa
  /// memaksa app mencoba ribuan client (tiap percobaan 10 detik) atau
  /// menyimpan peta raksasa. Pelanggaran batas membuat seluruh config
  /// ditolak (tryParse mengembalikan null, pemanggil memakai cache atau
  /// bawaan) — kecuali daftar kanari yang dipotong ke batasnya.
  static const int maxClients = 10;

  /// Panjang maksimum tiap string client (nama, versi, userAgent,
  /// clientId). Nilai yang sah jauh di bawah ini (userAgent terpanjang
  /// ~130 karakter).
  static const int maxClientStringLength = 200;

  /// Jumlah maksimum entri playerHashes.
  static const int maxPlayerHashes = 100;

  /// Jumlah maksimum ID kanari yang disimpan (sisanya diabaikan).
  static const int maxCanaryIds = 50;

  /// Config bawaan (nilai hasil probe 15 Nov 2026).
  factory RemotePlayerConfig.defaults() => RemotePlayerConfig(
    clients: kDefaultClientFallbackOrder,
    playerHashes: kBuiltinPlayerHashes,
    canaryVideoIds: kCanarySongs.map((s) => s.videoId).toList(growable: false),
    fetchedAt: DateTime.now(),
    isRemote: false,
  );

  /// Parse dari JSON config remote. Mengembalikan null bila struktur
  /// tidak valid (pemanggil memakai cache/bawaan).
  static RemotePlayerConfig? tryParse(
    Map<String, dynamic> json, {
    required DateTime fetchedAt,
  }) {
    try {
      final List<dynamic>? clientsJson = json['clients'] as List<dynamic>?;
      if (clientsJson == null ||
          clientsJson.isEmpty ||
          clientsJson.length > maxClients) {
        return null;
      }
      final List<ClientDefinition> clients = <ClientDefinition>[];
      for (final dynamic raw in clientsJson) {
        if (raw is! Map<String, dynamic>) return null;
        final String? name = raw['name'] as String?;
        final String? version = raw['version'] as String?;
        final String? userAgent = raw['userAgent'] as String?;
        final String? clientId = raw['clientId'] as String?;
        if (name == null || version == null || userAgent == null || clientId == null) {
          return null;
        }
        if (name.length > maxClientStringLength ||
            version.length > maxClientStringLength ||
            userAgent.length > maxClientStringLength ||
            clientId.length > maxClientStringLength) {
          return null;
        }
        // Opsional: false untuk client URL-langsung tanpa sts
        // (ANDROID_VR). Default true bila kunci tidak ada.
        final bool requiresScript = raw['requiresScript'] as bool? ?? true;
        clients.add(
          ClientDefinition(
            name: name,
            version: version,
            context: <String, dynamic>{
              'clientName': name,
              'clientVersion': version,
            },
            userAgent: userAgent,
            clientId: clientId,
            requiresScript: requiresScript,
          ),
        );
      }
      final Map<String, int> hashes = <String, int>{};
      final Map<String, dynamic>? hashesJson =
          json['playerHashes'] as Map<String, dynamic>?;
      if (hashesJson != null) {
        if (hashesJson.length > maxPlayerHashes) return null;
        for (final MapEntry<String, dynamic> e in hashesJson.entries) {
          final Object? value = e.value;
          if (value is Map<String, dynamic>) {
            final Object? sts = value['signatureTimestamp'];
            if (sts is int) hashes[e.key] = sts;
          } else if (value is int) {
            hashes[e.key] = value;
          }
        }
      }
      final List<String> canaryIds = <String>[];
      final List<dynamic>? canaryJson = json['canaryVideoIds'] as List<dynamic>?;
      if (canaryJson != null) {
        for (final dynamic v in canaryJson) {
          if (canaryIds.length >= maxCanaryIds) break;
          if (v is String && v.length == 11) canaryIds.add(v);
        }
      }
      if (canaryIds.isEmpty) {
        canaryIds.addAll(
          kCanarySongs.map((s) => s.videoId),
        );
      }
      return RemotePlayerConfig(
        clients: clients,
        playerHashes: hashes,
        canaryVideoIds: canaryIds,
        fetchedAt: fetchedAt,
        isRemote: true,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Loader config remote dengan cache + TTL + single-flight + rate limit.
class RemoteConfigLoader {
  RemoteConfigLoader({Dio? dio, required SharedPreferences prefs})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 5),
              responseType: ResponseType.json,
            ),
          ),
      _prefs = prefs;

  final Dio _dio;
  final SharedPreferences _prefs;

  /// TTL config: 6 jam (K7: config dipakai dalam 6 jam).
  static const Duration ttl = Duration(hours: 6);

  /// Jeda minimum antar fetch (rate limit), kecuali dipaksa.
  static const Duration minFetchInterval = Duration(minutes: 5);

  /// Batas ukuran respons: 4 MB (ResponseLimits.remoteConfigBytes),
  /// ditegakkan saat streaming di [_fetchOne] (R1-M3).

  RemotePlayerConfig? _current;
  Future<RemotePlayerConfig>? _inFlight;
  DateTime? _lastFetchAttempt;

  /// Config yang berlaku saat ini (cache memori, cache disk, atau bawaan).
  ///
  /// Bila cache sudah basi (lebih dari TTL), fetch baru dijadwalkan di
  /// latar belakang dan nilai lama tetap dikembalikan segera (stale-
  /// while-revalidate) supaya resolve tidak tertunda.
  Future<RemotePlayerConfig> current({bool forceRefresh = false}) async {
    _current ??= await _loadFromDisk() ?? RemotePlayerConfig.defaults();
    final RemotePlayerConfig current = _current!;
    final bool stale =
        DateTime.now().difference(current.fetchedAt) > ttl || forceRefresh;
    if (stale) {
      // Jangan tunggu: refresh di latar belakang, nilai lama tetap dipakai.
      unawaited(_refresh(force: forceRefresh));
    }
    return current;
  }

  /// Fetch config baru sekarang (dipakai tombol "Periksa pembaruan" dan
  /// start dingin). Mengembalikan config terbaru (remote bila berhasil,
  /// cache/bawaan bila gagal).
  Future<RemotePlayerConfig> refresh({bool force = false}) async {
    final RemotePlayerConfig result = await _refresh(force: force);
    return result;
  }

  Future<RemotePlayerConfig> _refresh({required bool force}) async {
    // Single-flight: fetch yang sedang berjalan dipakai bersama.
    final Future<RemotePlayerConfig>? inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    // Rate limit (kecuali dipaksa).
    final DateTime now = DateTime.now();
    if (!force &&
        _lastFetchAttempt != null &&
        now.difference(_lastFetchAttempt!) < minFetchInterval) {
      return _current ?? RemotePlayerConfig.defaults();
    }
    final Future<RemotePlayerConfig> job = _fetchAndStore();
    _inFlight = job;
    try {
      return await job;
    } finally {
      _inFlight = null;
    }
  }

  Future<RemotePlayerConfig> _fetchAndStore() async {
    _lastFetchAttempt = DateTime.now();
    for (final String url in <String>[
      kRemoteConfigUrl,
      kRemoteConfigFallbackUrl,
    ]) {
      try {
        final RemotePlayerConfig parsed = await _fetchOne(url);
        _current = parsed;
        return parsed;
      } on DioException {
        // URL ini gagal (mis. aset rilis belum ada -> 404): coba URL
        // berikutnya. Kegagalan terakhir ditangani di bawah.
        continue;
      } on FormatException {
        // Respons ada tapi isinya bukan config valid: jangan coba URL
        // lain dengan isi yang (kemungkinan) sama; langsung ke fallback
        // cache/bawaan.
        break;
      }
    }
    // Semua URL gagal: cache terakhir yang valid, atau bawaan.
    return _current ??
        await _loadFromDisk() ??
        RemotePlayerConfig.defaults();
  }

  Future<RemotePlayerConfig> _fetchOne(String url) async {
    final ResponseSizeCap cap =
        ResponseSizeCap(ResponseLimits.remoteConfigBytes);
    try {
      final Response<ResponseBody> response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: <String, String>{'Accept': 'application/json'},
        ),
        cancelToken: cap.cancelToken,
        onReceiveProgress: cap.onReceiveProgress,
      );
      // R1-M3: batas ukuran ditegakkan saat streaming, bukan setelah
      // seluruh respons terunduh + ter-decode seperti sebelumnya.
      checkContentLength(response, ResponseLimits.remoteConfigBytes);
      final Uint8List bytes = await readCappedResponseBody(
        response.data!,
        requestOptions: response.requestOptions,
        maxBytes: ResponseLimits.remoteConfigBytes,
        chunkTimeout: const Duration(seconds: 5),
      );
      return await _parseAndCache(bytes);
    } on ExtractorException {
      // Batas ukuran (cap streaming / Content-Length): config tidak
      // valid -> fallback cache/bawaan. Dipetakan ke FormatException
      // karena _fetchAndStore hanya menangkap DioException/FormatException;
      // ExtractorException di sini akan menjadi unhandled async error
      // lewat unawaited(_refresh(...)).
      throw const FormatException('config melebihi batas ukuran');
    } on DioException {
      // Pembatalan oleh cap == respons raksasa -> FormatException juga.
      if (cap.exceeded) {
        throw const FormatException('config melebihi batas ukuran');
      }
      rethrow;
    }
  }

  Future<RemotePlayerConfig> _parseAndCache(Uint8List bytes) async {
    final dynamic decoded = jsonDecode(utf8.decode(bytes));
    // R1-L1: cek `is`, bukan cast `as` — cast melempar TypeError bila
    // JSON ter-decode menjadi List, dan TypeError tidak ditangkap
    // _fetchAndStore (hanya DioException/FormatException) sehingga bisa
    // menjadi unhandled async error lewat unawaited(_refresh(...)).
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('config bukan objek JSON');
    }
    final Map<String, dynamic> json = decoded;
    // Batas ukuran (sabuk kedua): serialisasi ulang tidak boleh melebihi
    // 4 MB; nilainya juga yang disimpan ke cache disk.
    final String encoded = jsonEncode(json);
    if (encoded.length > ResponseLimits.remoteConfigBytes) {
      throw const FormatException('config melebihi 4 MB');
    }
    final DateTime fetchedAt = DateTime.now();
    final RemotePlayerConfig? parsed = RemotePlayerConfig.tryParse(
      json,
      fetchedAt: fetchedAt,
    );
    if (parsed == null) throw const FormatException('config tidak valid');
    await _prefs.setString(kRemoteConfigCacheKey, encoded);
    await _prefs.setString(
      kRemoteConfigFetchedAtKey,
      fetchedAt.toIso8601String(),
    );
    return parsed;
  }

  Future<RemotePlayerConfig?> _loadFromDisk() async {
    try {
      final String? raw = _prefs.getString(kRemoteConfigCacheKey);
      final String? fetchedAtRaw = _prefs.getString(kRemoteConfigFetchedAtKey);
      if (raw == null || fetchedAtRaw == null) return null;
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return RemotePlayerConfig.tryParse(
        decoded,
        fetchedAt: DateTime.parse(fetchedAtRaw),
      );
    } catch (_) {
      return null;
    }
  }
}
