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

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'client_definitions.dart';

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

  /// Config bawaan (nilai hasil probe 15 Nov 2026).
  factory RemotePlayerConfig.defaults() => RemotePlayerConfig(
    clients: kDefaultClientFallbackOrder,
    playerHashes: const <String, int>{'fad7e4e9': 20767},
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
      if (clientsJson == null || clientsJson.isEmpty) return null;
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
          ),
        );
      }
      final Map<String, int> hashes = <String, int>{};
      final Map<String, dynamic>? hashesJson =
          json['playerHashes'] as Map<String, dynamic>?;
      if (hashesJson != null) {
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

  /// Batas ukuran respons: 4 MB.
  static const int maxBytes = 4 * 1024 * 1024;

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
    final Response<dynamic> response = await _dio.get<dynamic>(
      url,
      options: Options(
        headers: <String, String>{'Accept': 'application/json'},
      ),
    );
    final dynamic data = response.data;
    final Map<String, dynamic>? json = data is Map<String, dynamic>
        ? data
        : data is String
        ? jsonDecode(data) as Map<String, dynamic>?
        : null;
    if (json == null) throw const FormatException('config bukan JSON');
    // Batas ukuran: serialisasi ulang tidak boleh melebihi 4 MB.
    final String encoded = jsonEncode(json);
    if (encoded.length > maxBytes) {
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
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      return RemotePlayerConfig.tryParse(
        json,
        fetchedAt: DateTime.parse(fetchedAtRaw),
      );
    } catch (_) {
      return null;
    }
  }
}
