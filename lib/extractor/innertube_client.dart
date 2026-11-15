/// Client HTTP InnerTube: request player/search/browse ke youtubei.
///
/// Semua request memakai host [kInnertubeHost] (`www.youtube.com`); POST ke
/// `music.youtube.com` stall total dari VM dan tidak pernah dipakai.
///
/// Timeout eksplisit di semua request (arsitektur 5.6): connect 10 detik,
/// receive 15 detik. Retry 3x dengan backoff 1 detik lalu 2 detik (+jitter)
/// HANYA untuk HTTP 429/503 dan error jaringan; error lain (termasuk
/// respons LOGIN_REQUIRED dari server) bukan alasan retry transport.
///
/// visitorData: bukti probe 15 Nov 2026 - saat reputasi IP rendah, request
/// player tanpa visitorData dibalas LOGIN_REQUIRED ("Sign in to confirm
/// you're not a bot") untuk SEMUA client, sementara request yang sama dengan
/// visitorData segar dari endpoint search lolos (WEB_REMIX, OK, 4 format
/// audio). Karena itu client ini mengambil visitorData dari search dan
/// menempelkannya ke request player; bila player tetap LOGIN_REQUIRED,
/// visitorData di-refresh sekali lalu request diulang sekali.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import 'client_definitions.dart';
import 'errors.dart';
import 'models.dart';
import 'player_parser.dart';

/// Hasil search: visitorData segar + daftar lagu.
class SearchResult {
  const SearchResult({required this.visitorData, required this.songs});

  /// visitorData dari `responseContext`, atau null bila server tidak
  /// memberikannya.
  final String? visitorData;
  final List<SearchSong> songs;
}

/// Client HTTP InnerTube (player + search).
class InnertubeClient {
  InnertubeClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://$kInnertubeHost',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 10),
              contentType: 'application/json',
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;

  /// visitorData terakhir yang berhasil diambil dari search.
  String? _visitorData;

  /// Waktu pengambilan visitorData terakhir (untuk kedaluwarsa cache).
  DateTime? _visitorDataFetchedAt;

  /// visitorData dianggap basi setelah 6 jam (sama dengan TTL config).
  static const Duration visitorDataTtl = Duration(hours: 6);

  /// Ambil visitorData segar lewat endpoint search (kueri netral).
  ///
  /// Hasil di-cache 6 jam. Bila search gagal, mengembalikan visitorData
  /// cache terakhir (bisa null) dan TIDAK melempar - request player tetap
  /// dicoba tanpa visitorData.
  Future<String?> ensureVisitorData(ClientDefinition client) async {
    final DateTime now = DateTime.now();
    if (_visitorData != null &&
        _visitorDataFetchedAt != null &&
        now.difference(_visitorDataFetchedAt!) < visitorDataTtl) {
      return _visitorData;
    }
    try {
      final SearchResult result = await search(
        'lagu indonesia populer',
        client,
      );
      if (result.visitorData != null && result.visitorData!.isNotEmpty) {
        _visitorData = result.visitorData;
        _visitorDataFetchedAt = now;
      }
    } on ExtractorException {
      // Search gagal: pakai cache terakhir (atau null). Player tetap dicoba.
    }
    return _visitorData;
  }

  /// Paksa refresh visitorData (dipakai saat player LOGIN_REQUIRED).
  Future<String?> refreshVisitorData(ClientDefinition client) async {
    _visitorData = null;
    _visitorDataFetchedAt = null;
    return ensureVisitorData(client);
  }

  /// Request search YouTube Music.
  Future<SearchResult> search(String query, ClientDefinition client) async {
    final Map<String, dynamic> json = await _postJson(
      '/youtubei/v1/search',
      <String, dynamic>{
        'context': <String, dynamic>{
          'client': client.contextWithVisitorData(_visitorData),
        },
        'query': query,
      },
      client,
    );
    final Map<String, dynamic>? responseContext =
        json['responseContext'] as Map<String, dynamic>?;
    final String? visitorData = responseContext?['visitorData'] as String?;
    return SearchResult(
      visitorData: visitorData,
      songs: parseSearchResponse(json),
    );
  }

