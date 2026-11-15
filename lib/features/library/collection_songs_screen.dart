/// Layar daftar lagu satu koleksi (artis atau album).
///
/// Dipakai dari tab Artis dan tab Album di Library. Judul layar adalah
/// nama artis/album; daftarnya lagu-lagu koleksi itu, urut nama.
/// Mengetuk lagu memutar koleksi dari lagu itu.
library;

import 'package:flutter/material.dart';
import 'package:laras/data/database.dart';
import 'package:laras/features/library/paged_list.dart';
import 'package:laras/features/library/play_helpers.dart';
import 'package:laras/features/library/song_row.dart';
import 'package:laras/player/player.dart';

class CollectionSongsScreen extends StatelessWidget {
  const CollectionSongsScreen({
    super.key,
    required this.title,
    required this.loadPage,
  });

  /// Nama artis atau album.
  final String title;

  /// Pemuatan halaman lagu koleksi (keyset, seperti tab lainnya).
  final Future<List<SongView>> Function(SongView? after) loadPage;

  @override
  Widget build(BuildContext context) {
    final PlayerService? playerService = PlayerScope.maybeOf(context);
    final AudioPlayerPort? port = playerService?.port;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: port == null
          ? _buildList(context, null, PlayerSnapshot.idle)
          : StreamBuilder<PlayerSnapshot>(
              stream: port.stateStream,
              initialData: port.snapshot,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<PlayerSnapshot> shot,
                  ) {
                    return _buildList(
                      context,
                      port,
                      shot.data ?? port.snapshot,
                    );
                  },
            ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AudioPlayerPort? port,
    PlayerSnapshot snap,
  ) {
    return PagedList<SongView>(
      loadPage: loadPage,
      itemBuilder:
          (
            BuildContext context,
            SongView view,
            int index,
            List<SongView> items,
          ) {
            final Track track = view.toTrack();
            final Track? current = snap.currentTrack;
            final bool isCurrent =
                current != null && current.videoId == track.videoId;
            final bool busy =
                isCurrent &&
                (snap.status == PlayerStatus.loading ||
                    snap.status == PlayerStatus.buffering);
            return SongRow(
              title: view.song.title,
              subtitle: view.artistNames.isEmpty ? null : view.artistsLabel,
              artUri: track.artUri,
              duration: track.duration,
              isCurrent: isCurrent,
              isPlaying: isCurrent && snap.playing,
              isBusy: busy,
              onTap: port == null
                  ? null
                  : () => playSongViews(port, snap, items, index),
            );
          },
      emptyIcon: Icons.music_note_outlined,
      emptyTitle: title,
      emptyBody: '',
    );
  }
}
