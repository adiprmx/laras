/// Halaman detail browse: artis, album, playlist, atau kategori YTM.
///
/// Dibuka dari hasil pencarian, kartu Jelajah, dan kartu di halaman
/// browse lain (rekursif). Menampilkan header (sampul, judul, keterangan)
/// + rak: rak lagu bisa langsung diputar, rak kartu bisa diketuk membuka
/// halaman detail berikutnya.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/album_cover.dart';
import 'package:laras/core/widgets/empty_state.dart';
import 'package:laras/core/widgets/loading_rows.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/library/play_helpers.dart';
import 'package:laras/features/library/song_row.dart';
import 'package:laras/features/search/browse_card.dart';
import 'package:laras/features/search/search_scope.dart';
import 'package:laras/features/search/search_service.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player.dart';

class BrowseDetailScreen extends StatefulWidget {
  const BrowseDetailScreen({
    super.key,
    required this.browseId,
    required this.title,
    this.params,
    this.subtitle,
    this.artUri,
  });

  /// browseId halaman (channelId artis, MPRE album, VLPL playlist, atau
  /// FEmusic_* untuk halaman kategori).
  final String browseId;

  /// Judul sementara selagi memuat (dari kartu yang diketuk).
  final String title;
  final String? params;
  final String? subtitle;
  final Uri? artUri;

  @override
  State<BrowseDetailScreen> createState() => _BrowseDetailScreenState();
}

class _BrowseDetailScreenState extends State<BrowseDetailScreen> {
  Future<BrowseOutcome>? _future;
  SearchService? _service;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final SearchService? service = SearchScope.maybeOf(context);
    if (service != _service) {
      _service = service;
      _future = service?.browse(widget.browseId, params: widget.params);
    }
  }

  void _retry() {
    final SearchService? service = _service;
    if (service == null) return;
    setState(() {
      _future = service.browse(widget.browseId, params: widget.params);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final PlayerService? service = PlayerScope.maybeOf(context);
    final AudioPlayerPort? port = service?.port;
    final Future<BrowseOutcome>? future = _future;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: port == null
          ? _buildBody(context, strings, future, null, PlayerSnapshot.idle)
          : StreamBuilder<PlayerSnapshot>(
              stream: port.stateStream,
              initialData: port.snapshot,
              builder:
                  (BuildContext context, AsyncSnapshot<PlayerSnapshot> shot) {
                    return _buildBody(
                      context,
                      strings,
                      future,
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
    Future<BrowseOutcome>? future,
    AudioPlayerPort? port,
    PlayerSnapshot snap,
  ) {
    if (future == null) {
      return EmptyState(
        icon: Icons.explore_outlined,
        title: strings.browseFailedTitle,
        body: strings.exploreFailedHttp,
      );
    }
    return FutureBuilder<BrowseOutcome>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<BrowseOutcome> snapshot) {
        // R2-L1: future yang error tidak pernah punya data — tanpa
        // cabang ini, layar menampilkan shimmer selamanya.
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.explore_outlined,
            title: strings.browseFailedTitle,
            body: strings.exploreFailedHttp,
            actionLabel: strings.retry,
            onAction: _retry,
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: LoadingRows(count: 6),
          );
        }
        final BrowseOutcome outcome = snapshot.data!;
        final BrowsePage? page = outcome.page;
        if (page == null) {
          return EmptyState(
            icon: Icons.explore_outlined,
            title: strings.browseFailedTitle,
            body: _failureBody(strings, outcome.failure),
            actionLabel: strings.retry,
            onAction: _retry,
          );
        }
        return _BrowseDetailBody(
          page: page,
          fallbackTitle: widget.title,
          fallbackSubtitle: widget.subtitle,
          fallbackArtUri: widget.artUri,
          port: port,
          snap: snap,
        );
      },
    );
  }

  String _failureBody(AppLocalizations strings, OnlineFailure? failure) {
    switch (failure) {
      case OnlineFailure.network:
        return strings.exploreNeedsInternet;
      case OnlineFailure.parse:
        return strings.exploreFailedParse;
      case OnlineFailure.server:
      case null:
        return strings.exploreFailedHttp;
    }
  }
}

class _BrowseDetailBody extends StatelessWidget {
  const _BrowseDetailBody({
    required this.page,
    required this.fallbackTitle,
    required this.port,
    required this.snap,
    this.fallbackSubtitle,
    this.fallbackArtUri,
  });

