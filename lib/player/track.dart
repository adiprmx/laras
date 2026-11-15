/// Satu lagu di antrean pemutar.
///
/// Antrean menyimpan identitas lagu ([videoId]), bukan URL stream: URL
/// kedaluwarsa dan hanya hidup di memori selama lagu itu diputar.
/// Dua entri dengan [videoId] yang sama adalah dua lagu berbeda di antrean
/// (pengguna boleh mengantre lagu yang sama dua kali), jadi kelas ini
/// sengaja tidak meng-override `==`: identitas antrean adalah identitas
/// objek, bukan nilai.
library;

class Track {
  const Track({
    required this.videoId,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.artUri,
    this.localPath,
  });

  /// ID video YouTube (atau ID lokal untuk lagu unduhan, P5).
  final String videoId;

  final String title;
  final String? artist;
  final String? album;

  /// Durasi dari metadata, bila diketahui sebelum lagu dimuat.
  final Duration? duration;

  /// Sampul lagu, bila ada (dari hasil pencarian, P4).
  final Uri? artUri;

  /// Path file lokal bila lagu sudah diunduh (P5). Null berarti streaming.
  final String? localPath;

  bool get isLocal => localPath != null;

  @override
  String toString() =>
      'Track(videoId: $videoId, title: $title, local: $isLocal)';
}
