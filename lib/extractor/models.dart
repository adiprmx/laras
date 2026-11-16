/// Model data lapisan ekstraksi Laras.
///
/// Aturan yang mengikat: URL stream ([ResolvedAudio.url]) hanya hidup di
/// memori. Tidak pernah ditulis ke database, file, atau log. Kelas-kelas di
/// sini tidak mencetak URL di [toString].
library;

import 'errors.dart';

/// Batas jumlah item per kelompok hasil parse (rencana §3.3: 100 item
/// per halaman; halaman playlist YouTube sendiri berukuran 100 item,
/// jadi cap ini tidak memotong hasil yang sah). Mencegah satu respons
/// raksasa menumbuhkan daftar tanpa batas di memori (R1-M3).
const int kMaxParserItemsPerGroup = 100;

/// Satu format audio dari respons player InnerTube.
class AudioFormat {
  const AudioFormat({
    required this.itag,
    required this.mimeType,
    required this.bitrate,
    this.contentLength,
    this.url,
    this.cipheredSignature,
    this.cipherParamName,
    this.cipherUrl,
    this.isSabr = false,
  });

  /// ID format YouTube (251, 140, 250, 249, 139 untuk audio).
  final int itag;

  /// Contoh: `audio/webm; codecs="opus"`.
  final String mimeType;

  /// Bitrate dalam bit per detik.
  final int bitrate;

  /// Ukuran file dalam byte, bila server menyebutkannya.
  final int? contentLength;

  /// URL stream langsung, bila format ini tidak terproteksi signature.
  final String? url;

  /// Nilai `s` dari `signatureCipher`, bila URL terproteksi.
  final String? cipheredSignature;

  /// Nama parameter signature (`sp`, biasanya `sig`).
  final String? cipherParamName;

  /// URL dari `signatureCipher` (belum ada parameter signature).
  final String? cipherUrl;

  /// Benar bila format ini adalah format SABR (`serverAbrStreamingUrl`).
  /// Format SABR tidak pernah dipilih: v1 menolak SABR, bukan memutarnya.
  final bool isSabr;

  /// Benar bila format ini bisa dipakai tanpa solver (URL langsung ada).
  bool get hasDirectUrl => url != null && url!.isNotEmpty;

  /// Benar bila format ini butuh solver signature + n challenge.
  bool get needsSolver =>
      cipheredSignature != null && cipherUrl != null && !isSabr;

  @override
  String toString() =>
      'AudioFormat(itag: $itag, mimeType: $mimeType, bitrate: $bitrate, '
      'direct: $hasDirectUrl, cipher: ${cipheredSignature != null}, '
      'sabr: $isSabr)';
}

/// Hasil resolve satu lagu: URL audio yang siap diputar.
///
/// URL hanya ada di memori dan kedaluwarsa (server menyebut
/// `expiresInSeconds`, sekitar 6 jam pada respons yang direkam spike).
/// Pemutar memakai URL ini segera; antrean menyimpan videoId, bukan URL.
class ResolvedAudio {
  const ResolvedAudio({
    required this.videoId,
    required this.url,
    required this.itag,
    required this.mimeType,
    required this.bitrate,
    required this.clientName,
    required this.resolveDuration,
    this.title,
    this.lengthSeconds,
  });

  final String videoId;

  /// URL stream audio. Jangan dicetak ke log.
  final String url;
  final int itag;
  final String mimeType;
  final int bitrate;

  /// Client InnerTube yang akhirnya memberi URL ini.
  final String clientName;

  /// Waktu resolve dari panggilan pertama sampai URL siap.
  final Duration resolveDuration;
  final String? title;
  final int? lengthSeconds;

  @override
  String toString() =>
      'ResolvedAudio(videoId: $videoId, itag: $itag, client: $clientName, '
      'resolveMs: ${resolveDuration.inMilliseconds})';
}

/// Status pemutaran dari `playabilityStatus` respons player.
enum Playability {
  /// Lagu bisa diputar; `streamingData` ada.
  ok,

  /// Server meminta login. Tanpa login di v1, client ini gagal.
  loginRequired,

  /// Server menolak dengan alasan lain (dihapus, dibatasi wilayah, dst).
  error,

  /// Status tidak dikenal atau respons tidak membawa `playabilityStatus`.
  unknown,
}

