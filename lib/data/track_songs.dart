/// Jembatan satu-satunya antara lagu pemutar ([Track]) dan baris database.
///
/// Pemetaan ini dipakai pencatat riwayat, tombol favorit di Player, dan
/// tombol favorit di mini-player, supaya ketiganya menulis metadata yang
/// sama untuk lagu yang sama.
///
/// Aturan pemetaan: `videoId` menjadi id lagu; `artist` (satu string nama)
/// menjadi satu nama artis (dengan channelId bila `Track` membawanya);
/// `album` dipetakan ke baris album HANYA bila `Track` membawa
/// `albumBrowseId` yang stabil (dari hasil pencarian/browse YTM, P4) —
/// judul album tanpa browseId tidak dibuatkan baris karena akan duplikat.
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

  /// channelId artis sejajar [artistNames] (nol atau satu id).
  List<String?> get artistChannelIds {
    final String? channelId = artistChannelId?.trim();
    if (artistNames.isEmpty) return const <String?>[];
    return <String?>[channelId];
  }

  /// Companion album untuk insert/update baris album dari metadata
  /// track, atau null bila track tidak membawa browseId album.
  ///
  /// Album hanya dicatat bila ada browseId yang stabil (dari hasil
  /// pencarian/browse YTM, P4); judul album tanpa browseId tidak
  /// dibuatkan baris karena akan duplikat.
  AlbumsCompanion? get albumCompanion {
    final String? browseId = albumBrowseId?.trim();
    final String? title = album?.trim();
    if (browseId == null ||
        browseId.isEmpty ||
        title == null ||
        title.isEmpty) {
      return null;
    }
    return AlbumsCompanion(
      id: Value<String>(browseId),
      title: Value<String>(title),
    );
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
