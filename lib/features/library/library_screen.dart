/// Library: lagu, playlist, favorit, riwayat, album, artis.
///
/// Enam tab di bawah judul. Tiap tab memakai daftar berpaginasi (50 per
/// halaman) dan memuat ulang sendiri saat database berubah dari tempat
/// lain (mis. favorit ditandai dari layar Player).
///
/// Tanpa service (widget test, atau database gagal dibuka), layar ini
/// tidak crash: menampilkan pesan jujur (gagal buka) atau empty state
/// (belum ada service). Pengaturan dibuka lewat ikon gerigi di header
/// ini, satu-satunya pintu masuk Pengaturan.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/album_cover.dart';
import 'package:laras/core/widgets/empty_state.dart';
import 'package:laras/core/widgets/pressable.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/features/downloads/download_button.dart';
import 'package:laras/features/library/add_to_playlist_sheet.dart';
import 'package:laras/features/library/collection_songs_screen.dart';
import 'package:laras/features/library/paged_list.dart';
import 'package:laras/features/library/play_helpers.dart';
import 'package:laras/features/library/playlist_detail_screen.dart';
import 'package:laras/features/library/playlist_form_dialog.dart';
import 'package:laras/features/library/song_row.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.onSettingsRequested});

  final VoidCallback onSettingsRequested;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final LibraryService? service = LibraryScope.maybeOf(context);
    final bool failed = LibraryScope.failedOf(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
              0,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    strings.tabLibrary,
                    style: theme.textTheme.displayLarge,
                  ),
                ),
                IconButton(
                  onPressed: onSettingsRequested,
                  tooltip: strings.settings,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
          ),
          if (service == null)
            Expanded(
              child: failed
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          strings.libraryFailed,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : EmptyState(
                      icon: Icons.library_music_outlined,
                      title: strings.libraryEmptyTitle,
                      body: strings.libraryEmptyBody,
                    ),
            )
          else
            Expanded(
              child: DefaultTabController(
                length: 6,
                child: Column(
                  children: <Widget>[
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: AppColors.hairline,
                      tabs: <Widget>[
                        Tab(text: strings.songs),
                        Tab(text: strings.playlists),
                        Tab(text: strings.favorite),
                        Tab(text: strings.history),
                        Tab(text: strings.albums),
                        Tab(text: strings.artists),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: <Widget>[
                          _SongsTab(service: service),
                          _PlaylistsTab(service: service),
                          _FavoritesTab(service: service),
                          _HistoryTab(service: service),
                          _AlbumsTab(service: service),
                          _ArtistsTab(service: service),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Menyediakan state pemutar untuk satu tab: StreamBuilder bila ada port,
/// snapshot idle bila tidak ada port (tes tanpa player).
class _WithPlayerState extends StatelessWidget {
  const _WithPlayerState({required this.builder});

  final Widget Function(
    BuildContext context,
    AudioPlayerPort? port,
    PlayerSnapshot snap,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    final PlayerService? playerService = PlayerScope.maybeOf(context);
    final AudioPlayerPort? port = playerService?.port;
    if (port == null) return builder(context, null, PlayerSnapshot.idle);
    return StreamBuilder<PlayerSnapshot>(
      stream: port.stateStream,
      initialData: port.snapshot,
      builder: (BuildContext context, AsyncSnapshot<PlayerSnapshot> shot) {
        return builder(context, port, shot.data ?? port.snapshot);
      },
    );
  }
}

/// Baris lagu library: hati + menu di ujung kanan, ketuk untuk memutar.
Widget _librarySongRow(
  BuildContext context, {
  required LibraryService service,
  required AudioPlayerPort? port,
  required PlayerSnapshot snap,
  required SongView view,
  required int index,
  required List<SongView> items,
  bool showRemoveFromLibrary = false,
}) {
  final AppLocalizations strings = AppLocalizations.of(context)!;
  final String? downloadsDir = DownloadsScope.downloadsDirOf(context);
  final Track track = view.toTrack(downloadsDir: downloadsDir);
  final Track? current = snap.currentTrack;
  final bool isCurrent =
      current != null && current.videoId == track.videoId;
  final bool busy =
      isCurrent &&
      (snap.status == PlayerStatus.loading ||
          snap.status == PlayerStatus.buffering);
  final bool liked = view.song.liked;
  return SongRow(
    title: view.song.title,
    subtitle: view.artistNames.isEmpty ? null : view.artistsLabel,
    artUri: track.artUri,
    duration: track.duration,
    isCurrent: isCurrent,
    isPlaying: isCurrent && snap.playing,
    isBusy: busy,
    isUnplayable: view.song.unplayable,
    onTap: port == null
        ? null
        : () => playSongViews(
            port,
            snap,
            items,
            index,
            downloadsDir: downloadsDir,
          ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DownloadButton(track: track),
        IconButton(
          onPressed: () => service.toggleLiked(view.id),
          tooltip: liked ? strings.favoriteRemove : strings.favoriteAdd,
          icon: Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            color: liked ? AppColors.accent : AppColors.textMuted,
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
          onSelected: (String value) async {
            if (value == 'add') {
              await showAddToPlaylistSheet(
                context,
                service: service,
                songId: view.id,
              );
            } else if (value == 'remove') {
              await service.removeFromLibrary(view.id);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'add',
              child: Text(strings.addToPlaylist),
            ),
            if (showRemoveFromLibrary)
              PopupMenuItem<String>(
                value: 'remove',
                child: Text(strings.removeFromLibrary),
              ),
          ],
        ),
      ],
    ),
  );
}

/// Tab Lagu: daftar lagu Library dengan sortir (diingat per pilihan).
class _SongsTab extends StatefulWidget {
  const _SongsTab({required this.service});

  final LibraryService service;

  @override
  State<_SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<_SongsTab> {
  late SongSort _sort;

  @override
  void initState() {
    super.initState();
    _sort = widget.service.sortPrefs.songSort;
  }

  String _sortLabel(AppLocalizations strings, SongSort sort) {
    return switch (sort) {
      SongSort.newest => strings.sortNewest,
      SongSort.byName => strings.sortByName,
      SongSort.mostPlayed => strings.sortMostPlayed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final LibraryService service = widget.service;
    return _WithPlayerState(
      builder:
          (BuildContext context, AudioPlayerPort? port, PlayerSnapshot snap) {
            return PagedList<SongView>(
              key: ValueKey<SongSort>(_sort),
              loadPage: (SongView? after) =>
                  service.songsPage(sort: _sort, after: after),
              reloadStream: service.libraryChanged,
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      children: <Widget>[
                        PopupMenuButton<SongSort>(
                      tooltip: strings.sortBy,
                      onSelected: (SongSort sort) {
                        service.sortPrefs.songSort = sort;
                        setState(() {
                          _sort = sort;
                        });
                      },
                      itemBuilder: (BuildContext context) =>
                          SongSort.values.map((SongSort sort) {
                            return PopupMenuItem<SongSort>(
                              value: sort,
                              child: Row(
                                children: <Widget>[
                                  if (sort == _sort)
                                    const Icon(Icons.check, size: 20)
                                  else
                                    const SizedBox(width: 20),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(_sortLabel(strings, sort)),
                                ],
                              ),
                            );
                          }).toList(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.sort, size: 20),
                          const SizedBox(width: AppSpacing.xs),
                          Text(_sortLabel(strings, _sort)),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                        ),
                      ],
                    ),
                  ),
                  // P6 (B4.7): hapus massal lagu yang tidak bisa diputar
                  // (hanya tampil bila ada lagu bertanda).
                  _DeleteUnplayableRow(service: service),
                ],
              ),
              itemBuilder:
                  (
                    BuildContext context,
                    SongView view,
                    int index,
                    List<SongView> items,
                  ) {
                    return _librarySongRow(
                      context,
                      service: service,
                      port: port,
                      snap: snap,
                      view: view,
                      index: index,
                      items: items,
                      showRemoveFromLibrary: true,
                    );
                  },
              emptyIcon: Icons.music_note_outlined,
              emptyTitle: strings.libraryEmptyTitle,
              emptyBody: strings.libraryEmptyBody,
            );
          },
    );
  }
}

/// Baris hapus massal lagu yang tidak bisa diputar (P6, B4.7).
///
/// Hanya tampil bila ada lagu bertanda (bukan unduhan). Jumlah dihitung
/// ulang setiap kali database berubah. Penghapusan memakai dialog
/// konfirmasi yang menyebut jumlahnya.
class _DeleteUnplayableRow extends StatefulWidget {
  const _DeleteUnplayableRow({required this.service});

  final LibraryService service;

  @override
  State<_DeleteUnplayableRow> createState() => _DeleteUnplayableRowState();
}

class _DeleteUnplayableRowState extends State<_DeleteUnplayableRow> {
  StreamSubscription<void>? _sub;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _reload();
    _sub = widget.service.libraryChanged.listen((_) => _reload());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final int count = await widget.service.unplayableCount();
    if (!mounted || count == _count) return;
    setState(() {
      _count = count;
    });
  }

  Future<void> _confirmDelete() async {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(strings.deleteUnplayableTitle),
        content: Text(strings.deleteUnplayableBody(_count)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final int deleted = await widget.service.deleteUnplayableSongs();
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.deleteUnplayableDone(deleted))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _confirmDelete,
          icon: const Icon(Icons.delete_outline, size: 20),
          label: Text(strings.deleteUnplayable),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
        ),
      ),
    );
  }
}

