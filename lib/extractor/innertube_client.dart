/// Client HTTP InnerTube: request player/search/browse ke youtubei.
///
/// Semua request memakai host [kInnertubeHost] (`www.youtube.com`); POST ke
/// `music.youtube.com` stall total dari VM dan tidak pernah dipakai.
///
/// Timeout eksplisit di semua request (arsitektur 5.6): connect 10 detik,
/// receive 30 detik. Angka receive dinaikkan dari 15 ke 30 detik di P0
/// dengan bukti probe 16 Nov 2026: tiga request player yang sah dari VM
/// memakan 16,2 / 22,2 / 26,5 detik (egress lambat) - semuanya akan mati
/// dibunuh timeout 15 detik. Jaringan HP yang lambat tapi hidup punya
/// risiko yang sama. Retry 3x dengan backoff 1 detik lalu 2 detik (+jitter)
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
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'client_definitions.dart';
import 'errors.dart';
import 'models.dart';
import 'player_parser.dart';
import 'response_limits.dart';
import 'search_parser.dart';

/// Hasil search: visitorData segar + daftar lagu.
///
/// [grouped] membawa pengelompokan penuh (lagu, album, artis, playlist);
/// [songs] adalah jalan pintas ke [GroupedSearchResults.songs] untuk
/// pemakaian lama (refresh visitorData, kanari).
class SearchResult {
  const SearchResult({
    required this.visitorData,
    required this.songs,
    this.grouped = const GroupedSearchResults(),
  });

  /// visitorData dari `responseContext`, atau null bila server tidak
  /// memberikannya.
  final String? visitorData;
  final List<SearchSong> songs;

  /// Hasil yang sudah dikelompokkan + parameter filter chip.
  final GroupedSearchResults grouped;
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
              receiveTimeout: const Duration(seconds: 30),
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
  ///
  /// [params] adalah parameter filter dari chip respons sebelumnya
  /// (mis. hanya lagu); null berarti pencarian tanpa filter.
  /// Parser terstruktur dipakai dulu; bila tidak menemukan satu pun
  /// lagu, kolektor toleran lama dipakai sebagai cadangan (bentuk
  /// respons berubah tidak langsung mengosongkan hasil).
  Future<SearchResult> search(
    String query,
    ClientDefinition client, {
    String? params,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'context': <String, dynamic>{
        'client': client.contextWithVisitorData(_visitorData),
      },
      'query': query,
    };
    if (params != null && params.isNotEmpty) {
      body['params'] = params;
    }
    final Map<String, dynamic> json = await _postJson(
      '/youtubei/v1/search',
      body,
      client,
    );
    // R1-M4: seluruh fase parse dibungkus try/catch (meniru
    // parsePlayerResponse) — cast `as` yang gagal melempar TypeError,
    // dan TypeError yang lolos dari sini membuat layar pencarian macet
    // di loading selamanya (pemanggil hanya menangkap ExtractorException).
    try {
      // Respons search yang valid selalu membawa `contents` — walau
      // hasilnya kosong. Tanpa itu, server menolak (mis. LOGIN_REQUIRED)
      // dan client berikut patut dicoba; diam-diam kosong akan menipu
      // pengguna seolah tidak ada hasil.
      if (json['contents'] == null) {
        throw const ExtractorException(
          ResolveFailureCause.parseFailed,
          detail: 'respons search tanpa contents',
        );
      }
      final Map<String, dynamic>? responseContext =
          json['responseContext'] as Map<String, dynamic>?;
      final String? visitorData = responseContext?['visitorData'] as String?;
      if (visitorData != null && visitorData.isNotEmpty) {
        _visitorData = visitorData;
        _visitorDataFetchedAt = DateTime.now();
      }
      final GroupedSearchResults grouped = parseGroupedSearchResults(json);
      final List<SearchSong> songs = grouped.songs.isNotEmpty
          ? grouped.songs
          : parseSearchResponse(json);
      return SearchResult(
        visitorData: visitorData,
        songs: songs,
        grouped: grouped,
      );
    } on ExtractorException {
      rethrow;
    } catch (e) {
      throw ExtractorException(
        ResolveFailureCause.parseFailed,
        detail: 'respons search tidak sesuai bentuk yang diharapkan: $e',
      );
    }
  }

