/// Layar Player penuh (Rombak UI-2): sampul besar berbayang, judul
/// rata kiri dengan hati + unduh di kanan, pencari waktu, tombol
/// putar 72 dp, acak/ulangi dengan titik status, pengaturan suara,
/// dan antrean sebagai baris lagu (SongRow — sampul + judul + artis
/// + durasi + penanda lagu yang sedang berbunyi).
///
/// Satu-satunya sumber state adalah [AudioPlayerPort] yang disuntik.
/// Layar ini tidak menyimpan state pemutaran sendiri — hanya nilai drag
/// slider selama jari menyentuh slider.
library;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/album_cover.dart';
import 'package:laras/core/widgets/section_header.dart';
import 'package:laras/data/database.dart';
import 'package:laras/features/downloads/download_button.dart';
import 'package:laras/features/library/song_row.dart';
import 'package:laras/features/player/playback_error_banner.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/audio_player_port.dart';
import 'package:laras/player/player_state.dart';
import 'package:laras/player/track.dart';
import 'package:laras/resilience/check_updates_action.dart';
import 'package:laras/resilience/resilience_scope.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.port});

  final AudioPlayerPort port;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double? _dragValue;

  static String _format(Duration value) {
    final int total = value.inSeconds;
    final int minutes = total ~/ 60;
    final int seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _openSoundSheet() async {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final PlayerSnapshot snap = widget.port.snapshot;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return _SoundSheet(port: widget.port, initial: snap, strings: strings);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return StreamBuilder<PlayerSnapshot>(
      stream: widget.port.stateStream,
      initialData: widget.port.snapshot,
      builder: (BuildContext context, AsyncSnapshot<PlayerSnapshot> snapShot) {
        final PlayerSnapshot snap =
            snapShot.data ?? widget.port.snapshot;
        final Track? track = snap.currentTrack;
        final bool loading =
            snap.status == PlayerStatus.loading ||
            snap.status == PlayerStatus.buffering;
        final Duration duration = snap.duration ?? track?.duration ?? Duration.zero;
        final bool hasDuration = duration.inMilliseconds > 0;
        return Scaffold(
          appBar: AppBar(
            title: Text(strings.nowPlaying),
            centerTitle: true,
            // Panah bawah (bukan panah kembali): konvensi layar pemutar —
            // layar ini menutup ke bawah, kembali ke mini-player.
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: strings.close,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: track == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.music_note_outlined,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          strings.queueEmpty,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : StreamBuilder<Duration>(
                  stream: widget.port.positionStream,
                  initialData: widget.port.position,
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<Duration> posShot,
                      ) {
                        final Duration position =
                            posShot.data ?? widget.port.position;
                        final double sliderValue =
                            _dragValue ??
                            (hasDuration
                                ? position.inMilliseconds
                                          .clamp(0, duration.inMilliseconds)
                                          .toDouble()
                                : 0.0);
                        return ListView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          children: <Widget>[
                            if (snap.status == PlayerStatus.error &&
                                snap.lastError != null)
                              PlaybackErrorBanner(
                                failure: snap.lastError!,
                                onRetry: () => widget.port.play(),
                                onCheckUpdates:
                                    ResilienceScope.serviceStatusOf(context) ==
                                        null
                                    ? null
                                    : () => runCheckForUpdates(
                                        context,
                                        ResilienceScope.serviceStatusOf(
                                          context,
                                        )!,
                                      ),
                              ),
                            if (snap.reResolving)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        strings.retryingSong,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Sampul berganti dengan fade + skala kecil
                            // bila lagu berubah (kunci = videoId).
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 0.96,
                                          end: 1.0,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                              child: _Cover(
                                key: ValueKey<String>(track.videoId),
                                artUri: track.artUri,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        track.title,
                                        style: theme.textTheme.titleLarge,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (track.artist != null) ...<Widget>[
                                        const SizedBox(height: 4),
                                        Text(
                                          track.artist!,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                _FavoriteHeart(track: track),
                                DownloadButton(track: track),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: <Widget>[
                                Text(
                                  _format(
                                    Duration(
                                      milliseconds: sliderValue.round(),
                                    ),
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFeatures: const <FontFeature>[
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: hasDuration ? sliderValue : 0.0,
                                    max: hasDuration
                                        ? duration.inMilliseconds.toDouble()
                                        : 1.0,
                                    onChanged: hasDuration
                                        ? (double value) {
                                            setState(() {
                                              _dragValue = value;
                                            });
                                          }
                                        : null,
                                    onChangeEnd: (double value) {
                                      setState(() {
                                        _dragValue = null;
                                      });
                                      widget.port.seek(
                                        Duration(
                                          milliseconds: value.round(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Text(
                                  _format(duration),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFeatures: const <FontFeature>[
                                      FontFeature.tabularFigures(),
                                    ],
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                _ModeButton(
                                  active: snap.shuffleEnabled,
                                  icon: Icons.shuffle,
                                  tooltip: strings.shuffle,
                                  onPressed: () => widget.port.setShuffle(
                                    !snap.shuffleEnabled,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      widget.port.skipToPrevious(),
                                  tooltip: strings.previousSong,
                                  icon: const Icon(Icons.skip_previous),
                                  iconSize: 36,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: loading
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : FilledButton(
                                          onPressed: () {
                                            if (snap.playing) {
                                              widget.port.pause();
                                            } else {
                                              widget.port.play();
                                            }
                                          },
                                          style: FilledButton.styleFrom(
                                            shape: const CircleBorder(),
                                            padding: EdgeInsets.zero,
                                          ),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 150,
                                            ),
                                            child: Icon(
                                              snap.playing
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              key: ValueKey<bool>(
                                                snap.playing,
                                              ),
                                              size: 36,
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                IconButton(
                                  onPressed: () => widget.port.skipToNext(),
                                  tooltip: strings.nextSong,
                                  icon: const Icon(Icons.skip_next),
                                  iconSize: 36,
                                ),
                                _ModeButton(
                                  active: snap.repeatMode != RepeatMode.off,
                                  icon: snap.repeatMode == RepeatMode.one
                                      ? Icons.repeat_one
                                      : Icons.repeat,
                                  tooltip: switch (snap.repeatMode) {
                                    RepeatMode.off => strings.repeatOff,
                                    RepeatMode.all => strings.repeatAll,
                                    RepeatMode.one => strings.repeatOne,
                                  },
                                  onPressed: () {
                                    final RepeatMode next = switch (snap
                                        .repeatMode) {
                                      RepeatMode.off => RepeatMode.all,
                                      RepeatMode.all => RepeatMode.one,
                                      RepeatMode.one => RepeatMode.off,
                                    };
                                    widget.port.setRepeatMode(next);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Center(
                              child: TextButton.icon(
                                onPressed: _openSoundSheet,
                                icon: const Icon(Icons.tune),
                                label: Text(strings.soundSettings),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SectionHeader(title: strings.queue),
                            const SizedBox(height: AppSpacing.sm),
                            ...snap.queue.asMap().entries.map((entry) {
                              final int index = entry.key;
                              final Track item = entry.value;
                              final bool isCurrent =
                                  index == snap.currentIndex;
                              return SongRow(
                                title: item.title,
                                subtitle: item.artist,
                                artUri: item.artUri,
                                duration: item.duration,
                                isCurrent: isCurrent,
                                isPlaying: isCurrent && snap.playing,
                                // Sengaja false: spinner muat hanya ada
                                // di tombol putar utama — tes loading
                                // mengharapkan tepat satu spinner.
                                isBusy: false,
                                onTap: () =>
                                    widget.port.skipToIndex(index),
                              );
                            }),
                          ],
                        );
                      },
                ),
        );
      },
    );
  }
}

/// Tombol mode (acak / ulangi): ikon + titik putih 4 dp di bawahnya
/// saat mode aktif. Titik menandai state nyata, bukan dekorasi.
class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.active,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final bool active;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          color: active ? AppColors.accent : AppColors.textMuted,
          icon: Icon(icon),
        ),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// Sampul persegi layar penuh: radius 16 + bayangan lembut supaya
/// sampul terasa mengangkat dari kanvas hitam.
class _Cover extends StatelessWidget {
  const _Cover({super.key, this.artUri});

  final Uri? artUri;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.heroCard)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return AlbumCover(
              artUri: artUri,
              size: constraints.maxWidth,
              radius: AppRadius.heroCard,
              iconSize: 96,
              memCacheWidth: 720,
            );
          },
        ),
      ),
    );
  }
}

/// Tombol hati di kanan judul: menandai lagu yang sedang diputar
/// sebagai favorit (dan otomatis masuk Library).
///
/// Sembunyi total bila tidak ada LibraryService di atasnya (tes tanpa
/// database) — tidak ada tombol mati yang tampil.
class _FavoriteHeart extends StatelessWidget {
  const _FavoriteHeart({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final LibraryService? service = LibraryScope.maybeOf(context);
    if (service == null) return const SizedBox.shrink();
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return StreamBuilder<bool>(
      stream: service.watchIsLiked(track.videoId),
      initialData: false,
      builder: (BuildContext context, AsyncSnapshot<bool> shot) {
        final bool liked = shot.data ?? false;
        return IconButton(
          onPressed: () async {
            // Pastikan lagu dikenal database dulu (lagu dari beranda
            // belum tentu tersimpan), baru ubah status favoritnya.
            await service.upsertSong(
              track.toSongsCompanion(),
              artistNames: track.artistNames,
            );
            await service.toggleLiked(track.videoId);
          },
          tooltip: liked ? strings.favoriteRemove : strings.favoriteAdd,
          icon: Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            color: liked ? AppColors.accent : AppColors.textMuted,
          ),
          iconSize: 28,
        );
      },
    );
  }
}

class _SoundSheet extends StatefulWidget {
  const _SoundSheet({
    required this.port,
    required this.initial,
    required this.strings,
  });

  final AudioPlayerPort port;
  final PlayerSnapshot initial;
  final AppLocalizations strings;

  @override
  State<_SoundSheet> createState() => _SoundSheetState();
}

class _SoundSheetState extends State<_SoundSheet> {
  static const List<double> _speeds = <double>[
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
  ];

  late double _speed;
  late double _pitch;
  late bool _skipSilence;

  @override
  void initState() {
    super.initState();
    _speed = widget.initial.speed;
    _pitch = widget.initial.pitch;
    _skipSilence = widget.initial.skipSilence;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.strings.soundSettings, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.strings.playbackSpeed,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: _speeds.map((double speed) {
              final bool selected = _speed == speed;
              return ChoiceChip(
                label: Text('${speed}x'),
                selected: selected,
                onSelected: (_) {
                  setState(() => _speed = speed);
                  widget.port.setSpeed(speed);
                },
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(widget.strings.pitch, style: theme.textTheme.titleSmall),
          Row(
            children: <Widget>[
              Text('0.5x', style: theme.textTheme.bodySmall),
              Expanded(
                child: Slider(
                  value: _pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${_pitch.toStringAsFixed(1)}x',
                  onChanged: (double value) {
                    setState(() => _pitch = value);
                    widget.port.setPitch(value);
                  },
                ),
              ),
              Text('2.0x', style: theme.textTheme.bodySmall),
            ],
          ),
          SwitchListTile(
            title: Text(widget.strings.skipSilence),
            value: _skipSilence,
            onChanged: (bool value) {
              setState(() => _skipSilence = value);
              widget.port.setSkipSilence(value);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