/// Tab Playlist: daftar playlist + buat baru.
class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab({required this.service});

  final LibraryService service;

  Future<void> _create(BuildContext context) async {
    final PlaylistFormResult? result = await showPlaylistFormDialog(
      context,
      isEditing: false,
    );
    if (result == null) return;
    await service.createPlaylist(
      result.name,
      description: result.description,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return PagedList<PlaylistWithCount>(
      loadPage: (PlaylistWithCount? after) =>
          service.playlistsPage(after: after),
      reloadStream: service.libraryChanged,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: ElevatedButton.icon(
          onPressed: () => _create(context),
          icon: const Icon(Icons.add),
          label: Text(strings.createPlaylist),
        ),
      ),
      itemBuilder:
          (
            BuildContext context,
            PlaylistWithCount item,
            int index,
            List<PlaylistWithCount> items,
          ) {
            return Pressable(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        PlaylistDetailScreen(playlistId: item.playlist.id),
                  ),
                );
              },
              child: SizedBox(
                height: AppSizes.songRow,
                child: Row(
                  children: <Widget>[
                    Container(
                      width: AppSizes.touchTarget,
                      height: AppSizes.touchTarget,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppRadius.coverSmall),
                        ),
                      ),
                      child: const Icon(
                        Icons.queue_music_outlined,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.playlist.name,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            strings.playlistSongsCount(item.songCount),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            );
          },
      emptyIcon: Icons.queue_music_outlined,
      emptyTitle: strings.playlistsEmptyTitle,
      emptyBody: strings.playlistsEmptyBody,
    );
  }
}

