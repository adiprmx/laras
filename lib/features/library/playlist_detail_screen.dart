/// Detail playlist: daftar lagu yang bisa diurutkan ulang (tekan lama
/// lalu seret), tambah lagu, ubah nama/deskripsi, hapus playlist.
///
/// Urutan diubah lewat [ReorderableListView]; perubahan posisi ditulis
/// ke database setiap kali seret selesai. Mengetuk lagu memutar playlist
/// dari lagu itu (maksimal 200 lagu, batas antrean pemutar).
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/empty_state.dart';
import 'package:laras/core/widgets/loading_rows.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/features/library/play_helpers.dart';
import 'package:laras/features/library/playlist_form_dialog.dart';
import 'package:laras/features/library/song_row.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player.dart';

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final int playlistId;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  Playlist? _playlist;
  List<PlaylistSongEntry> _entries = <PlaylistSongEntry>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _loadedOnce = false;

  LibraryService get _service => LibraryScope.maybeOf(context)!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Muat di sini, bukan initState: LibraryScope.maybeOf memakai context
    // yang baru valid setelah widget terpasang di tree.
    if (!_loadedOnce) {
      _loadedOnce = true;
      _reload();
    }
  }

  Future<void> _reload() async {
    final LibraryService service = LibraryScope.maybeOf(context)!;
    final Playlist? playlist = await service.playlistById(widget.playlistId);
    final List<PlaylistSongEntry> entries = await service.playlistSongsPage(
      widget.playlistId,
    );
    if (!mounted) return;
    setState(() {
      _playlist = playlist;
      _entries = entries;
      _hasMore = entries.length >= kPageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _entries.isEmpty) return;
    setState(() {
      _loadingMore = true;
    });
    final List<PlaylistSongEntry> page = await _service.playlistSongsPage(
      widget.playlistId,
      after: _entries.last,
    );
    if (!mounted) return;
    setState(() {
      _entries = <PlaylistSongEntry>[..._entries, ...page];
      _hasMore = page.length >= kPageSize;
      _loadingMore = false;
    });
  }

  // onReorderItem (Flutter 3.41+) memberi newIndex yang SUDAH
  // disesuaikan (indeks akhir), jadi tanpa koreksi -1 seperti onReorder.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final List<PlaylistSongEntry> reordered = List<PlaylistSongEntry>.of(
      _entries,
    );
    final PlaylistSongEntry moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    setState(() {
      _entries = reordered;
    });
    await _service.moveSongInPlaylist(
      widget.playlistId,
      moved.song.id,
      newIndex,
    );
  }

  Future<void> _rename() async {
    final Playlist? playlist = _playlist;
    if (playlist == null) return;
    final PlaylistFormResult? result = await showPlaylistFormDialog(
      context,
      initialName: playlist.name,
      initialDescription: playlist.description,
      isEditing: true,
    );
    if (result == null) return;
    await _service.renamePlaylist(widget.playlistId, result.name);
    await _service.updatePlaylistDescription(
      widget.playlistId,
      result.description,
    );
    await _reload();
  }

  Future<void> _delete() async {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final Playlist? playlist = _playlist;
    if (playlist == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(strings.deletePlaylistTitle),
          content: Text(strings.deletePlaylistBody(playlist.name)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _service.deletePlaylist(widget.playlistId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _addSongs() async {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final List<SongView>? picked = await showModalBottomSheet<List<SongView>>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return _PickSongsSheet(service: _service);
      },
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final int added = await _service.addSongsToPlaylist(
      widget.playlistId,
      picked.map((SongView v) => v.id).toList(),
    );
    if (!mounted) return;
    if (added > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.addedToPlaylist(_playlist?.name ?? ''))),
      );
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final Playlist? playlist = _playlist;
    final PlayerService? playerService = PlayerScope.maybeOf(context);
    final AudioPlayerPort? port = playerService?.port;
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist?.name ?? strings.playlists),
        actions: <Widget>[
          IconButton(
            onPressed: playlist == null ? null : _rename,
            tooltip: strings.renamePlaylist,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: playlist == null ? null : _delete,
            tooltip: strings.delete,
            icon: const Icon(Icons.delete_outlined),
          ),
        ],
      ),
      body: _loading
          ? const LoadingRows()
          : playlist == null
          ? Center(
              child: Text(
                strings.playlistEmpty,
                style: theme.textTheme.bodyMedium,
              ),
            )
          : StreamBuilder<PlayerSnapshot>(
              stream: port?.stateStream,
              initialData: port?.snapshot,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<PlayerSnapshot> shot,
                  ) {
                    final PlayerSnapshot snap =
                        shot.data ?? port?.snapshot ?? PlayerSnapshot.idle;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.sm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (playlist.description != null &&
                                  playlist.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: Text(
                                    playlist.description!,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              Text(
                                strings.playlistSongsCount(_entries.length),
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ElevatedButton.icon(
                                onPressed: _addSongs,
                                icon: const Icon(Icons.add),
                                label: Text(strings.addSongs),
                              ),
                            ],
                          ),
                        ),
                        if (_entries.isEmpty)
                          Expanded(
                            child: EmptyState(
                              icon: Icons.queue_music_outlined,
                              title: strings.playlistEmpty,
                              body: strings.playlistsEmptyBody,
                            ),
                          )
                        else
                          Expanded(
                            child: ReorderableListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              itemCount: _entries.length,
                              onReorderItem: _onReorder,
                              itemBuilder:
                                  (BuildContext context, int index) {
                                    final PlaylistSongEntry entry =
                                        _entries[index];
                                    final SongView view = entry.song;
                                    final Track track = view.toTrack();
                                    final Track? current = snap.currentTrack;
                                    final bool isCurrent =
                                        current != null &&
                                        current.videoId == track.videoId;
                                    return SongRow(
                                      key: ValueKey<String>(view.id),
                                      title: view.song.title,
                                      subtitle: view.artistNames.isEmpty
                                          ? null
                                          : view.artistsLabel,
                                      artUri: track.artUri,
                                      duration: track.duration,
                                      isCurrent: isCurrent,
                                      isPlaying: isCurrent && snap.playing,
                                      isUnplayable: view.song.unplayable,
                                      onTap: port == null
                                          ? null
                                          : () => _playFrom(
                                              port,
                                              snap,
                                              index,
                                            ),
                                      trailing: PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (String value) async {
                                          if (value == 'remove') {
                                            await _service
                                                .removeSongFromPlaylist(
                                                  widget.playlistId,
                                                  view.id,
                                                );
                                            await _reload();
                                          }
                                        },
                                        itemBuilder:
                                            (BuildContext context) =>
                                                <PopupMenuEntry<String>>[
                                                  PopupMenuItem<String>(
                                                    value: 'remove',
                                                    child: Text(
                                                      strings.removeFromPlaylist,
                                                    ),
                                                  ),
                                                ],
                                      ),
                                    );
                                  },
                            ),
                          ),
                        if (_hasMore)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Center(
                              child: _loadingMore
                                  ? Text(
                                      strings.loadingMore,
                                      style: theme.textTheme.bodySmall,
                                    )
                                  : TextButton(
                                      onPressed: _loadMore,
                                      child: Text(strings.loadMore),
                                    ),
                            ),
                          ),
                      ],
                    );
                  },
            ),
    );
  }

  Future<void> _playFrom(
    AudioPlayerPort port,
    PlayerSnapshot snap,
    int index,
  ) async {
    final List<SongView> items = _entries
        .map((PlaylistSongEntry e) => e.song)
        .toList();
    await playSongViews(
      port,
      snap,
      items,
      index,
      downloadsDir: DownloadsScope.downloadsDirOf(context),
    );
  }
}