  final BrowsePage page;
  final String fallbackTitle;
  final String? fallbackSubtitle;
  final Uri? fallbackArtUri;
  final AudioPlayerPort? port;
  final PlayerSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final String title = page.title.isEmpty ? fallbackTitle : page.title;
    final String? subtitle = page.subtitle ?? fallbackSubtitle;
    final Uri? artUri = page.thumbnailUrl == null
        ? fallbackArtUri
        : Uri.tryParse(page.thumbnailUrl!);
    final List<Track> allSongs = <Track>[
      for (final BrowseItem item in page.allSongs)
        if (item.videoId != null) item.toTrack(),
    ];
    final AudioPlayerPort? port = this.port;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AlbumCover(
                artUri: artUri,
                size: 96,
                radius: AppRadius.coverLarge,
                memCacheWidth: 192,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (allSongs.isNotEmpty && port != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: () => playTracks(port, snap, allSongs, 0),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(strings.playAll),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (page.isEmpty)
          EmptyState(
            icon: Icons.music_note_outlined,
            title: strings.noSongsInBrowse,
            body: strings.browseEmptyBody,
          )
        else
          for (final BrowseShelf shelf in page.shelves)
            _BrowseShelfSection(shelf: shelf, port: port, snap: snap),
      ],
    );
  }
}

class _BrowseShelfSection extends StatelessWidget {
  const _BrowseShelfSection({
    required this.shelf,
    required this.port,
    required this.snap,
  });

  final BrowseShelf shelf;
  final AudioPlayerPort? port;
  final PlayerSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (shelf.items.isEmpty) return const SizedBox.shrink();
    final Widget header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(shelf.title, style: theme.textTheme.titleLarge),
    );
    if (shelf.isSongList) {
      final List<Track> tracks = <Track>[
        for (final BrowseItem item in shelf.items)
          if (item.videoId != null) item.toTrack(),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          header,
          for (final BrowseItem item in shelf.items)
            _SongShelfRow(item: item, tracks: tracks, port: port, snap: snap),
        ],
      );
    }
    if (shelf.items.every(
      (BrowseItem i) => i.kind == BrowseItemKind.category,
    )) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          header,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                // Item tanpa browseId disembunyikan, bukan ditampilkan
                // sebagai chip mati (K-F2-09).
                for (final BrowseItem item in shelf.items)
                  if (item.browseId != null)
                    ActionChip(
                      label: Text(item.title),
                      onPressed: () => _openDetail(context, item),
                    ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        header,
        SizedBox(
          // 140 sampul + 8 jarak + judul 2 baris + 2 jarak + keterangan.
          height: 216,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: shelf.items.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final BrowseItem item = shelf.items[index];
              return BrowseCard(
                title: item.title,
                subtitle: item.subtitle,
                artUri: item.thumbnailUrl == null
                    ? null
                    : Uri.tryParse(item.thumbnailUrl!),
                onTap: () => _openItem(context, item),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openItem(BuildContext context, BrowseItem item) {
    final AudioPlayerPort? port = this.port;
    if (item.videoId != null &&
        item.kind == BrowseItemKind.song &&
        port != null) {
      playTracks(port, snap, <Track>[item.toTrack()], 0);
      return;
    }
    _openDetail(context, item);
  }

  void _openDetail(BuildContext context, BrowseItem item) {
    final String? browseId = item.browseId;
    if (browseId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => BrowseDetailScreen(
          browseId: browseId,
          params: item.browseParams,
          title: item.title,
          subtitle: item.subtitle,
          artUri: item.thumbnailUrl == null
              ? null
              : Uri.tryParse(item.thumbnailUrl!),
        ),
      ),
    );
  }
}

/// Satu baris lagu di rak lagu halaman browse.
class _SongShelfRow extends StatelessWidget {
  const _SongShelfRow({
    required this.item,
    required this.tracks,
    required this.port,
    required this.snap,
  });

  final BrowseItem item;
  final List<Track> tracks;
  final AudioPlayerPort? port;
  final PlayerSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final Track track = item.toTrack();
    final Track? current = snap.currentTrack;
    final bool isCurrent = current != null && current.videoId == track.videoId;
    final bool busy =
        isCurrent &&
        (snap.status == PlayerStatus.loading ||
            snap.status == PlayerStatus.buffering);
    final AudioPlayerPort? port = this.port;
    final int startIndex = tracks.indexWhere(
      (Track t) => t.videoId == track.videoId,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SongRow(
        title: track.title,
        subtitle: track.artist,
        artUri: track.artUri,
        duration: track.duration,
        isCurrent: isCurrent,
        isPlaying: isCurrent && snap.playing,
        isBusy: busy,
        onTap: port == null || startIndex < 0
            ? null
            : () => playTracks(port, snap, tracks, startIndex),
        trailing: port == null || startIndex < 0
            ? null
            : RoundPlayButton(
                isPlaying: isCurrent && snap.playing,
                onPressed: () => playTracks(port, snap, tracks, startIndex),
              ),
      ),
    );
  }
}
