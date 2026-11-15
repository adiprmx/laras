/// Logika putar bersama untuk daftar lagu (beranda dan library).
///
/// Satu aturan di semua tempat: mengetuk lagu yang sedang diputar
/// menjeda/melanjutkannya; mengetuk lagu lain mengganti antrean dengan
/// daftar yang tampil, mulai dari lagu yang diketuk.
library;

import 'package:laras/data/database.dart';
import 'package:laras/player/player.dart';

/// Putar [tracks] mulai dari [index]: jeda/lanjut bila lagu itu yang
/// sedang diputar, ganti antrean bila bukan.
Future<void> playTracks(
  AudioPlayerPort port,
  PlayerSnapshot snap,
  List<Track> tracks,
  int index,
) async {
  if (tracks.isEmpty || index < 0 || index >= tracks.length) return;
  final Track tapped = tracks[index];
  final Track? current = snap.currentTrack;
  if (current != null && current.videoId == tapped.videoId) {
    if (snap.playing) {
      await port.pause();
    } else {
      await port.play();
    }
    return;
  }
  await port.setQueue(tracks, initialIndex: index, autoplay: true);
}

/// Putar daftar lagu database mulai dari [index].
///
/// Antrean pemutar dibatasi 200 lagu: bila daftar yang dimuat lebih dari
/// itu, antrean diambil 200 lagu mulai dari lagu yang diketuk (pengguna
/// memutar "dari sini ke depan", bukan seluruh library sekaligus).
Future<void> playSongViews(
  AudioPlayerPort port,
  PlayerSnapshot snap,
  List<SongView> items,
  int index,
) async {
  if (items.isEmpty || index < 0 || index >= items.length) return;
  final List<Track> all = items.map((SongView v) => v.toTrack()).toList();
  if (all.length <= kMaxQueueLength) {
    await playTracks(port, snap, all, index);
    return;
  }
  final int end = (index + kMaxQueueLength).clamp(0, all.length);
  final List<Track> window = all.sublist(index, end);
  await playTracks(port, snap, window, 0);
}
