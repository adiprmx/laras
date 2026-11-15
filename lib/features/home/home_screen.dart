/// Beranda: lagu langsung terlihat dan langsung bisa diputar.
///
/// Lima lagu pilihan tampil sebagai daftar sungguhan (sampul, judul,
/// tombol putar) tanpa tombol perantara: mengetuk lagu memutarnya lewat
/// pemutar yang sama dengan seluruh app. Di bawahnya, bila library sudah
/// berisi lagu, tampil seksi lagu yang baru ditambahkan.
///
/// Lagu pilihan adalah lima lagu kanari P1 (satu-satunya lagu yang
/// tersedia sebelum pencarian online P4). Artisnya tidak ditampilkan
/// karena data kanari tidak membawa nama artis; menebak nama artis
/// dilarang. Sampul diambil dari thumbnail YouTube berdasarkan videoId
/// (pola URL publik yang sama dengan yang dikembalikan pemutar YouTube).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/loading_rows.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/library/play_helpers.dart';
import 'package:laras/features/library/song_row.dart';
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
        artUri: Uri.parse(
          'https://i.ytimg.com/vi/${s.videoId}/hqdefault.jpg',
        ),
      ),
    )
    .toList(growable: false);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LibraryService? _service;
  StreamSubscription<void>? _librarySub;
  Future<List<SongView>>? _recentsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LibraryService? service = LibraryScope.maybeOf(context);
    if (service != _service) {
      _librarySub?.cancel();
      _service = service;
      _recentsFuture = service?.songsPage(limit: 5);
      _librarySub = service?.libraryChanged.listen((_) {
        if (!mounted) return;
        setState(() {
          _recentsFuture = service.songsPage(limit: 5);
        });
      });
    }
  }

  @override
  void dispose() {
    _librarySub?.cancel();
    super.dispose();
  }

  /// Tombol putar kepala seksi: bila salah satu dari lima lagu sedang
  /// diputar, tombol ini menjeda/melanjutkan; bila tidak, memutar dari
  /// lagu pertama.
  Future<void> _playAll(AudioPlayerPort port, PlayerSnapshot snap) async {
    final Track? current = snap.currentTrack;
    if (current != null &&
        _tracks.any((Track t) => t.videoId == current.videoId)) {
      if (snap.playing) {
        await port.pause();
      } else {
        await port.play();
      }
      return;
    }
    await port.setQueue(_tracks, initialIndex: 0, autoplay: true);
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
                  (
                    BuildContext context,
                    AsyncSnapshot<PlayerSnapshot> shot,
                  ) {
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
    return SingleChildScrollView(
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
                if (port != null)
                  RoundPlayButton(
                    isPlaying:
                        snap.playing &&
                        snap.currentTrack != null &&
                        _tracks.any(
                          (Track t) => t.videoId == snap.currentTrack!.videoId,
                        ),
                    onPressed: () => _playAll(port, snap),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._tracks.asMap().entries.map((MapEntry<int, Track> entry) {
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: SongRow(
                title: track.title,
                artUri: track.artUri,
                duration: track.duration,
                isCurrent: isCurrent,
                isPlaying: playing,
                isBusy: busy,
                onTap: port == null
                    ? null
                    : () => playTracks(port, snap, _tracks, index),
                trailing: port == null
                    ? null
                    : RoundPlayButton(
                        isPlaying: playing,
                        onPressed: () => playTracks(port, snap, _tracks, index),
                      ),
              ),
            );
          }),
          _buildRecentsSection(context, strings, theme, port, snap),
        ],
      ),
    );
  }

  Widget _buildRecentsSection(
    BuildContext context,
    AppLocalizations strings,
    ThemeData theme,
    AudioPlayerPort? port,
    PlayerSnapshot snap,
  ) {
    final Future<List<SongView>>? future = _recentsFuture;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<List<SongView>>(
      future: future,
      builder:
          (BuildContext context, AsyncSnapshot<List<SongView>> shot) {
            final List<SongView>? recents = shot.data;
            if (shot.connectionState == ConnectionState.waiting &&
                recents == null) {
              return const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xl),
                child: LoadingRows(count: 3),
              );
            }
            if (recents == null || recents.isEmpty) {
              return const SizedBox.shrink();
            }
            final List<Track> tracks = recents
                .map((SongView v) => v.toTrack())
                .toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    strings.homeLibraryTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...recents.asMap().entries.map((MapEntry<int, SongView> entry) {
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: SongRow(
                      title: view.song.title,
                      subtitle: view.artistNames.isEmpty
                          ? null
                          : view.artistsLabel,
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
                              onPressed: () =>
                                  playTracks(port, snap, tracks, index),
                            ),
                    ),
                  );
                }),
              ],
            );
          },
    );
  }
}