/// Hasil parse respons player, sebelum pemilihan format dan solver.
class ParsedPlayerResponse {
  const ParsedPlayerResponse({
    required this.playability,
    required this.audioFormats,
    this.reason,
    this.title,
    this.lengthSeconds,
    this.expiresInSeconds,
    this.hasTopLevelSabrUrl = false,
  });

  final Playability playability;

  /// Alasan server bila tidak bisa diputar (teks mentah, hanya untuk log
  /// internal; pesan ke pengguna memakai string ARB).
  final String? reason;
  final List<AudioFormat> audioFormats;
  final String? title;
  final int? lengthSeconds;
  final int? expiresInSeconds;

  /// Benar bila `streamingData` membawa `serverAbrStreamingUrl` tingkat atas.
  /// Ini bukan berarti semua format adalah SABR: respons WEB_REMIX yang
  /// direkam spike membawa URL SABR tingkat atas sekaligus format
  /// konvensional di `adaptiveFormats`. Yang menentukan SABR adalah
  /// tiap format, bukan field tingkat atas ini.
  final bool hasTopLevelSabrUrl;

  /// Benar bila semua format audio yang ada adalah SABR (tidak ada format
  /// konvensional yang bisa dipilih).
  bool get isSabrOnly =>
      audioFormats.isNotEmpty && audioFormats.every((f) => f.isSabr);
}

/// Satu baris log resolve (tanpa URL stream).
class ResolveLogEntry {
  const ResolveLogEntry({
    required this.timestamp,
    required this.videoId,
    required this.clientName,
    required this.outcome,
    required this.durationMs,
    this.cause,
    this.isNetworkError = false,
    this.isTimeout = false,
    this.skipped = false,
  });

  final DateTime timestamp;
  final String videoId;
  final String clientName;

  /// Hasil dibaca manusia, mis. 'OK itag 251', 'GAGAL httpForbidden',
  /// 'LEWATI (butuh script)'. Untuk diagnosis mesin pakai [cause] +
  /// [skipped], bukan parse string ini.
  final String outcome;
  final int durationMs;

  /// Penyebab kegagalan terstruktur (P0-2), null bila upaya ini sukses
  /// atau dilewati. Diisi dari [ExtractorException.cause] upaya itu.
  final ResolveFailureCause? cause;

  /// Benar bila kegagalan ini berasal dari jaringan perangkat.
  final bool isNetworkError;

  /// Benar bila kegagalan ini adalah timeout.
  final bool isTimeout;

  /// Benar bila client ini DILEWATI tanpa request player (mode
  /// terdegradasi: butuh script padahal script gagal dimuat).
  final bool skipped;

  @override
  String toString() =>
      '${timestamp.toIso8601String()} $videoId [$clientName] '
      '$outcome ${durationMs}ms';
}

/// Foto kegagalan resolve terakhir (P0-2, tindak lanjut gejala
/// "coba lagi mulu" 16 Nov 2026 18:56 WIB).
///
/// Dipakai layar "Laporkan kerusakan" (P6, B11.4) sebagai data kode
/// diagnostik: jenis gagal + penyebab + waktu + client yang dicoba.
/// TIDAK berisi URL stream, judul lagu, atau data pribadi — [videoId]
/// hanya dipakai internal (pencocokan dengan log) dan TIDAK masuk
/// [diagnosticCode].
///
/// Kontrak antar tim: P6 membaca snapshot ini dari resolver pemutar
/// ([StreamResolver.lastFailure]; bila resolver bukan StreamResolver,
/// turun ke [AudioResolver.recentLog] dan ambil entri resolve terakhir
/// dari entri dengan timestamp terbaru). Snapshot dibersihkan (null)
/// saat sebuah resolve sukses — yang tersimpan selalu kegagalan
/// TERAKHIR yang belum disusul sukses.
class ResolveFailureSnapshot {
  const ResolveFailureSnapshot({
    required this.videoId,
    required this.timestamp,
    required this.cause,
    required this.isNetworkError,
    required this.isTimeout,
    required this.attempts,
    required this.hadVisitorData,
  });

  /// videoId lagu yang gagal di-resolve (internal saja, tidak masuk kode).
  final String videoId;

  /// Waktu kegagalan terjadi.
  final DateTime timestamp;

  /// Penyebab akhir yang dilempar ke pemutar (aturan "paling informatif"
  /// orkestrator: non-jaringan didahulukan).
  final ResolveFailureCause cause;

