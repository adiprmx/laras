/// Beranda: tujuh seksi dari data nyata (P4 + P5).
///
/// 1. Lagu Pilihan — lima lagu kanari P1, selalu tampil dan langsung
///    bisa diputar (lagu yang terunduh diputar dari file lokal).
/// 2. Baru Ditambahkan — lagu terbaru di library.
/// 3. Baru diputar — lagu yang terakhir diputar, tanpa duplikat.
/// 4. Lagu favorit — lagu yang ditandai hati.
/// 5. Playlist kamu — playlist buatan pengguna.
/// 6. Unduhan (P5) — lagu terunduh, diputar offline; "Lihat semua"
///    membuka tab Unduhan.
/// 7. Jelajah — rak dari YouTube Music (butuh internet; gagal muat
///    menampilkan pesan, bukan data palsu).
///
/// Seksi lokal yang kosong tidak tampil. Tarik ke bawah memuat ulang
/// Jelajah dan seksi lokal.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/loading_rows.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/downloads/download_button.dart';
import 'package:laras/features/downloads/downloads_screen.dart';
import 'package:laras/features/library/play_helpers.dart';
import 'package:laras/features/library/playlist_detail_screen.dart';
import 'package:laras/features/library/song_row.dart';
import 'package:laras/features/player/playback_error_banner.dart';
import 'package:laras/features/search/browse_card.dart';
import 'package:laras/features/search/browse_detail_screen.dart';
import 'package:laras/features/search/search_scope.dart';
import 'package:laras/features/search/search_service.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player.dart';

/// Lima lagu pilihan beranda, dari data kanari P1.
List<Track> get homeTracks => _tracks;

final List<Track> _tracks = kCanarySongs
    .map(
      (CanarySong s) => Track(
        videoId: s.videoId,
        title: s.title,
        duration: Duration(seconds: s.lengthSeconds),
        artUri: Uri.parse('https://i.ytimg.com/vi/${s.videoId}/hqdefault.jpg'),
      ),
    )
    .toList(growable: false);

/// Batas lagu per seksi beranda (PRD B6.1: 10 per seksi).
const int kHomeSectionLimit = 10;

class _HomeLocalData {
  const _HomeLocalData({
    required this.recents,
    required this.recentPlayed,
    required this.favorites,
    required this.playlists,
    required this.downloads,
  });

  final List<SongView> recents;
  final List<SongView> recentPlayed;
  final List<SongView> favorites;
  final List<PlaylistWithCount> playlists;