/// Bottom sheet pilih lagu dari Library (multi-pilih dengan centang).
class _PickSongsSheet extends StatefulWidget {
  const _PickSongsSheet({required this.service});

  final LibraryService service;

  @override
  State<_PickSongsSheet> createState() => _PickSongsSheetState();
}

class _PickSongsSheetState extends State<_PickSongsSheet> {
  List<SongView> _songs = <SongView>[];
  bool _loading = true;
  bool _hasMore = false;
  final Set<String> _picked = <String>{};

  @override
  void initState() {
    super.initState();
    _loadFirst();
  }

  Future<void> _loadFirst() async {
    final List<SongView> page = await widget.service.songsPage();
    if (!mounted) return;
    setState(() {
      _songs = page;
      _hasMore = page.length >= kPageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_songs.isEmpty) return;
    final List<SongView> page = await widget.service.songsPage(
      after: _songs.last,
    );
    if (!mounted) return;
    setState(() {
      _songs = <SongView>[..._songs, ...page];
      _hasMore = page.length >= kPageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(strings.addSongs, style: theme.textTheme.titleMedium),
          ),
          Expanded(
            child: _loading
                ? const LoadingRows()
                : _songs.isEmpty
                ? EmptyState(
                    icon: Icons.music_note_outlined,
                    title: strings.libraryEmptyTitle,
                    body: strings.libraryEmptyBody,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: _songs.length + (_hasMore ? 1 : 0),
                    itemBuilder: (BuildContext context, int index) {
                      if (index >= _songs.length) {
                        return Center(
                          child: TextButton(
                            onPressed: _loadMore,
                            child: Text(strings.loadMore),
                          ),
                        );
                      }
                      final SongView view = _songs[index];
                      final bool picked = _picked.contains(view.id);
                      return SongRow(
                        title: view.song.title,
                        subtitle: view.artistNames.isEmpty
                            ? null
                            : view.artistsLabel,
                        artUri: view.toTrack().artUri,
                        duration: view.toTrack().duration,
                        isUnplayable: view.song.unplayable,
                        trailing: Icon(
                          picked
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: picked
                              ? theme.colorScheme.primary
                              : theme.iconTheme.color,
                        ),
                        onTap: () {
                          setState(() {
                            if (picked) {
                              _picked.remove(view.id);
                            } else {
                              _picked.add(view.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(strings.cancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _picked.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop(
                              _songs
                                  .where(
                                    (SongView v) => _picked.contains(v.id),
                                  )
                                  .toList(),
                            );
                          },
                    child: Text(strings.save),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