  /// Benar bila penyebab akhir adalah jaringan perangkat.
  final bool isNetworkError;

  /// Benar bila penyebab akhir adalah timeout.
  final bool isTimeout;

  /// Upaya per client dalam resolve yang gagal ini, sesuai urutan
  /// dicoba — termasuk entri SCRIPT dan yang dilewati. Tanpa URL.
  final List<ResolveLogEntry> attempts;

  /// Benar bila visitorData tersedia saat resolve gagal. Palsu berarti
  /// search visitorData gagal total — petunjuk IP perangkat kena cek bot
  /// sejak awal (semua client LOGIN_REQUIRED tanpa visitorData saat
  /// reputasi IP rendah, bukti P1).
  final bool hadVisitorData;

  /// Kode diagnostik ringkas untuk laporan kerusakan, mis.
  /// `R1/httpForbidden/WEB_REMIX:httpForbidden/MWEB:httpForbidden/
  /// ANDROID_VR:httpForbidden`. Stabil antar versi (bagian dep `R1`
  /// adalah versi format kode). Tanpa videoId, judul, dan URL.
  String get diagnosticCode {
    final StringBuffer code = StringBuffer('R1/${cause.name}');
    if (isTimeout) code.write('/TIMEOUT');
    if (!hadVisitorData) code.write('/NOVD');
    for (final ResolveLogEntry attempt in attempts) {
      code.write('/${attempt.clientName}:');
      if (attempt.skipped) {
        code.write('SKIP');
      } else if (attempt.cause != null) {
        code.write(attempt.cause!.name);
      } else {
        code.write('OK');
      }
    }
    return code.toString();
  }
}

/// Satu hasil pencarian lagu dari YouTube Music.
///
/// [artistChannelId] dan [albumBrowseId] diisi bila respons membawa
/// tautan artis/album (P4): dipakai untuk menggabungkan artis pseudo-id
/// lokal ke channelId asli dan mencatat album lagu (lihat
/// `LibraryService.mergeArtistChannel`).
class SearchSong {
  const SearchSong({
    required this.videoId,
    required this.title,
    this.artist,
    this.artistChannelId,
    this.album,
    this.albumBrowseId,
    this.durationSeconds,
    this.thumbnailUrl,
  });

  final String videoId;
  final String title;
  final String? artist;

  /// channelId YouTube Music artis utama, bila respons membawanya.
  final String? artistChannelId;
  final String? album;

  /// browseId album (awalan `MPRE`), bila respons membawanya.
  final String? albumBrowseId;
  final int? durationSeconds;
  final String? thumbnailUrl;
}

/// Satu hasil pencarian album dari YouTube Music.
class SearchAlbum {
  const SearchAlbum({
    required this.browseId,
    required this.title,
    this.artists = const <String>[],
    this.year,
    this.thumbnailUrl,
  });

  /// browseId album (awalan `MPRE`).
  final String browseId;
  final String title;
  final List<String> artists;
  final int? year;
  final String? thumbnailUrl;
}

/// Satu hasil pencarian artis dari YouTube Music.
class SearchArtist {
  const SearchArtist({
    required this.channelId,
    required this.name,
    this.thumbnailUrl,
    this.subscribersText,
  });

  /// channelId artis (awalan `UC`).
  final String channelId;
  final String name;
  final String? thumbnailUrl;

  /// Teks jumlah pendengar/pengikut apa adanya dari respons
  /// (mis. "33.5M monthly audience"), atau null bila tidak ada.
  final String? subscribersText;
}

/// Satu hasil pencarian playlist dari YouTube Music.
class SearchPlaylist {
  const SearchPlaylist({
    required this.browseId,
    required this.title,
    this.subtitle,
    this.thumbnailUrl,
  });

  /// browseId playlist (awalan `VLPL`, `VLRD`, atau `PL`).
  final String browseId;
  final String title;

  /// Keterangan apa adanya dari respons (pembuat, jumlah lagu).
  final String? subtitle;
  final String? thumbnailUrl;
}

