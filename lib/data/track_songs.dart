/// Jembatan satu-satunya antara lagu pemutar ([Track]) dan baris database.
///
/// Pemetaan ini dipakai pencatat riwayat, tombol favorit di Player, dan
/// tombol favorit di mini-player, supaya ketiganya menulis metadata yang
/// sama untuk lagu yang sama.
///
/// Aturan pemetaan: `videoId` menjadi id lagu; `artist` (satu string nama)
/// menjadi satu nama artis; `album` (satu string judul) TIDAK dipetakan ke
/// baris album karena [Track] tidak membawa browseId album, dan album
/// tanpa id yang stabil akan duplikat. Album dicatat P4 dari hasil
/// pencarian YTM yang membawa browseId.
library;

import 'package:drift/drift.dart';
import 'package:laras/player/track.dart';

import 'laras_database.dart';
import 'library_service.dart';

extension TrackSongMapping on Track {
  /// Companion untuk insert/update baris lagu dari metadata track.
  ///
  /// Kolom yang tidak dibawa [Track] (liked, total waktu putar, status
  /// unduhan, tanggal) diisi [LibraryService.upsertSong], bukan di sini.
  SongsCompanion toSongsCompanion() {
    return SongsCompanion(
      id: Value<String>(videoId),
      title: Value<String>(title),
      durationSeconds: duration == null
          ? const Value<int?>(null)
          : Value<int?>(duration!.inSeconds),
      thumbnailUrl: artUri == null
          ? const Value<String?>(null)
          : Value<String?>(artUri.toString()),
    );
  }

  /// Nama artis sebagai daftar (nol atau satu nama, sesuai [artist]).
  List<String> get artistNames {
    final String? name = artist?.trim();
    if (name == null || name.isEmpty) return const <String>[];
    return <String>[name];
  }
}

/// Arah sebaliknya: lagu dari database menjadi lagu pemutar.
///
/// Dipakai beranda (seksi library) dan tab Library saat pengguna mengetuk
/// lagu: daftar yang tampil menjadi antrean pemutar.
extension SongViewTrack on SongView {
  Track toTrack() {
    final int? seconds = song.durationSeconds;
    final String? thumbnail = song.thumbnailUrl;
    return Track(
      videoId: song.id,
      title: song.title,
      artist: artistNames.isEmpty ? null : artistsLabel,
      duration: seconds == null ? null : Duration(seconds: seconds),
      artUri: thumbnail == null || thumbnail.isEmpty
          ? null
          : Uri.tryParse(thumbnail),
    );
  }
}