  /// Lagu terunduh (P5): tampil di seksi "Unduhan", diputar dari file
  /// lokal tanpa jaringan.
  final List<SongView> downloads;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  LibraryService? _library;
  SearchService? _search;
  StreamSubscription<void>? _librarySub;
  Future<_HomeLocalData>? _localFuture;
  Future<BrowseOutcome>? _exploreFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari background: muat ulang Jelajah bila cache sudah basi
    // (PRD B6.4, TTL 6 jam). browseHome() tanpa forceRefresh memakai
    // cache bila masih segar, jadi panggilan ini murah.
    if (state == AppLifecycleState.resumed) {
      final SearchService? search = _search;
      if (search != null) {
        setState(() {
          _exploreFuture = search.browseHome();
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LibraryService? library = LibraryScope.maybeOf(context);
    if (library != _library) {
      _librarySub?.cancel();
      _library = library;
      _localFuture = library == null ? null : _loadLocal(library);
      _librarySub = library?.libraryChanged.listen((_) {
        if (!mounted) return;
        setState(() {
          _localFuture = _loadLocal(library);
        });
      });
    }
    final SearchService? search = SearchScope.maybeOf(context);
    if (search != _search) {
      _search = search;
      _exploreFuture = search?.browseHome();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _librarySub?.cancel();
    super.dispose();
  }

  Future<_HomeLocalData> _loadLocal(LibraryService library) async {
    final List<Object> results = await Future.wait(<Future<Object>>[
      library.songsPage(limit: kHomeSectionLimit),
      library.recentPlayedSongs(limit: kHomeSectionLimit),
      library.favoriteSongsPage(limit: kHomeSectionLimit),
      library.playlistsPage(limit: kHomeSectionLimit),
      library.downloadedSongs(limit: kHomeSectionLimit),
    ]);
    return _HomeLocalData(
      recents: results[0] as List<SongView>,
      recentPlayed: results[1] as List<SongView>,
      favorites: results[2] as List<SongView>,
      playlists: results[3] as List<PlaylistWithCount>,
      downloads: results[4] as List<SongView>,
    );
  }

  Future<void> _refresh() async {
    final LibraryService? library = _library;
    final SearchService? search = _search;
    setState(() {
      _localFuture = library == null ? null : _loadLocal(library);
      _exploreFuture = search?.browseHome(forceRefresh: true);
    });
    await Future.wait(<Future<Object?>>[?_localFuture, ?_exploreFuture]);
  }

  /// Tombol putar kepala seksi: bila salah satu dari lima lagu sedang
  /// diputar, tombol ini menjeda/melanjutkan; bila tidak, memutar dari
  /// lagu pertama. [tracks] adalah daftar yang sadar-unduhan (lagu
  /// terunduh membawa localPath).
  Future<void> _playAll(
    AudioPlayerPort port,
    PlayerSnapshot snap,
    List<Track> tracks,
  ) async {
    final Track? current = snap.currentTrack;
    if (current != null &&
        tracks.any((Track t) => t.videoId == current.videoId)) {
      if (snap.playing) {
        await port.pause();
      } else {
        await port.play();
      }
      return;
    }
    await port.setQueue(tracks, initialIndex: 0, autoplay: true);
  }

  void _retryExplore() {
    final SearchService? search = _search;
    if (search == null) return;
    setState(() {
      _exploreFuture = search.browseHome(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final PlayerService? service = PlayerScope.maybeOf(context);
    final AudioPlayerPort? port = service?.port;
    return SafeArea(
      child: port == null
          ? _buildBody(context, strings, theme, null, PlayerSnapshot.idle)
          : StreamBuilder<PlayerSnapshot>(
              stream: port.stateStream,
              initialData: port.snapshot,
              builder:
                  (BuildContext context, AsyncSnapshot<PlayerSnapshot> shot) {
                    return _buildBody(
                      context,
                      strings,
                      theme,
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
    ThemeData theme,
    AudioPlayerPort? port,
    PlayerSnapshot snap,
  ) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: Text(strings.tabHome, style: theme.textTheme.displayLarge),
            ),
            const SizedBox(height: AppSpacing.lg),
            _CanarySectionHost(
              port: port,
              snap: snap,
              onPlayAll: _playAll,
            ),
            _LocalSections(future: _localFuture, port: port, snap: snap),
            _ExploreSection(future: _exploreFuture, onRetry: _retryExplore),
          ],
        ),
      ),
    );
  }
}

/// Pembungkus seksi Lagu Pilihan (P5): membangun daftar lagu yang
/// sadar-unduhan dari snapshot unduhan — lagu kanari yang terunduh
/// diganti dengan Track ber-localPath supaya diputar dari file lokal
/// (offline), bukan dari jaringan.
class _CanarySectionHost extends StatelessWidget {
  const _CanarySectionHost({
    required this.port,
    required this.snap,
    required this.onPlayAll,
  });

  final AudioPlayerPort? port;
  final PlayerSnapshot snap;
  final Future<void> Function(
    AudioPlayerPort port,
    PlayerSnapshot snap,
    List<Track> tracks,
  )
  onPlayAll;

  @override
  Widget build(BuildContext context) {
    final DownloadService? downloads = DownloadsScope.downloadsOf(context);
    final AudioPlayerPort? port = this.port;
    if (port == null) {
      return _CanarySection(
        port: port,
        snap: snap,
        tracks: _tracks,
        onPlayAll: null,
      );
    }
    if (downloads == null) {
      // Tanpa layanan unduhan (database gagal / tes tanpa layanan):
      // tombol putar kepala seksi tetap ada, memakai daftar kanari
      // apa adanya (tidak ada lagu terunduh yang perlu localPath).
      return _CanarySection(
        port: port,
        snap: snap,
        tracks: _tracks,
        onPlayAll: () => onPlayAll(port, snap, _tracks),
      );
    }
    return StreamBuilder<DownloadsSnapshot>(
      stream: downloads.stateStream,
      // Snapshot terakhir sebagai data awal (stream broadcast tidak
      // mengulang emisi lama untuk pendengar baru).
      initialData: downloads.currentSnapshot,
      builder:
          (BuildContext context, AsyncSnapshot<DownloadsSnapshot> shot) {
            final List<Track> effective = _localAwareTracks(
              downloads,
              shot.data,
            );
            return _CanarySection(
              port: port,
              snap: snap,
              tracks: effective,
              onPlayAll: () => onPlayAll(port, snap, effective),
            );
          },
    );
  }
}

/// Ganti lagu kanari yang terunduh dengan Track ber-localPath.
List<Track> _localAwareTracks(
  DownloadService downloads,
  DownloadsSnapshot? snapshot,
) {
  if (snapshot == null) return _tracks;
  final Map<String, SongView> byId = <String, SongView>{
    for (final SongView view in snapshot.downloaded) view.id: view,
  };
  return _tracks.map((Track track) {
    final SongView? view = byId[track.videoId];
    if (view == null) return track;
    return downloads.trackFor(view);
  }).toList(growable: false);
}

/// Seksi 1: lima lagu pilihan (kanari), selalu tampil.
class _CanarySection extends StatelessWidget {
  const _CanarySection({
    required this.port,
    required this.snap,
    required this.tracks,
    this.onPlayAll,
  });

  final AudioPlayerPort? port;
  final PlayerSnapshot snap;

  /// Daftar lagu yang sadar-unduhan (lihat [_CanarySectionHost]).
  final List<Track> tracks;
  final VoidCallback? onPlayAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final AudioPlayerPort? port = this.port;
    final VoidCallback? onPlayAll = this.onPlayAll;
    // Banner error (P0): bila lagu yang gagal adalah salah satu dari lima
    // lagu pilihan, penyebabnya ditampilkan di sini (bukan hanya di Player
    // layar penuh) supaya pengguna langsung tahu kenapa tidak ada bunyi.
    final bool showError =
        port != null &&
        snap.status == PlayerStatus.error &&
        snap.lastError != null &&
        snap.currentTrack != null &&
        tracks.any(
          (Track t) => t.videoId == snap.currentTrack!.videoId,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.homeSongsTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      strings.homeSongsHint,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (port != null && onPlayAll != null)
                RoundPlayButton(
                  isPlaying:
                      snap.playing &&
                      snap.currentTrack != null &&
                      tracks.any(
                        (Track t) => t.videoId == snap.currentTrack!.videoId,
                      ),
                  onPressed: onPlayAll,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (showError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: PlaybackErrorBanner(
              failure: snap.lastError!,
              onRetry: () => port.play(),
            ),
          ),
        ...tracks.asMap().entries.map((MapEntry<int, Track> entry) {
          final int index = entry.key;
          final Track track = entry.value;
          final Track? current = snap.currentTrack;
          final bool isCurrent =
              current != null && current.videoId == track.videoId;
          final bool busy =
              isCurrent &&
              (snap.status == PlayerStatus.loading ||
                  snap.status == PlayerStatus.buffering);
          final bool playing = isCurrent && snap.playing;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SongRow(
              title: track.title,
              artUri: track.artUri,
              duration: track.duration,
              isCurrent: isCurrent,
              isPlaying: playing,
              isBusy: busy,
              onTap: port == null
                  ? null
                  : () => playTracks(port, snap, tracks, index),
              trailing: port == null
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        DownloadButton(track: track),
                        RoundPlayButton(
                          isPlaying: playing,
                          onPressed: () =>
                              playTracks(port, snap, tracks, index),
                        ),
                      ],
                    ),
            ),
          );
        }),
      ],
    );
  }
}

/// Seksi 2–5: dari database lokal. Seksi kosong tidak tampil.
class _LocalSections extends StatelessWidget {
  const _LocalSections({
    required this.future,
    required this.port,
    required this.snap,
  });

