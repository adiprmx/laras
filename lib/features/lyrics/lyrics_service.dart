/// Layanan lirik (P7): cache database dulu, LRCLIB bila belum tersimpan.
///
/// Urutan tiap permintaan:
/// 1. Cache database (tabel `lyrics`) — tanpa jaringan.
/// 2. Cache negatif in-memory per sesi ("tidak ada" / instrumental) —
///    supaya lagu yang sama tidak ditanyakan berulang dalam satu sesi.
/// 3. LRCLIB (jaringan) — hasil yang ada liriknya disimpan ke database;
///    "tidak ada" dan instrumental hanya dicatat in-memory (tidak
///    disimpan ke database, supaya lirik yang ditambahkan LRCLIB nanti
///    tetap bisa ditemukan di sesi berikutnya).
///
/// Tanpa database ([library] null), layanan tetap jalan fetch-only
/// (tanpa cache) — dipakai saat database gagal dibuka.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:laras/data/database.dart';
import 'package:laras/player/track.dart';

import 'lrclib_client.dart';

/// Batas ukuran lirik yang disimpan ke database (R3-L1): 256 KB per
/// kolom (polos maupun tersinkron). Lirik lagu normal jauh di bawah
/// ini; lirik di atas batas tetap ditampilkan di sesi ini tapi tidak
/// disimpan, supaya satu baris DB raksasa tidak membengkakkan file
/// database — dan terulang tiap lagu.
const int kMaxStoredLyricsBytes = 256 * 1024;

/// Status hasil pengambilan lirik.
enum LyricsStatus {
  /// Lirik ditemukan (polos, tersinkron, atau keduanya).
  found,

  /// LRCLIB tidak punya lirik lagu ini.
  notFound,

  /// Lagu terbukti instrumental (tanpa lirik).
  instrumental,

  /// Tidak ada internet (dan lirik belum tersimpan).
  offline,

  /// Gagal lain (rate limit, respons tidak bisa dibaca).
  error,
}

/// Hasil pengambilan lirik.
class LyricsResult {
  const LyricsResult({
    required this.status,
    this.plainLyrics,
    this.syncedLyrics,
  });

  const LyricsResult.notFound() : this(status: LyricsStatus.notFound);

  const LyricsResult.instrumental()
    : this(status: LyricsStatus.instrumental);

  const LyricsResult.offline() : this(status: LyricsStatus.offline);

  const LyricsResult.error() : this(status: LyricsStatus.error);

  final LyricsStatus status;

  /// Lirik polos (tanpa timestamp), bila ada.
  final String? plainLyrics;

  /// Lirik format LRC (dengan timestamp), bila ada.
  final String? syncedLyrics;

  /// True bila ada lirik tersinkron yang bisa di-parse.
  bool get hasSynced => syncedLyrics != null && syncedLyrics!.isNotEmpty;
}

/// Layanan lirik: cache + LRCLIB.
class LyricsService {
  LyricsService({required LrclibClient client, LibraryService? library})
    : _client = client, // ignore: prefer_initializing_formals
      _library = library; // ignore: prefer_initializing_formals

  final LrclibClient _client;
  final LibraryService? _library;

  /// videoId yang sudah terbukti tidak punya lirik (sesi ini saja).
  final Set<String> _notFound = <String>{};

  /// videoId yang sudah terbukti instrumental (sesi ini saja).
  final Set<String> _instrumental = <String>{};

  /// Permintaan yang sedang berjalan per videoId (dedup).
  final Map<String, Future<LyricsResult>> _inFlight =
      <String, Future<LyricsResult>>{};

  /// Ambil lirik lagu ini (cache dulu, LRCLIB bila belum ada).
  Future<LyricsResult> fetch(Track track) {
    final String videoId = track.videoId;
    final Future<LyricsResult>? existing = _inFlight[videoId];
    if (existing != null) return existing;
    final Future<LyricsResult> future = _fetch(track);
    _inFlight[videoId] = future;
    // Hapus dari map saat selesai (sukses atau gagal) supaya permintaan
    // berikutnya tidak memakai future yang sudah selesai.
    unawaited(future.whenComplete(() => _inFlight.remove(videoId)));
    return future;
  }