/// Tab Favorit: lagu yang ditandai hati (playlist virtual).
class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab({required this.service});

  final LibraryService service;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return _WithPlayerState(
      builder:
          (BuildContext context, AudioPlayerPort? port, PlayerSnapshot snap) {
            return PagedList<SongView>(
              loadPage: (SongView? after) =>
                  service.favoriteSongsPage(after: after),
              reloadStream: service.libraryChanged,
              itemBuilder:
                  (
                    BuildContext context,
                    SongView view,
                    int index,
                    List<SongView> items,
                  ) {
                    return _librarySongRow(
                      context,
                      service: service,
                      port: port,
                      snap: snap,
                      view: view,
                      index: index,
                      items: items,
                    );
                  },
              emptyIcon: Icons.favorite_border,
              emptyTitle: strings.favoritesEmptyTitle,
              emptyBody: strings.favoritesEmptyBody,
            );
          },
    );
  }
}

/// Tab Riwayat: sesi putar terbaru dulu + hapus semua.
class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.service});

  final LibraryService service;

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static String _formatPlayedAt(DateTime dt) {
    final String hh = dt.hour.toString().padLeft(2, '0');
    final String mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}, $hh.$mm';
  }

  Future<void> _clear(BuildContext context) async {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(strings.clearHistoryTitle),
          content: Text(strings.clearHistoryBody),
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
    if (confirmed == true) {
      await service.clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return _WithPlayerState(
      builder:
          (BuildContext context, AudioPlayerPort? port, PlayerSnapshot snap) {
            return PagedList<PlayHistoryEntry>(
              loadPage: (PlayHistoryEntry? after) =>
                  service.historyPage(after: after),
              reloadStream: service.libraryChanged,
              header: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: <Widget>[
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _clear(context),
                      icon: const Icon(Icons.delete_outlined, size: 20),
                      label: Text(strings.clearHistory),
                    ),
                  ],
                ),
              ),
              itemBuilder:
                  (
                    BuildContext context,
                    PlayHistoryEntry entry,
                    int index,
                    List<PlayHistoryEntry> items,
                  ) {
                    final SongView view = entry.song;
                    final String? downloadsDir =
                        DownloadsScope.downloadsDirOf(context);
                    final Track track =
                        view.toTrack(downloadsDir: downloadsDir);
                    final Track? current = snap.currentTrack;
                    final bool isCurrent =
                        current != null &&
                        current.videoId == track.videoId;
                    final String playedAt = _formatPlayedAt(
                      entry.event.timestamp,
                    );
                    final String subtitle = view.artistNames.isEmpty
                        ? playedAt
                        : '${view.artistsLabel} • $playedAt';
                    return SongRow(
                      title: view.song.title,
                      subtitle: subtitle,
                      artUri: track.artUri,
                      duration: track.duration,
                      isCurrent: isCurrent,
                      isPlaying: isCurrent && snap.playing,
                      isUnplayable: view.song.unplayable,
                      onTap: port == null
                          ? null
                          : () => playSongViews(
                              port,
                              snap,
                              items
                                  .map(
                                    (PlayHistoryEntry e) => e.song,
                                  )
                                  .toList(),
                              index,
                              downloadsDir: downloadsDir,
                            ),
                      trailing: IconButton(
                        onPressed: () => showAddToPlaylistSheet(
                          context,
                          service: service,
                          songId: view.id,
                        ),
                        tooltip: strings.addToPlaylist,
                        icon: const Icon(
                          Icons.playlist_add,
                          color: AppColors.textMuted,
                        ),
                      ),
                    );
                  },
              emptyIcon: Icons.history_outlined,
              emptyTitle: strings.historyEmptyTitle,
              emptyBody: strings.historyEmptyBody,
            );
          },
    );
  }
}

