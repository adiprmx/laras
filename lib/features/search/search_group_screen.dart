/// Layar daftar penuh satu kelompok hasil pencarian ("Lihat semua").
///
/// Dua mode:
/// - Online: pencarian ulang dengan filter [params] kelompok itu
///   (mis. hanya lagu, hanya album), mengambil halaman penuh kelompok.
/// - Lokal: pencarian FTS5 dengan batas 50 (tanpa request jaringan).
///
/// Ketuk lagu memutarnya dan mengantre sisa daftar; ketuk album/artis/
/// playlist membuka halaman detailnya.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/empty_state.dart';
import 'package:laras/core/widgets/loading_rows.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/library/play_helpers.dart';
import 'package:laras/features/library/song_row.dart';
import 'package:laras/features/search/browse_card.dart';
import 'package:laras/features/search/browse_detail_screen.dart';
import 'package:laras/features/search/search_scope.dart';
import 'package:laras/features/search/search_service.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player.dart';

/// Kelompok hasil yang ditampilkan layar ini.
enum SearchGroup { songs, albums, artists, playlists, localSongs }

class SearchGroupScreen extends StatefulWidget {
  const SearchGroupScreen({
    super.key,
    required this.title,
    required this.query,
    required this.group,
    this.params,
  });

  final String title;
  final String query;
  final SearchGroup group;

  /// Param filter InnerTube kelompok ini; null berarti pakai hasil
  /// pencarian tanpa filter (dipakai bila chip filter tidak tersedia).
  final String? params;

  @override
  State<SearchGroupScreen> createState() => _SearchGroupScreenState();
}

class _SearchGroupScreenState extends State<SearchGroupScreen> {
  Future<CombinedSearch>? _future;
  Future<LocalSearchResults>? _localFuture;
  SearchService? _service;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final SearchService? service = SearchScope.maybeOf(context);
    if (service != _service) {
      _service = service;
      _load(service);
    }
  }

  void _load(SearchService? service) {
    if (widget.group == SearchGroup.localSongs) {
      _localFuture = service?.searchLocalOnly(widget.query);
      _future = null;
    } else {
      _future = service?.search(widget.query, params: widget.params);
      _localFuture = null;
    }
  }

  void _retry() {
    setState(() {
      _load(_service);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final PlayerService? service = PlayerScope.maybeOf(context);
    final AudioPlayerPort? port = service?.port;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: port == null
          ? _buildBody(context, strings, null, PlayerSnapshot.idle)
          : StreamBuilder<PlayerSnapshot>(
              stream: port.stateStream,
              initialData: port.snapshot,
              builder:
                  (BuildContext context, AsyncSnapshot<PlayerSnapshot> shot) {
                    return _buildBody(
                      context,
                      strings,
                      port,
                      shot.data ?? port.snapshot,
                    );
                  },
            ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations strings,
    AudioPlayerPort? port,
    PlayerSnapshot snap,
  ) {
    if (widget.group == SearchGroup.localSongs) {
      final Future<LocalSearchResults>? future = _localFuture;
      if (future == null) {
        return EmptyState(
          icon: Icons.search_off_outlined,
          title: strings.noResultsTitle,
          body: strings.searchNoResults(widget.query),
        );
      }
      return FutureBuilder<LocalSearchResults>(
        future: future,
        builder:
            (BuildContext context, AsyncSnapshot<LocalSearchResults> snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: LoadingRows(count: 6),
                );
              }
              return _LocalSongsList(
                views: snapshot.data!.songs,
                query: widget.query,
                port: port,
                snap: snap,
              );
            },
      );
    }
    final Future<CombinedSearch>? future = _future;
    if (future == null) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: strings.noResultsTitle,
        body: strings.onlineResultsFailed,
      );
    }
    return FutureBuilder<CombinedSearch>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<CombinedSearch> snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: LoadingRows(count: 6),
          );
        }
        final CombinedSearch result = snapshot.data!;
        final GroupedSearchResults? grouped = result.online;
        if (grouped == null) {
          return EmptyState(
            icon: Icons.search_off_outlined,
            title: strings.noResultsTitle,
            body: result.failure == OnlineFailure.network
                ? strings.searchNeedsInternet
                : strings.onlineResultsFailed,
            actionLabel: strings.retry,
            onAction: _retry,
          );
        }
        return _OnlineGroupList(
          grouped: grouped,
          group: widget.group,
          query: widget.query,
          port: port,
          snap: snap,
        );
      },
    );
  }
}

class _LocalSongsList extends StatelessWidget {
  const _LocalSongsList({
    required this.views,
    required this.query,
    required this.port,
    required this.snap,
  });

