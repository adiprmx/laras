/// Model data lapisan ekstraksi Laras.
///
/// Aturan yang mengikat: URL stream ([ResolvedAudio.url]) hanya hidup di
/// memori. Tidak pernah ditulis ke database, file, atau log. Kelas-kelas di
/// sini tidak mencetak URL di [toString].
library;

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

/// Satu hasil pencarian lagu dari YouTube Music.
class SearchSong {
  const SearchSong({
    required this.videoId,
    required this.title,
    this.artist,
    this.album,
    this.durationSeconds,
    this.thumbnailUrl,
  });

  final String videoId;
  final String title;
  final String? artist;
  final String? album;
  final int? durationSeconds;
  final String? thumbnailUrl;
}
