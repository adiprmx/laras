/// Parser respons player InnerTube menjadi [ParsedPlayerResponse].
///
/// Fungsi murni (tanpa I/O) supaya mudah dites dengan fixture respons asli
/// yang direkam spike. Parser tidak pernah mencetak URL stream.
///
/// Aturan SABR: status SABR ditentukan per format, bukan dari field
/// tingkat atas `streamingData` saja. Respons WEB_REMIX yang direkam spike
/// membawa URL SABR tingkat atas sekaligus format konvensional di
/// `adaptiveFormats` - jadi field tingkat atas saja tidak cukup.
///
/// Bentuk SABR-only yang teramati (client ANDROID/IOS, probe 15 Nov 2026):
/// format audio TIDAK punya `url`, TIDAK punya `signatureCipher`, dan
/// TIDAK punya `serverAbrStreamingUrl` per format - satu-satunya jalur
/// putar adalah URL SABR tingkat atas. Jadi sebuah format ditandai SABR
/// bila (a) punya `serverAbrStreamingUrl` sendiri, ATAU (b) tidak punya
/// URL langsung maupun cipher SEMENTARA respons membawa URL SABR tingkat
/// atas. Format tanpa URL/cipher di respons tanpa URL SABR tingkat atas
/// bukan SABR - itu format rusak, dan pemilih itag sudah melewatinya.
library;

import 'errors.dart';
import 'models.dart';

/// Parse satu respons player (JSON yang sudah di-decode) menjadi model.
///
/// Melempar [ExtractorException] penyebab [ResolveFailureCause.parseFailed]
/// bila struktur JSON tidak seperti yang diharapkan.
ParsedPlayerResponse parsePlayerResponse(Map<String, dynamic> json) {
  try {
    final Map<String, dynamic>? playabilityJson =
        json['playabilityStatus'] as Map<String, dynamic>?;
    final String status = playabilityJson?['status'] as String? ?? '';
    final Playability playability = switch (status) {
      'OK' => Playability.ok,
      'LOGIN_REQUIRED' => Playability.loginRequired,
      'ERROR' => Playability.error,
      '' => Playability.unknown,
      _ => Playability.error,
    };
    final String? reason = playabilityJson?['reason'] as String?;

    final Map<String, dynamic>? streamingData =
        json['streamingData'] as Map<String, dynamic>?;
    final bool hasTopLevelSabrUrl =
        streamingData?['serverAbrStreamingUrl'] is String;
    final int? expiresInSeconds = _asInt(streamingData?['expiresInSeconds']);

    final List<AudioFormat> audioFormats = <AudioFormat>[];
    final List<dynamic>? adaptive =
        streamingData?['adaptiveFormats'] as List<dynamic>?;
    if (adaptive != null) {
      for (final dynamic raw in adaptive) {
        // R1-M3: respons player yang sah membawa segelintir format audio;
        // hentikan pengumpulan di cap supaya daftar tidak tumbuh tanpa
        // batas dari respons yang dimanipulasi.
        if (audioFormats.length >= kMaxParserItemsPerGroup) break;
        if (raw is! Map<String, dynamic>) continue;
        final String mimeType = raw['mimeType'] as String? ?? '';
        if (!mimeType.startsWith('audio/')) continue;
        audioFormats.add(
          _parseAudioFormat(raw, hasTopLevelSabrUrl: hasTopLevelSabrUrl),
        );
      }
    }

    final Map<String, dynamic>? videoDetails =
        json['videoDetails'] as Map<String, dynamic>?;
    final String? title = videoDetails?['title'] as String?;
    final int? lengthSeconds = _asInt(videoDetails?['lengthSeconds']);

    return ParsedPlayerResponse(
      playability: playability,
      reason: reason,
      audioFormats: audioFormats,
      title: title,
      lengthSeconds: lengthSeconds,
      expiresInSeconds: expiresInSeconds,
      hasTopLevelSabrUrl: hasTopLevelSabrUrl,
    );
  } on ExtractorException {
    rethrow;
  } catch (e) {
    throw ExtractorException(
      ResolveFailureCause.parseFailed,
      detail: 'player JSON tidak sesuai bentuk yang diharapkan: $e',
    );
  }
}

