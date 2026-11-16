/// Tautan dalam (P7, MUST #13): tautan youtu.be / music.youtube.com /
/// youtube.com yang dibuka dari luar app membuka lagu itu di Laras.
///
/// [parseYouTubeVideoId] murni (tanpa I/O, teruji penuh); intent filter
/// di AndroidManifest mendeklarasikan host + path yang sama, dan
/// MainActivity meneruskan tautan lewat EventChannel
/// `id.my.adipmusic.laras/deep_link`.
///
/// Alur buka: resolve metadata lewat resolver yang sama dengan pemutar
/// (satu panggilan player InnerTube ekstra per tautan — port akan
/// resolve lagi saat memuat; didokumentasikan, bukan bug), lalu antrean
/// diganti lagu itu dan langsung diputar (perilaku tautan-dalam standar:
/// tautan menggantikan antrean yang sedang jalan).
///
/// Batasan: resolver tidak memberi nama artis ([ResolvedAudio] tidak
/// punya author), jadi lagu dari tautan tampil tanpa artis sampai
/// metadata lengkap tersedia; judul jatuh ke videoId bila resolve tidak
/// memberi judul (jujur, bukan karangan).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:laras/extractor/extractor.dart';

import 'audio_player_port.dart';
import 'track.dart';

/// Pola videoId YouTube: tepat 11 karakter.
final RegExp _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// Ambil videoId YouTube (11 karakter) dari [uri], atau null bila bukan
/// tautan lagu YouTube yang valid.
///
/// Pola yang didukung:
/// - `youtu.be/<id>` (segmen path pertama)
/// - `youtube.com/watch?v=<id>`, `music.youtube.com/watch?v=<id>`,
///   `www.youtube.com/watch?v=<id>` (query `v`)
/// - `youtube.com/shorts/<id>` (pola berbagi yang umum)
String? parseYouTubeVideoId(Uri uri) {
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  final String host = uri.host.toLowerCase();
  String? candidate;
  if (host == 'youtu.be') {
    if (uri.pathSegments.isNotEmpty) candidate = uri.pathSegments.first;
  } else if (host == 'youtube.com' ||
      host == 'www.youtube.com' ||
      host == 'music.youtube.com') {
    if (uri.path == '/watch') {
      candidate = uri.queryParameters['v'];
    } else if (uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'shorts') {
      candidate = uri.pathSegments[1];
    }
  } else {
    return null;
  }
  if (candidate == null) return null;
  return _videoIdPattern.hasMatch(candidate) ? candidate : null;
}

/// Hasil pembukaan satu tautan dalam.
enum DeepLinkOutcome {
  /// Lagu berhasil dibuka dan diputar.
  opened,

  /// Tautan tidak bisa dibuka (tidak valid / jaringan / resolve gagal).
  failed,
}

/// Service tautan dalam: mendengarkan stream tautan dari platform dan
/// membuka lagunya lewat resolver + port.
class DeepLinkService {
  DeepLinkService({
    required Stream<String> links,
    required AudioResolver resolver,
    required AudioPlayerPort port,
  }) : _links = links, // ignore: prefer_initializing_formals
       _resolver = resolver, // ignore: prefer_initializing_formals
       _port = port; // ignore: prefer_initializing_formals

  final Stream<String> _links;
  final AudioResolver _resolver;
  final AudioPlayerPort _port;

  final StreamController<DeepLinkOutcome> _outcomes =
      StreamController<DeepLinkOutcome>.broadcast();

  /// Hasil tiap tautan yang ditangani.
  Stream<DeepLinkOutcome> get outcomes => _outcomes.stream;

  /// Hasil tautan terakhir (replay untuk subscriber yang telat datang).
  DeepLinkOutcome? get lastOutcome => _lastOutcome;
  DeepLinkOutcome? _lastOutcome;

  StreamSubscription<String>? _sub;
  bool _disposed = false;

  /// Mulai mendengarkan tautan dari platform.
  void start() {
    _sub ??= _links.listen(
      (String link) => unawaited(handleLink(link)),
      onError: (_) {
        // Error stream platform bukan kegagalan tautan: abaikan.
      },
    );
  }

  /// Tangani satu tautan mentah (string URL). Dipakai juga langsung oleh
  /// tes. Mengembalikan hasil pembukaannya.
  Future<DeepLinkOutcome> handleLink(String rawLink) async {
    final Uri? uri = Uri.tryParse(rawLink.trim());
    final String? videoId = uri == null
        ? null
        : parseYouTubeVideoId(uri);
    if (videoId == null) return _emit(DeepLinkOutcome.failed);
    try {
      final ResolvedAudio resolved = await _resolver.resolve(videoId);
      final int? seconds = resolved.lengthSeconds;
      final Track track = Track(
        videoId: videoId,
        title: resolved.title ?? videoId,
        duration: seconds == null ? null : Duration(seconds: seconds),
        artUri: Uri.parse('https://i.ytimg.com/vi/$videoId/hqdefault.jpg'),
      );
      await _port.setQueue(<Track>[track], autoplay: true);
      return _emit(DeepLinkOutcome.opened);
    } on Object catch (e) {
      debugPrint('Laras: tautan dalam gagal dibuka: $e');
      return _emit(DeepLinkOutcome.failed);
    }
  }

  DeepLinkOutcome _emit(DeepLinkOutcome outcome) {
    _lastOutcome = outcome;
    if (!_disposed) _outcomes.add(outcome);
    return outcome;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _sub?.cancel();
    _sub = null;
    await _outcomes.close();
  }
}