  final Future<_HomeLocalData>? future;
  final AudioPlayerPort? port;
  final PlayerSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final Future<_HomeLocalData>? future = this.future;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<_HomeLocalData>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<_HomeLocalData> shot) {
        final _HomeLocalData? data = shot.data;
        if (shot.connectionState == ConnectionState.waiting && data == null) {
          return const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xl),
            child: LoadingRows(count: 3),
          );
        }
        if (data == null) return const SizedBox.shrink();
        final AppLocalizations strings = AppLocalizations.of(context)!;
        final String? downloadsDir = DownloadsScope.downloadsDirOf(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (data.recents.isNotEmpty)
              _SongSection(
                title: strings.homeLibraryTitle,
                views: data.recents,
                port: port,
                snap: snap,
                downloadsDir: downloadsDir,
              ),
            if (data.recentPlayed.isNotEmpty)
              _SongSection(
                title: strings.sectionRecent,
                views: data.recentPlayed,
                port: port,
                snap: snap,
                downloadsDir: downloadsDir,
              ),
            if (data.favorites.isNotEmpty)
              _SongSection(
                title: strings.favorites,
                views: data.favorites,
                port: port,
                snap: snap,
                downloadsDir: downloadsDir,
              ),
            if (data.playlists.isNotEmpty)
              _PlaylistsSection(playlists: data.playlists),
            if (data.downloads.isNotEmpty)
              _SongSection(
                title: strings.sectionDownloads,
                views: data.downloads,
                port: port,
                snap: snap,
                downloadsDir: downloadsDir,
                onSeeAll: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const DownloadsScreen(),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// Satu seksi lagu lokal (Baru Ditambahkan / Baru diputar / Favorit /
/// Unduhan). Lagu terunduh diputar dari file lokal via [downloadsDir].
class _SongSection extends StatelessWidget {
  const _SongSection({
    required this.title,
    required this.views,
    required this.port,
    required this.snap,
    required this.downloadsDir,
    this.onSeeAll,
  });

  final String title;
  final List<SongView> views;
  final AudioPlayerPort? port;
  final PlayerSnapshot snap;
  final String? downloadsDir;

  /// Bila ada, judul seksi mendapat tombol "Lihat semua".
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AudioPlayerPort? port = this.port;
    final VoidCallback? onSeeAll = this.onSeeAll;
    final List<Track> tracks = views
        .map((SongView v) => v.toTrack(downloadsDir: downloadsDir))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: onSeeAll == null
              ? Text(title, style: theme.textTheme.titleMedium)
              : Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    TextButton(
                      onPressed: onSeeAll,
                      child: Text(
                        AppLocalizations.of(context)!.seeAll,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...views.asMap().entries.map((MapEntry<int, SongView> entry) {
          final int index = entry.key;
          final SongView view = entry.value;
          final Track track = tracks[index];
          final Track? current = snap.currentTrack;
          final bool isCurrent =
              current != null && current.videoId == track.videoId;
          final bool busy =
              isCurrent &&
              (snap.status == PlayerStatus.loading ||
                  snap.status == PlayerStatus.buffering);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SongRow(
              title: view.song.title,
              subtitle: view.artistNames.isEmpty ? null : view.artistsLabel,
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
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        DownloadButton(track: track),
                        RoundPlayButton(
                          isPlaying: isCurrent && snap.playing,
                          onPressed: () =>
                              playTracks(port, snap, tracks, index),
                        ),
                      ],
                    ),
            ),
          );
        }),
      ],
    );
  }
}