/// Baris koleksi (album/artis): sampul + nama + jumlah lagu.
Widget _collectionRow(
  BuildContext context, {
  required String title,
  required String? thumbnailUrl,
  required int songCount,
  required VoidCallback onTap,
}) {
  final AppLocalizations strings = AppLocalizations.of(context)!;
  final ThemeData theme = Theme.of(context);
  final Uri? artUri = thumbnailUrl == null || thumbnailUrl.isEmpty
      ? null
      : Uri.tryParse(thumbnailUrl);
  return Pressable(
    onTap: onTap,
    child: SizedBox(
      height: AppSizes.songRow,
      child: Row(
        children: <Widget>[
          AlbumCover(artUri: artUri, size: AppSizes.touchTarget),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  strings.playlistSongsCount(songCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    ),
  );
}

/// Tab Album.
class _AlbumsTab extends StatelessWidget {
  const _AlbumsTab({required this.service});

  final LibraryService service;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return PagedList<AlbumWithCount>(
      loadPage: (AlbumWithCount? after) =>
          service.albumsPage(after: after),
      reloadStream: service.libraryChanged,
      itemBuilder:
          (
            BuildContext context,
            AlbumWithCount item,
            int index,
            List<AlbumWithCount> items,
          ) {
            return _collectionRow(
              context,
              title: item.album.title,
              thumbnailUrl: item.album.thumbnailUrl,
              songCount: item.songCount,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        CollectionSongsScreen(
                          title: item.album.title,
                          loadPage: (SongView? after) =>
                              service.songsByAlbumPage(
                                item.album.id,
                                after: after,
                              ),
                        ),
                  ),
                );
              },
            );
          },
      emptyIcon: Icons.album_outlined,
      emptyTitle: strings.albumsEmptyTitle,
      emptyBody: strings.albumsEmptyBody,
    );
  }
}

/// Tab Artis.
class _ArtistsTab extends StatelessWidget {
  const _ArtistsTab({required this.service});

  final LibraryService service;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return PagedList<ArtistWithCount>(
      loadPage: (ArtistWithCount? after) =>
          service.artistsPage(after: after),
      reloadStream: service.libraryChanged,
      itemBuilder:
          (
            BuildContext context,
            ArtistWithCount item,
            int index,
            List<ArtistWithCount> items,
          ) {
            return _collectionRow(
              context,
              title: item.artist.name,
              thumbnailUrl: item.artist.thumbnailUrl,
              songCount: item.songCount,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        CollectionSongsScreen(
                          title: item.artist.name,
                          loadPage: (SongView? after) =>
                              service.songsByArtistPage(
                                item.artist.id,
                                after: after,
                              ),
                        ),
                  ),
                );
              },
            );
          },
      emptyIcon: Icons.person_outlined,
      emptyTitle: strings.artistsEmptyTitle,
      emptyBody: strings.artistsEmptyBody,
    );
  }
}