  /// Request browse YouTube Music: beranda (FEmusic_home), halaman
  /// artis/album/playlist (browseId), atau kategori mood/genre
  /// (browseId + [params]).
  Future<BrowsePage> browse(
    String browseId,
    ClientDefinition client, {
    String? params,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'context': <String, dynamic>{
        'client': client.contextWithVisitorData(_visitorData),
      },
      'browseId': browseId,
    };
    if (params != null && params.isNotEmpty) {
      body['params'] = params;
    }
    final Map<String, dynamic> json = await _postJson(
      '/youtubei/v1/browse',
      body,
      client,
    );
    // R1-M4: sama seperti search — TypeError dari parser dipetakan ke
    // ExtractorException supaya layar browse menampilkan pesan error +
    // tombol coba lagi, bukan shimmer selamanya.
    try {
      if (json['contents'] == null) {
        throw const ExtractorException(
          ResolveFailureCause.parseFailed,
          detail: 'respons browse tanpa contents',
        );
      }
      return parseBrowsePage(json);
    } on ExtractorException {
      rethrow;
    } catch (e) {
      throw ExtractorException(
        ResolveFailureCause.parseFailed,
        detail: 'respons browse tidak sesuai bentuk yang diharapkan: $e',
      );
    }
  }

  /// Request saran pencarian (`music/get_search_suggestions`).
  ///
  /// Mengembalikan daftar teks saran (paling banyak 8, sesuai PRD
  /// B1.2). Kegagalan apa pun melempar [ExtractorException] dan
  /// ditangani pemanggil dengan diam (saran hilang, pencarian penuh
  /// tetap jalan).
  Future<List<String>> fetchSuggestions(
    String input,
    ClientDefinition client,
  ) async {
    final Map<String, dynamic> json = await _postJson(
      '/youtubei/v1/music/get_search_suggestions',
      <String, dynamic>{
        'context': <String, dynamic>{
          'client': client.contextWithVisitorData(_visitorData),
        },
        'input': input,
      },
      client,
    );
    // R1-M4: sama seperti search/browse.
    try {
      final List<String> suggestions = parseSearchSuggestions(json);
      return suggestions.take(8).toList(growable: false);
    } on ExtractorException {
      rethrow;
    } catch (e) {
      throw ExtractorException(
        ResolveFailureCause.parseFailed,
        detail: 'respons saran tidak sesuai bentuk yang diharapkan: $e',
      );
    }
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
    final Map<String, dynamic> playbackContext = <String, dynamic>{
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
  /// Batas ditegakkan SAAT STREAMING (R1-M3): begitu byte yang mengalir
  /// melewati batas, pembacaan dibatalkan — respons tidak pernah utuh di
  /// memori. Melempar [ExtractorException] bila ukuran melewati batas
  /// atau jaringan gagal. Retry 3x (backoff 1 dtk lalu 2 dtk) untuk
  /// error jaringan dan HTTP 429/503 - sama seperti [_postJson]. Retry
  /// penting karena load script ada di jalur kritis resolve pertama
  /// (untuk sts).
  Future<String> fetchText(
    String url, {
    int maxBytes = ResponseLimits.playerScriptBytes,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    const List<Duration> backoff = <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 2),
    ];
    final Random random = Random();
    DioException? lastError;
    for (int attempt = 0; attempt < 3; attempt++) {
      // Cap per percobaan (token yang dibatalkan tidak bisa dipakai ulang).
      final ResponseSizeCap cap = ResponseSizeCap(maxBytes);
      try {
        final Response<ResponseBody> response =
            await _dio.get<ResponseBody>(
              url,
              options: Options(
                responseType: ResponseType.stream,
                receiveTimeout: timeout,
                sendTimeout: const Duration(seconds: 10),
                headers: <String, String>{
                  'User-Agent': kWebRemixClient.userAgent,
                  'Accept': '*/*',
                },
              ),
              cancelToken: cap.cancelToken,
              onReceiveProgress: cap.onReceiveProgress,
            );
        checkContentLength(response, maxBytes);
        final Uint8List bytes = await readCappedResponseBody(
          response.data!,
          requestOptions: response.requestOptions,
          maxBytes: maxBytes,
          chunkTimeout: timeout,
        );
        return utf8.decode(bytes);
      } on ExtractorException {
        rethrow;
      } on DioException catch (e) {
        // Respons raksasa (cap) bukan error jaringan: jangan retry,
        // langsung parseFailed.
        cap.throwIfExceeded();
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
  ///
  /// Respons dibaca sebagai stream dengan batas
  /// [ResponseLimits.youtubeiJsonBytes] (R1-M3): Dio tidak pernah
  /// men-decode body tanpa batas. Body yang bukan objek JSON (atau JSON
  /// yang tidak valid) melempar parseFailed.
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
      // Cap per percobaan (token yang dibatalkan tidak bisa dipakai ulang).
      final ResponseSizeCap cap =
          ResponseSizeCap(ResponseLimits.youtubeiJsonBytes);
      try {
        final Response<ResponseBody> response =
            await _dio.post<ResponseBody>(
              '$path?key=$kInnertubeApiKey&prettyPrint=false',
              data: body,
              options: Options(
                responseType: ResponseType.stream,
                headers: <String, String>{
                  'User-Agent': client.userAgent,
                  'X-YouTube-Client-Name': client.clientId,
                  'X-YouTube-Client-Version': client.version,
                  'Accept': 'application/json',
                  'Accept-Language': 'en-US,en;q=0.9',
                },
              ),
              cancelToken: cap.cancelToken,
              onReceiveProgress: cap.onReceiveProgress,
            );
        checkContentLength(response, ResponseLimits.youtubeiJsonBytes);
        final Uint8List bytes = await readCappedResponseBody(
          response.data!,
          requestOptions: response.requestOptions,
          maxBytes: ResponseLimits.youtubeiJsonBytes,
          chunkTimeout: const Duration(seconds: 30),
        );
        final dynamic decoded = _decodeJsonBytes(bytes);
        if (decoded is Map<String, dynamic>) return decoded;
        throw const ExtractorException(
          ResolveFailureCause.parseFailed,
          detail: 'respons youtubei bukan objek JSON',
        );
      } on ExtractorException {
        rethrow;
      } on DioException catch (e) {
        // Respons raksasa (cap) bukan error jaringan: jangan retry,
        // langsung parseFailed.
        cap.throwIfExceeded();
        lastError = e;
        final bool retryable = _isRetryable(e);
        if (!retryable || attempt == maxAttempts - 1) break;
        final Duration delay =
            backoff[attempt] + Duration(milliseconds: random.nextInt(500));
        await Future<void>.delayed(delay);
      }
    }
    throw _mapDioException(lastError!, client.name);
  }

  /// Decode byte respons menjadi JSON. FormatException (UTF-8/JSON tidak
  /// valid) dipetakan ke parseFailed — respons 200 yang isinya sampah
  /// adalah kegagalan parse, bukan kegagalan jaringan.
  dynamic _decodeJsonBytes(Uint8List bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException catch (e) {
      throw ExtractorException(
        ResolveFailureCause.parseFailed,
        detail: 'respons youtubei bukan JSON valid: $e',
      );
    }
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
    final bool timeout =
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
    final bool network =
        timeout || e.type == DioExceptionType.connectionError;
    return ExtractorException(
      ResolveFailureCause.emptyResponse,
      clientName: clientName,
      isNetworkError: network,
      isTimeout: timeout,
      detail:
          'request gagal: ${e.type}'
          '${status != null ? ' HTTP $status' : ''}',
    );
  }
}