  /// Request player untuk satu videoId.
  ///
  /// [signatureTimestamp] (sts) dari base.js yang sedang dipakai, bila
  /// diketahui. [visitorData] menimpa cache bila diberikan.
  Future<ParsedPlayerResponse> fetchPlayer(
    String videoId,
    ClientDefinition client, {
    int? signatureTimestamp,
    String? visitorData,
  }) async {
    final String? vd = visitorData ?? _visitorData;
    final Map<String, dynamic> playbackContext =
        <String, dynamic>{
          'vis': 0,
          'splay': false,
          'autoCaptionsDefaultOn': false,
          'autonavState': 'STATE_OFF',
          'html5Preference': 'HTML5_PREF_WANTS',
          'lact': <dynamic>[],
          'signatureTimestamp': ?signatureTimestamp,
        };
    final Map<String, dynamic> json = await _postJson(
      '/youtubei/v1/player',
      <String, dynamic>{
        'context': <String, dynamic>{
          'client': client.contextWithVisitorData(vd),
        },
        'videoId': videoId,
        'playbackContext': <String, dynamic>{
          'contentPlaybackContext': playbackContext,
        },
        'racyCheckOk': true,
        'contentCheckOk': true,
      },
      client,
    );
    return parsePlayerResponse(json);
  }

  /// GET teks mentah (untuk HTML youtube.com dan base.js).
  ///
  /// [maxBytes] membatasi ukuran respons (base.js ~2,7 MB; HTML ~1 MB).
  /// Melempar [ExtractorException] bila ukuran melewati batas atau jaringan
  /// gagal. Retry 3x (backoff 1 dtk lalu 2 dtk) untuk error jaringan dan
  /// HTTP 429/503 - sama seperti [_postJson]. Retry penting karena load
  /// script ada di jalur kritis resolve pertama (untuk sts).
  Future<String> fetchText(
    String url, {
    int maxBytes = 8 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    const List<Duration> backoff = <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 2),
    ];
    final Random random = Random();
    DioException? lastError;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final Response<List<int>> response = await _dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: timeout,
            sendTimeout: const Duration(seconds: 10),
            headers: <String, String>{
              'User-Agent': kWebRemixClient.userAgent,
              'Accept': '*/*',
            },
          ),
        );
        final List<int> bytes = response.data ?? <int>[];
        if (bytes.length > maxBytes) {
          throw const ExtractorException(
            ResolveFailureCause.parseFailed,
            detail: 'respons teks melebihi batas ukuran',
          );
        }
        return utf8.decode(bytes);
      } on ExtractorException {
        rethrow;
      } on DioException catch (e) {
        lastError = e;
        if (!_isRetryable(e) || attempt == 2) break;
        await Future<void>.delayed(
          backoff[attempt] + Duration(milliseconds: random.nextInt(500)),
        );
      }
    }
    throw _mapDioException(lastError!, null);
  }

  /// POST JSON ke endpoint youtubei dengan retry backoff.
  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
    ClientDefinition client,
  ) async {
    const int maxAttempts = 3;
    const List<Duration> backoff = <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 2),
    ];
    final Random random = Random();
    DioException? lastError;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final Response<dynamic> response = await _dio.post<dynamic>(
          '$path?key=$kInnertubeApiKey&prettyPrint=false',
          data: body,
          options: Options(
            headers: <String, String>{
              'User-Agent': client.userAgent,
              'X-YouTube-Client-Name': client.clientId,
              'X-YouTube-Client-Version': client.version,
              'Accept': 'application/json',
              'Accept-Language': 'en-US,en;q=0.9',
            },
          ),
        );
        final dynamic data = response.data;
        if (data is Map<String, dynamic>) return data;
        if (data is String) {
          final dynamic decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) return decoded;
        }
        throw const ExtractorException(
          ResolveFailureCause.parseFailed,
          detail: 'respons youtubei bukan objek JSON',
        );
      } on ExtractorException {
        rethrow;
      } on DioException catch (e) {
        lastError = e;
        final bool retryable = _isRetryable(e);
        if (!retryable || attempt == maxAttempts - 1) break;
        final Duration delay =
            backoff[attempt] +
            Duration(milliseconds: random.nextInt(500));
        await Future<void>.delayed(delay);
      }
    }
    throw _mapDioException(lastError!, client.name);
  }

  /// Retry hanya untuk 429/503 dan error jaringan (timeout, koneksi putus,
  /// DNS). HTTP 4xx lain dan error respons bukan alasan retry.
  bool _isRetryable(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    final int? status = e.response?.statusCode;
    return status == 429 || status == 503;
  }

  ExtractorException _mapDioException(DioException e, String? clientName) {
    final int? status = e.response?.statusCode;
    if (status == 403) {
      return ExtractorException(
        ResolveFailureCause.httpForbidden,
        clientName: clientName,
        detail: 'HTTP 403 dari server',
      );
    }
    final bool network =
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
    return ExtractorException(
      ResolveFailureCause.emptyResponse,
      clientName: clientName,
      isNetworkError: network,
      detail:
          'request gagal: ${e.type}'
          '${status != null ? ' HTTP $status' : ''}',
    );
  }
}