/// Seksi 5: playlist buatan pengguna.
class _PlaylistsSection extends StatelessWidget {
  const _PlaylistsSection({required this.playlists});

  final List<PlaylistWithCount> playlists;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            strings.sectionYourPlaylists,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final PlaylistWithCount item in playlists)
          ListTile(
            leading: Container(
              width: AppSizes.touchTarget,
              height: AppSizes.touchTarget,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.coverSmall),
              ),
              child: const Icon(
                Icons.queue_music_outlined,
                color: AppColors.textMuted,
              ),
            ),
            title: Text(
              item.playlist.name,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(strings.playlistSongsCount(item.songCount)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      PlaylistDetailScreen(playlistId: item.playlist.id),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Seksi 6: Jelajah dari YouTube Music.
///
/// Memuat: skeleton 3 baris. Gagal: pesan sesuai penyebab (offline tanpa
/// tombol coba lagi, PRD B6.3; gagal lain dengan tombol coba lagi).
/// Sukses: rak kartu horizontal + baris "Mood dan genre".
class _ExploreSection extends StatelessWidget {
  const _ExploreSection({required this.future, required this.onRetry});

  final Future<BrowseOutcome>? future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Future<BrowseOutcome>? future = this.future;
    if (future == null) return const SizedBox.shrink();
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return FutureBuilder<BrowseOutcome>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<BrowseOutcome> shot) {
        final BrowseOutcome? outcome = shot.data;
        final bool waiting =
            shot.connectionState == ConnectionState.waiting && outcome == null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                strings.sectionExplore,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (waiting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: LoadingRows(count: 3),
              )
            else if (outcome == null || outcome.page == null)
              _ExploreFailure(failure: outcome?.failure, onRetry: onRetry)
            else ...<Widget>[
              if (outcome.fromCache && outcome.failure != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    strings.refreshFailed,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              for (final BrowseShelf shelf in outcome.page!.shelves)
                if (shelf.items.isNotEmpty) _ExploreShelf(shelf: shelf),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: ListTile(
                  leading: Container(
                    width: AppSizes.touchTarget,
                    height: AppSizes.touchTarget,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.coverSmall),
                    ),
                    child: const Icon(
                      Icons.explore_outlined,
                      color: AppColors.textMuted,
                    ),
                  ),
                  title: Text(
                    strings.moodsAndGenres,
                    style: theme.textTheme.titleSmall,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => BrowseDetailScreen(
                          browseId: kBrowseMoodsId,
                          title: strings.moodsAndGenres,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ExploreFailure extends StatelessWidget {
  const _ExploreFailure({required this.failure, required this.onRetry});

  final OnlineFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final String message = switch (failure) {
      OnlineFailure.network => strings.exploreNeedsInternet,
      OnlineFailure.parse => strings.exploreFailedParse,
      OnlineFailure.server || null => strings.exploreFailedHttp,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message, style: theme.textTheme.bodyMedium),
            // Saat offline tidak ada tombol coba lagi (PRD B6.3):
            // tombol itu tidak akan berhasil sebelum internet kembali.
            if (failure != OnlineFailure.network) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              TextButton(onPressed: onRetry, child: Text(strings.retry)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Satu rak Jelajah: judul + deretan kartu horizontal.
class _ExploreShelf extends StatelessWidget {
  const _ExploreShelf({required this.shelf});

  final BrowseShelf shelf;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(shelf.title, style: theme.textTheme.titleMedium),
        ),
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
                onTap: item.browseId == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                BrowseDetailScreen(
                                  browseId: item.browseId!,
                                  params: item.browseParams,
                                  title: item.title,
                                  subtitle: item.subtitle,
                                  artUri: item.thumbnailUrl == null
                                      ? null
                                      : Uri.tryParse(item.thumbnailUrl!),
                                ),
                          ),
                        );
                      },
              );
            },
          ),
        ),
      ],
    );
  }
}