  final List<SongView> views;
  final String query;
  final AudioPlayerPort? port;
  final PlayerSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    if (views.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: strings.noResultsTitle,
        body: strings.searchNoResults(query),
      );
    }
    final AudioPlayerPort? port = this.port;
    return ListView.builder(
      itemCount: views.length,
      itemBuilder: (BuildContext context, int index) {
        final SongView view = views[index];
        final Track track = view.toTrack();
        final Track? current = snap.currentTrack;
        final bool isCurrent =
            current != null && current.videoId == track.videoId;
        return SongRow(
          title: view.song.title,
          subtitle: view.artistNames.isEmpty ? null : view.artistsLabel,
          artUri: track.artUri,
          duration: track.duration,
          isCurrent: isCurrent,
          isPlaying: isCurrent && snap.playing,
          onTap: port == null
              ? null
              : () => playSongViews(port, snap, views, index),
        );
      },
    );
  }
}

class _OnlineGroupList extends StatelessWidget {
  const _OnlineGroupList({
    required this.grouped,
    required this.group,
    required this.query,
    required this.port,
    required this.snap,
  });

  final GroupedSearchResults grouped;
  final SearchGroup group;
  final String query;
  final AudioPlayerPort? port;
  final PlayerSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    switch (group) {
      case SearchGroup.songs:
        final List<Track> tracks = grouped.songs
            .map((SearchSong s) => s.toTrack())
            .toList(growable: false);
        if (tracks.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_outlined,
            title: strings.noResultsTitle,
            body: strings.searchNoResults(query),
          );
        }
        final AudioPlayerPort? port = this.port;
        return ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (BuildContext context, int index) {
            final Track track = tracks[index];
            final Track? current = snap.currentTrack;
            final bool isCurrent =
                current != null && current.videoId == track.videoId;
            final bool busy =
                isCurrent &&
                (snap.status == PlayerStatus.loading ||
                    snap.status == PlayerStatus.buffering);
            return SongRow(
              title: track.title,
              subtitle: track.artist,
              artUri: track.artUri,
              duration: track.duration,
              isCurrent: isCurrent,
              isPlaying: isCurrent && snap.playing,
              isBusy: busy,
              onTap: port == null
                  ? null
                  : () => playTracks(port, snap, tracks, index),
              trailing: port == null
                  ? null
                  : RoundPlayButton(
                      isPlaying: isCurrent && snap.playing,
                      onPressed: () => playTracks(port, snap, tracks, index),
                    ),
            );
          },
        );
      case SearchGroup.albums:
        if (grouped.albums.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_outlined,
            title: strings.noResultsTitle,
            body: strings.searchNoResults(query),
          );
        }
        return ListView.builder(
          itemCount: grouped.albums.length,
          itemBuilder: (BuildContext context, int index) {
            final SearchAlbum album = grouped.albums[index];
            return BrowseResultRow(
              title: album.title,
              subtitle: album.displaySubtitle,
              artUri: album.thumbnailUrl == null
                  ? null
                  : Uri.tryParse(album.thumbnailUrl!),
              onTap: () => _openBrowse(
                context,
                album.browseId,
                album.title,
                album.displaySubtitle,
                album.thumbnailUrl,
              ),
            );
          },
        );
      case SearchGroup.artists:
        if (grouped.artists.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_outlined,
            title: strings.noResultsTitle,
            body: strings.searchNoResults(query),
          );
        }
        return ListView.builder(
          itemCount: grouped.artists.length,
          itemBuilder: (BuildContext context, int index) {
            final SearchArtist artist = grouped.artists[index];
            return BrowseResultRow(
              title: artist.name,
              subtitle: artist.subscribersText,
              artUri: artist.thumbnailUrl == null
                  ? null
                  : Uri.tryParse(artist.thumbnailUrl!),
              onTap: () => _openBrowse(
                context,
                artist.channelId,
                artist.name,
                artist.subscribersText,
                artist.thumbnailUrl,
              ),
            );
          },
        );
      case SearchGroup.playlists:
        if (grouped.playlists.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_outlined,
            title: strings.noResultsTitle,
            body: strings.searchNoResults(query),
          );
        }
        return ListView.builder(
          itemCount: grouped.playlists.length,
          itemBuilder: (BuildContext context, int index) {
            final SearchPlaylist playlist = grouped.playlists[index];
            return BrowseResultRow(
              title: playlist.title,
              subtitle: playlist.subtitle,
              artUri: playlist.thumbnailUrl == null
                  ? null
                  : Uri.tryParse(playlist.thumbnailUrl!),
              onTap: () => _openBrowse(
                context,
                playlist.browseId,
                playlist.title,
                playlist.subtitle,
                playlist.thumbnailUrl,
              ),
            );
          },
        );
      case SearchGroup.localSongs:
        return const SizedBox.shrink();
    }
  }
}

/// Buka halaman detail browse dari baris hasil.
void _openBrowse(
  BuildContext context,
  String browseId,
  String title,
  String? subtitle,
  String? thumbnailUrl,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => BrowseDetailScreen(
        browseId: browseId,
        title: title,
        subtitle: subtitle,
        artUri: thumbnailUrl == null ? null : Uri.tryParse(thumbnailUrl),
      ),
    ),
  );
}
