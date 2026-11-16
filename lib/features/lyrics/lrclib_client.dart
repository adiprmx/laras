/// Client LRCLIB (https://lrclib.net) — layanan lirik gratis tanpa
/// kunci atau akun untuk baca.
///
/// Diverifikasi dari 3 sumber independen 16 Nov 2026: dokumentasi di
/// cors.dev (cek live 28 Okt 2026), bytetools.bytevancer.com (tes live
/// 21 Agu 2026), dan DeepWiki dari source code tranxuanthang/lrclib.
/// Probe live dari VM GAGAL (egress mati, http=000) — verifikasi live
/// dari perangkat masih utang dan dicatat di p7-notes.
///
/// Endpoint baca (tanpa auth):
/// - `GET /api/get?artist_name=&track_name=&album_name=&duration=`
///   (404 bila tidak cocok; durasi dalam detik, toleransi ±2 detik)
/// - `GET /api/search?q=` (daftar, urut relevansi)
/// - `GET /api/get/<id>`
///
/// Aturan layanan: User-Agent deskriptif wajib; rate limit ~45 req/menit
/// per IP untuk client generik (429 + header Retry-After). Client ini
/// tidak me-retry sendiri — pemanggil (LyricsService) yang memutuskan.
library;

import 'package:dio/dio.dart';

/// User-Agent yang dikirim ke LRCLIB (aturan layanan: deskriptif +
/// cara menghubungi pemilik client).
const String kLrclibUserAgent =
    'Laras/0.9.0 (https://github.com/adiprmx/laras)';

/// Satu hasil lirik dari LRCLIB.
class LrclibTrack {
  const LrclibTrack({
    required this.id,
    this.plainLyrics,
    this.syncedLyrics,
    this.instrumental = false,
    this.duration,
  });

  factory LrclibTrack.fromJson(Map<String, dynamic> json) {
    final String? plain = _nonEmptyString(json['plainLyrics']);
    final String? synced = _nonEmptyString(json['syncedLyrics']);
    final num? durationSeconds = json['duration'] as num?;
    return LrclibTrack(
      id: (json['id'] as num?)?.toInt() ?? 0,
      plainLyrics: plain,
      syncedLyrics: synced,
      instrumental: json['instrumental'] as bool? ?? false,
      duration: durationSeconds == null
          ? null
          : Duration(seconds: durationSeconds.round()),
    );
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : value;
  }

  final int id;

  /// Lirik polos (tanpa timestamp), null bila tidak ada.
  final String? plainLyrics;

  /// Lirik format LRC (dengan timestamp), null bila tidak ada.
  final String? syncedLyrics;

  /// True bila lagu terbukti instrumental (tanpa lirik).
  final bool instrumental;

  /// Durasi lagu menurut LRCLIB, bila ada.
  final Duration? duration;

  /// True bila ada lirik yang bisa ditampilkan (polos atau tersinkron).
  bool get hasLyrics => plainLyrics != null || syncedLyrics != null;
}

/// Penyebab kegagalan client LRCLIB.
enum LrclibFailureKind {
  /// Lirik tidak ditemukan (404 / pencarian kosong). Bukan error.
  notFound,

  /// Rate limit (429).
  rateLimited,

  /// Jaringan bermasalah (tidak ada internet, timeout).
  network,

  /// Respons tidak bisa dibaca (bukan JSON yang diharapkan, HTTP lain).
  invalidResponse,
}

/// Error dari [LrclibClient]. `notFound` tidak pernah dilempar sebagai
/// exception — [LrclibClient.fetchLyrics] mengembalikan null untuk itu.
class LrclibException implements Exception {
  const LrclibException(this.kind, [this.message]);

  final LrclibFailureKind kind;
  final String? message;

  @override
  String toString() => 'LrclibException($kind${message == null ? '' : ': $message'})';
}

/// Client baca LRCLIB. [Dio] bisa disuntik (tes memakai adapter palsu).
class LrclibClient {
  LrclibClient({Dio? dio, String userAgent = kLrclibUserAgent})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://lrclib.net/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          ) {
    // User-Agent selalu dipasang — termasuk bila Dio disuntik dari luar
    // (tes): aturan layanan LRCLIB mewajibkannya di tiap request.
    _dio.options.headers['User-Agent'] = userAgent;
  }

  final Dio _dio;

  /// Cari lirik yang paling cocok untuk lagu ini.
  ///
  /// Jalur utama `/get` (judul + artis + album + durasi); bila 404,
  /// fallback ke `/search` dan ambil hasil pertama yang durasinya cocok
  /// (±2 detik) bila durasi diketahui, atau hasil pertama bila tidak.
  /// Mengembalikan null bila tidak ada lirik yang cocok.
  ///
  /// Melempar [LrclibException] untuk rate limit, jaringan, dan respons
  /// yang tidak bisa dibaca.
  Future<LrclibTrack?> fetchLyrics({
    required String artist,
    required String title,
    String? album,
    Duration? duration,
  }) async {
    final Map<String, Object> params = <String, Object>{
      'artist_name': artist,
      'track_name': title,
    };
    final String? albumName = album?.trim();
    if (albumName != null && albumName.isNotEmpty) {
      params['album_name'] = albumName;
    }
    if (duration != null) {
      params['duration'] = duration.inSeconds;
    }
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/get',
        queryParameters: params,
      );
      final Object? data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const LrclibException(
          LrclibFailureKind.invalidResponse,
          'respons /get bukan objek',
        );
      }
      return LrclibTrack.fromJson(data);
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status == 404) {
        return _searchFallback(
          artist: artist,
          title: title,
          duration: duration,
        );
      }
      throw _mapDioException(e);
    }
  }

  Future<LrclibTrack?> _searchFallback({
    required String artist,
    required String title,
    Duration? duration,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/search',
        queryParameters: <String, Object>{'q': '$artist $title'},
      );
      final Object? data = response.data;
      if (data is! List) {
        throw const LrclibException(
          LrclibFailureKind.invalidResponse,
          'respons /search bukan daftar',
        );
      }
      final List<LrclibTrack> tracks = data
          .whereType<Map<String, dynamic>>()
          .map(LrclibTrack.fromJson)
          .toList(growable: false);
      if (tracks.isEmpty) return null;
      if (duration == null) return tracks.first;
      for (final LrclibTrack track in tracks) {
        final Duration? trackDuration = track.duration;
        if (trackDuration == null) continue;
        if ((trackDuration - duration).inSeconds.abs() <= 2) return track;
      }
      return tracks.first;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _mapDioException(e);
    }
  }

  LrclibException _mapDioException(DioException e) {
    final int? status = e.response?.statusCode;
    if (status == 429) {
      return const LrclibException(
        LrclibFailureKind.rateLimited,
        'terlalu banyak permintaan ke LRCLIB',
      );
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return LrclibException(
          LrclibFailureKind.network,
          e.message ?? e.error?.toString(),
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return LrclibException(
          LrclibFailureKind.invalidResponse,
          e.message ?? e.error?.toString(),
        );
    }
  }
}