  Future<LyricsResult> _fetch(Track track) async {
    final String videoId = track.videoId;
    final LibraryService? library = _library;
    if (library != null) {
      try {
        final Lyric? cached = await library.getLyrics(videoId);
        if (cached != null) {
          return LyricsResult(
            status: LyricsStatus.found,
            plainLyrics: cached.lyrics,
            syncedLyrics: cached.syncedLyrics,
          );
        }
      } on Object catch (e) {
        // Cache rusak tidak boleh mematikan lirik: lanjut ke jaringan.
        debugPrint('Laras: baca cache lirik gagal: $e');
      }
    }
    if (_notFound.contains(videoId)) return const LyricsResult.notFound();
    if (_instrumental.contains(videoId)) {
      return const LyricsResult.instrumental();
    }
    final String? artist = track.artist?.trim();
    if (artist == null || artist.isEmpty) {
      // Tanpa nama artis, /get tidak bisa dipakai andal — LRCLIB butuh
      // artis + judul untuk mencocokkan. Perlakukan sebagai tidak ada.
      _notFound.add(videoId);
      return const LyricsResult.notFound();
    }
    try {
      final LrclibTrack? found = await _client.fetchLyrics(
        artist: artist,
        title: track.title,
        album: track.album,
        duration: track.duration,
      );
      if (found == null) {
        _notFound.add(videoId);
        return const LyricsResult.notFound();
      }
      if (found.instrumental) {
        _instrumental.add(videoId);
        return const LyricsResult.instrumental();
      }
      if (!found.hasLyrics) {
        _notFound.add(videoId);
        return const LyricsResult.notFound();
      }
      final LyricsResult result = LyricsResult(
        status: LyricsStatus.found,
        plainLyrics: found.plainLyrics,
        syncedLyrics: found.syncedLyrics,
      );
      if (library != null) {
        // R3-L1: lirik raksasa tidak disimpan ke DB (satu baris raksasa
        // per lagu = pembengkakan file DB). Lirik tetap tampil di sesi
        // ini; sesi berikut mengambil ulang dari jaringan.
        final int plainBytes = utf8.encode(found.plainLyrics ?? '').length;
        final int syncedBytes = utf8.encode(found.syncedLyrics ?? '').length;
        if (plainBytes > kMaxStoredLyricsBytes ||
            syncedBytes > kMaxStoredLyricsBytes) {
          debugPrint(
            'Laras: lirik terlalu besar untuk disimpan '
            '(polos $plainBytes byte, tersinkron $syncedBytes byte)',
          );
        } else {
          try {
            // Lagu wajib ada di tabel songs dulu (FK lyrics -> songs).
            await library.upsertSong(
              track.toSongsCompanion(),
              artistNames: track.artistNames,
              artistChannelIds: track.artistChannelIds,
              album: track.albumCompanion,
            );
            await library.saveLyrics(
              songId: videoId,
              lyrics: found.plainLyrics ?? '',
              syncedLyrics: found.syncedLyrics,
            );
          } on Object catch (e) {
            // Gagal menyimpan tidak membatalkan lirik yang sudah didapat.
            debugPrint('Laras: simpan lirik gagal: $e');
          }
        }
      }
      return result;
    } on LrclibException catch (e) {
      switch (e.kind) {
        case LrclibFailureKind.network:
          return const LyricsResult.offline();
        case LrclibFailureKind.notFound:
          _notFound.add(videoId);
          return const LyricsResult.notFound();
        case LrclibFailureKind.rateLimited:
        case LrclibFailureKind.invalidResponse:
          return const LyricsResult.error();
      }
    }
  }
}