AudioFormat _parseAudioFormat(
  Map<String, dynamic> raw, {
  required bool hasTopLevelSabrUrl,
}) {
  final int itag = _asInt(raw['itag']) ?? 0;
  final String mimeType = raw['mimeType'] as String? ?? '';
  final int bitrate = _asInt(raw['bitrate']) ?? 0;
  final int? contentLength = _asInt(raw['contentLength']);
  final String? url = raw['url'] as String?;
  final String? signatureCipher = raw['signatureCipher'] as String?;
  // SABR bila format sendiri membawa URL SABR, atau format tidak punya
  // jalur putar konvensional (tanpa URL langsung dan tanpa cipher)
  // sementara respons membawa URL SABR tingkat atas.
  final bool isSabr =
      raw['serverAbrStreamingUrl'] is String ||
      (url == null &&
          (signatureCipher == null || signatureCipher.isEmpty) &&
          hasTopLevelSabrUrl);

  String? cipheredSignature;
  String? cipherParamName;
  String? cipherUrl;
  if (signatureCipher != null && signatureCipher.isNotEmpty) {
    // signatureCipher adalah query string berkode URL: s=...&sp=...&url=...
    final Map<String, String> params = Uri.splitQueryString(signatureCipher);
    cipheredSignature = params['s'];
    cipherParamName = params['sp'];
    cipherUrl = params['url'];
  }

  return AudioFormat(
    itag: itag,
    mimeType: mimeType,
    bitrate: bitrate,
    contentLength: contentLength,
    url: url,
    cipheredSignature: cipheredSignature,
    cipherParamName: cipherParamName,
    cipherUrl: cipherUrl,
    isSabr: isSabr,
  );
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

/// Parse respons search InnerTube menjadi daftar lagu.
///
/// Kolektor berjalan iteratif (tanpa batas kedalaman) di seluruh pohon
/// respons dan mengambil setiap `videoId` yang punya judul. Bentuk respons
/// search YouTube Music dalam dan berubah-ubah, jadi parser ini sengaja
/// toleran: entri tanpa judul tetap diambil dengan judul kosong dan
/// disaring di lapisan atas.
List<SearchSong> parseSearchResponse(Map<String, dynamic> json) {
  final List<SearchSong> out = <SearchSong>[];
  final Set<String> seen = <String>{};
  final List<Object?> stack = <Object?>[json];
  while (stack.isNotEmpty) {
    // R1-M3: hentikan pengumpulan di cap (lihat kMaxParserItemsPerGroup).
    if (out.length >= kMaxParserItemsPerGroup) break;
    final Object? node = stack.removeLast();
    if (node is List) {
      stack.addAll(node);
      continue;
    }
    if (node is! Map<String, dynamic>) continue;
    final Object? videoId = node['videoId'];
    if (videoId is String && videoId.length == 11 && seen.add(videoId)) {
      final String title = _extractTitle(node);
      out.add(SearchSong(videoId: videoId, title: title));
    }
    stack.addAll(node.values);
  }
  return out;
}

String _extractTitle(Map<String, dynamic> node) {
  // Judul biasanya di node yang sama (title.simpleText) atau di saudara
  // dekat; kolektor di atas hanya melihat node yang membawa videoId, jadi
  // judul diambil dari field title bila ada.
  final Object? title = node['title'];
  if (title is Map<String, dynamic>) {
    final Object? simple = title['simpleText'];
    if (simple is String) return simple;
    final Object? runs = title['runs'];
    if (runs is List && runs.isNotEmpty) {
      final Object? first = runs.first;
      if (first is Map<String, dynamic>) {
        final Object? text = first['text'];
        if (text is String) return text;
      }
    }
  }
  if (title is String) return title;
  return '';
}
