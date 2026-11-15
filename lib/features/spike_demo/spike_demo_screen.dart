/// Layar demo spike SEMENTARA - hapus sebelum v1.0.0.
///
/// Bukti ujung-ke-ujung untuk owner: daftar 5 lagu kanari, ketuk lagu
/// -> diputar lewat [AudioPlayerPort] yang sama dengan seluruh app
/// (bukan just_audio langsung), supaya uji perangkat owner menguji
/// player core yang sesungguhnya. Menampilkan status tiap lagu
/// (menyiapkan / diputar / dijeda / gagal) dan catatan percobaan
/// resolve (client yang dipakai + waktu, tanpa URL).
///
/// File ini + rute dari Beranda + string ARB `spikeDemo*` wajib dihapus
/// sebelum rilis v1.0.0.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player.dart';

/// Layar demo spike: 5 lagu kanari yang diputar lewat player nyata.
class SpikeDemoScreen extends StatelessWidget {
  const SpikeDemoScreen({super.key});

  static final List<Track> _tracks = kCanarySongs
      .map(
        (CanarySong s) => Track(
          videoId: s.videoId,
          title: s.title,
          duration: Duration(seconds: s.lengthSeconds),
        ),
      )
      .toList(growable: false);

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  Future<void> _onTapSong(
    BuildContext context,
    AudioPlayerPort port,
    PlayerSnapshot snap,
    int index,
  ) async {
    final Track tapped = _tracks[index];
    final Track? current = snap.currentTrack;
    if (current != null && current.videoId == tapped.videoId) {
      if (snap.playing) {
        await port.pause();
      } else {
        await port.play();
      }
      return;
    }
    await port.setQueue(_tracks, initialIndex: index, autoplay: true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final PlayerService? service = PlayerScope.maybeOf(context);
    if (service == null) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.spikeDemoTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              strings.songCannotPlay,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final AudioPlayerPort port = service.port;
    return Scaffold(
      appBar: AppBar(title: Text(strings.spikeDemoTitle)),
      body: StreamBuilder<PlayerSnapshot>(
        stream: port.stateStream,
        initialData: port.snapshot,
        builder: (BuildContext context, AsyncSnapshot<PlayerSnapshot> shot) {
          final PlayerSnapshot snap = shot.data ?? port.snapshot;
          final List<ResolveLogEntry> log = service.resolveLog;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.warning),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  strings.spikeDemoBanner,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ..._tracks.asMap().entries.map(
                (MapEntry<int, Track> entry) => _buildRow(
                  context,
                  port: port,
                  snap: snap,
                  index: entry.key,
                  track: entry.value,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                strings.spikeDemoLogTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (log.isEmpty)
                Text(
                  strings.spikeDemoLogEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                )
              else
                ...log.reversed.map(
                  (ResolveLogEntry entry) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      '[${entry.clientName}] ${entry.outcome} '
                      '(${entry.durationMs} ms)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required AudioPlayerPort port,
    required PlayerSnapshot snap,
    required int index,
    required Track track,
  }) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final Track? current = snap.currentTrack;
    final bool isCurrent =
        current != null && current.videoId == track.videoId;
    final bool busy =
        isCurrent &&
        (snap.status == PlayerStatus.loading ||
            snap.status == PlayerStatus.buffering);
    final bool playing = isCurrent && snap.playing;
    final bool paused =
        isCurrent && !snap.playing && snap.status == PlayerStatus.ready;
    final bool failed =
        isCurrent &&
        snap.status == PlayerStatus.error &&
        snap.lastError != null;
    final ResolveInfo? info = snap.lastResolve;
    final String? readyLine =
        playing && info != null && info.videoId == track.videoId
        ? '${strings.spikeDemoReadyIn((info.resolveDuration.inMilliseconds / 1000).toStringAsFixed(1))} · ${info.clientName}'
        : null;
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => _onTapSong(context, port, snap, index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 44,
                height: 44,
                child: busy
                    ? const CircularProgressIndicator()
                    : Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        color: playing
                            ? AppColors.success
                            : AppColors.textPrimary,
                        size: 32,
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(track.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _formatDuration(track.duration?.inSeconds ?? 0),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (busy)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          strings.spikeDemoResolving,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else if (playing)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          strings.spikeDemoPlaying,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      )
                    else if (paused)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          strings.spikeDemoPaused,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else if (failed)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          snap.lastError!.kind == PlaybackFailureKind.network
                              ? strings.noInternet
                              : strings.songCannotPlay,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    if (readyLine != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          readyLine,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