/// Hasil pencarian yang sudah dikelompokkan.
///
/// Kelompok yang gagal di-parse tidak mengosongkan kelompok lain:
/// parser mengisi kelompok yang berhasil dan membiarkan sisanya kosong
/// (PRD B1.1).
class GroupedSearchResults {
  const GroupedSearchResults({
    this.songs = const <SearchSong>[],
    this.albums = const <SearchAlbum>[],
    this.artists = const <SearchArtist>[],
    this.playlists = const <SearchPlaylist>[],
    this.filterParams = const <String, String>{},
  });

  /// Lagu dan video musik (keduanya bisa diputar lewat videoId).
  final List<SearchSong> songs;
  final List<SearchAlbum> albums;
  final List<SearchArtist> artists;
  final List<SearchPlaylist> playlists;

  /// Parameter filter pencarian per kelompok, dibaca dari chip respons
  /// (kunci: `songs`, `albums`, `artists`, `playlists`). Dipakai layar
  /// "Lihat semua" untuk meminta daftar penuh satu kelompok. Kosong
  /// bila respons tidak membawa chip.
  final Map<String, String> filterParams;

  bool get isEmpty =>
      songs.isEmpty && albums.isEmpty && artists.isEmpty && playlists.isEmpty;
}

/// Jenis item di satu rak halaman browse.
enum BrowseItemKind {
  /// Lagu/video yang bisa diputar (membawa videoId).
  song,

  /// Album (membawa browseId `MPRE...`).
  album,

  /// Artis (membawa browseId channelId).
  artist,

  /// Playlist (membawa browseId `VL...`/`PL...`).
  playlist,

  /// Kategori mood/genre (membawa browseId + params).
  category,
}

/// Satu kartu/baris di halaman browse (beranda Jelajah, halaman artis,
/// album, playlist, mood).
class BrowseItem {
  const BrowseItem({
    required this.kind,
    required this.title,
    this.subtitle,
    this.videoId,
    this.browseId,
    this.browseParams,
    this.thumbnailUrl,
    this.durationSeconds,
    this.artist,
    this.artistChannelId,
    this.album,
    this.albumBrowseId,
  });

  final BrowseItemKind kind;
  final String title;

  /// Keterangan di bawah judul (artis, jumlah lagu, tahun).
  final String? subtitle;

  /// videoId bila [kind] adalah [BrowseItemKind.song].
  final String? videoId;

  /// browseId bila item membuka halaman lain.
  final String? browseId;

  /// Parameter browse tambahan (dipakai kategori mood/genre).
  final String? browseParams;
  final String? thumbnailUrl;
  final int? durationSeconds;

  /// Artis utama (untuk lagu).
  final String? artist;

  /// channelId artis utama, bila respons membawanya.
  final String? artistChannelId;

  /// Judul album (untuk lagu).
  final String? album;

  /// browseId album, bila respons membawanya.
  final String? albumBrowseId;

  /// Benar bila item ini membuka halaman browse lain saat diketuk.
  bool get opensPage =>
      kind != BrowseItemKind.song && browseId != null && browseId!.isNotEmpty;
}

/// Satu rak (shelf) di halaman browse: judul + daftar item.
class BrowseShelf {
  const BrowseShelf({
    required this.title,
    this.items = const <BrowseItem>[],
    this.isSongList = false,
  });

  /// Judul rak apa adanya dari respons (mis. "Top songs").
  final String title;
  final List<BrowseItem> items;

  /// Benar bila rak ini adalah daftar lagu vertikal (bukan deretan
  /// kartu horizontal).
  final bool isSongList;
}

/// Satu halaman browse: kepala + rak-rak.
///
/// Dipakai beranda Jelajah (FEmusic_home), halaman artis, album,
/// playlist, dan kategori mood/genre. [continuation] adalah token
/// halaman berikut daftar lagu (playlist panjang), atau null bila
/// tidak ada.
class BrowsePage {
  const BrowsePage({
    required this.title,
    this.subtitle,
    this.thumbnailUrl,
    this.shelves = const <BrowseShelf>[],
    this.continuation,
  });

  final String title;
  final String? subtitle;
  final String? thumbnailUrl;
  final List<BrowseShelf> shelves;
  final String? continuation;

  /// Semua lagu di semua rak, sesuai urutan tampil.
  List<BrowseItem> get allSongs => <BrowseItem>[
    for (final BrowseShelf shelf in shelves)
      for (final BrowseItem item in shelf.items)
        if (item.kind == BrowseItemKind.song) item,
  ];

  bool get isEmpty => shelves.every((s) => s.items.isEmpty);
}
