import 'package:flutter/material.dart' hide RepeatMode;
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/album_cover.dart';
import 'package:laras/data/database.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/audio_player_port.dart';
import 'package:laras/player/player_state.dart';
import 'package:laras/player/track.dart';

/// Layar Player penuh: sampul, judul, pencari waktu, tombol putar,
/// acak, ulangi, pengaturan suara, dan antrean.
///
/// Satu-satunya sumber state adalah [AudioPlayerPort] yang disuntik.
/// Layar ini tidak menyimpan state pemutaran sendiri — hanya nilai drag
/// slider selama jari menyentuh slider.
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
          appBar: AppBar(title: Text(strings.nowPlaying)),
          body: track == null
              ? Center(
                  child: Text(
                    strings.queueEmpty,
                    style: theme.textTheme.bodyMedium,
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
                              _ErrorBanner(
                                failure: snap.lastError!,
                                onRetry: () => widget.port.play(),
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
                            _Cover(artUri: track.artUri),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              track.title,
                              style: theme.textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            if (track.artist != null) ...<Widget>[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                track.artist!,
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xs),
                            Center(child: _FavoriteHeart(track: track)),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: <Widget>[
                                Text(
                                  _format(
                                    Duration(
                                      milliseconds: sliderValue.round(),
                                    ),
                                  ),
                                  style: theme.textTheme.bodySmall,
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
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                IconButton(
                                  onPressed: () => widget.port.setShuffle(
                                    !snap.shuffleEnabled,
                                  ),
                                  tooltip: strings.shuffle,
                                  color: snap.shuffleEnabled
                                      ? AppColors.accent
                                      : AppColors.textMuted,
                                  icon: const Icon(Icons.shuffle),
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
                                          child: Icon(
                                            snap.playing
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            size: 36,
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
                                IconButton(
                                  onPressed: () {
                                    final RepeatMode next = switch (snap
                                        .repeatMode) {
                                      RepeatMode.off => RepeatMode.all,
                                      RepeatMode.all => RepeatMode.one,
                                      RepeatMode.one => RepeatMode.off,
                                    };
                                    widget.port.setRepeatMode(next);
                                  },
                                  tooltip: switch (snap.repeatMode) {
                                    RepeatMode.off => strings.repeatOff,
                                    RepeatMode.all => strings.repeatAll,
                                    RepeatMode.one => strings.repeatOne,
                                  },
                                  color: snap.repeatMode == RepeatMode.off
                                      ? AppColors.textMuted
                                      : AppColors.accent,
                                  icon: Icon(
                                    snap.repeatMode == RepeatMode.one
                                        ? Icons.repeat_one
                                        : Icons.repeat,
                                  ),
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
                            Text(
                              strings.queue,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ...snap.queue.asMap().entries.map((entry) {
                              final int index = entry.key;
                              final Track item = entry.value;
                              final bool isCurrent =
                                  index == snap.currentIndex;
                              return ListTile(
                                leading: isCurrent
                                    ? const Icon(
                                        Icons.equalizer,
                                        color: AppColors.accent,
                                      )
                                    : Text('${index + 1}'),
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: isCurrent
                                      ? theme.textTheme.titleSmall?.copyWith(
                                          color: AppColors.accent,
                                        )
                                      : theme.textTheme.titleSmall,
                                ),
                                subtitle: item.artist == null
                                    ? null
                                    : Text(
                                        item.artist!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                trailing: item.duration == null
                                    ? null
                                    : Text(_format(item.duration!)),
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

class _Cover extends StatelessWidget {
  const _Cover({this.artUri});

  final Uri? artUri;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return AlbumCover(
            artUri: artUri,
            size: constraints.maxWidth,
            radius: AppRadius.card,
            iconSize: 96,
            memCacheWidth: 720,
          );
        },
      ),
    );
  }
}

/// Tombol hati di bawah judul: menandai lagu yang sedang diputar
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.failure, required this.onRetry});

  final PlaybackFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final String message = failure.kind == PlaybackFailureKind.network
        ? strings.noInternet
        : strings.songCannotPlay;
    final String text = failure.skippedCount > 0
        ? '$message ${strings.skippedUnplayable(failure.skippedCount)}'
        : message;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
          TextButton(onPressed: onRetry, child: Text(strings.retry)),
        ],
      ),
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
