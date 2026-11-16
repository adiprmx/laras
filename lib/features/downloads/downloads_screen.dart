/// Tab Unduhan (P5): antrean unduhan, progress, dan lagu terunduh.
///
/// Kelompok tampil hanya bila berisi (PRD B3.2): Mengunduh, Menunggu,
/// Selesai (lagu terunduh, bisa diputar offline), Gagal. Job yang dijeda
/// tampil di kelompok Menunggu dengan status "Dijeda".
///
/// State: loading skeleton saat snapshot pertama belum tiba; empty state
/// jujur saat tidak ada job dan tidak ada unduhan; pesan jujur bila
/// database tidak tersedia. Tab ini bekerja penuh saat offline (semua
/// datanya lokal).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/empty_state.dart';
import 'package:laras/core/widgets/loading_rows.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/features/library/play_helpers.dart';
import 'package:laras/features/library/song_row.dart';
import 'package:laras/features/storage/storage_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  DownloadService? _downloads;
  StreamSubscription<String>? _completedSub;
  StreamSubscription<String>? _failedSub;
  bool _reconcileChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final DownloadService? downloads = DownloadsScope.downloadsOf(context);
    if (downloads != _downloads) {
      _completedSub?.cancel();
      _failedSub?.cancel();
      _downloads = downloads;
      if (downloads != null) {
        _completedSub = downloads.completedStream.listen((String _) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.downloadDone,
              ),
            ),
          );
        });
        _failedSub = downloads.failedStream.listen((String _) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.downloadFailed,
              ),
            ),
          );
        });
      }
    }
    if (!_reconcileChecked) {
      _reconcileChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final DownloadService? service = _downloads;
        final ReconcileResult? result = service?.lastReconcile;
        if (!mounted || service == null || result == null) return;
        if (service.reconcileNotified) return;
        service.reconcileNotified = true;
        if (result.missingDownloads <= 0) return;
        final AppLocalizations strings = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.missingDownloads == 1
                  ? strings.dlMissingDownloadOne
                  : strings.dlMissingDownloads(result.missingDownloads),
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _completedSub?.cancel();
    _failedSub?.cancel();
    super.dispose();
  }

  void _openStorage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const StorageScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final DownloadService? downloads = _downloads;
    final LibraryService? library = LibraryScope.maybeOf(context);
    final PlayerService? service = PlayerScope.maybeOf(context);
    final AudioPlayerPort? port = service?.port;
    return SafeArea(
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
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    strings.tabDownloads,
                    style: theme.textTheme.displayLarge,
                  ),
                ),
                TextButton(
                  onPressed: _openStorage,
                  child: Text(strings.manageStorage),
                ),
              ],
            ),
          ),
          if (downloads == null || library == null)
            Expanded(
              child: EmptyState(
                icon: Icons.download_outlined,
                title: strings.libraryFailed,
                body: strings.downloadsEmptyBody,
              ),
            )
          else if (port == null)
            Expanded(
              child: _DownloadsBody(
                downloads: downloads,
                port: null,
                snap: PlayerSnapshot.idle,
              ),
            )
          else
            Expanded(
              child: StreamBuilder<PlayerSnapshot>(
                stream: port.stateStream,
                initialData: port.snapshot,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<PlayerSnapshot> shot,
                    ) {
                      return _DownloadsBody(
                        downloads: downloads,
                        port: port,
                        snap: shot.data ?? port.snapshot,
                      );
                    },
              ),
            ),
        ],
      ),
    );
  }
}

/// Isi tab: snapshot job + lagu terunduh.
class _DownloadsBody extends StatelessWidget {
  const _DownloadsBody({
    required this.downloads,
    required this.port,
    required this.snap,
  });

  final DownloadService downloads;
  final AudioPlayerPort? port;
  final PlayerSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return StreamBuilder<DownloadsSnapshot>(
      stream: downloads.stateStream,
      // Snapshot terakhir sebagai data awal: stream broadcast tidak
      // mengulang emisi lama untuk pendengar baru (lihat stateStream).
      initialData: downloads.currentSnapshot,
      builder:
          (BuildContext context, AsyncSnapshot<DownloadsSnapshot> shot) {
            final DownloadsSnapshot? snapshot = shot.data;
            if (snapshot == null) {
              return const Padding(
                padding: EdgeInsets.only(top: AppSpacing.md),
                child: LoadingRows(count: 5),
              );
            }
            final List<DownloadJobView> running = snapshot.jobs
                .where((DownloadJobView v) => v.isActive)
                .toList(growable: false);
            final List<DownloadJobView> waiting = snapshot.jobs
                .where(
                  (DownloadJobView v) =>
                      v.job.status == DownloadJobStatus.queued ||
                      v.job.status == DownloadJobStatus.paused,
                )
                .toList(growable: false);
            final List<DownloadJobView> failed = snapshot.jobs
                .where(
                  (DownloadJobView v) => v.job.status == DownloadJobStatus.failed,
                )
                .toList(growable: false);
            final List<SongView> done = snapshot.downloaded;
            final bool empty =
                running.isEmpty &&
                waiting.isEmpty &&
                failed.isEmpty &&
                done.isEmpty;
            if (empty) {
              return EmptyState(
                icon: Icons.download_outlined,
                title: strings.downloadsEmptyTitle,
                body: strings.downloadsEmptyBody,
              );
            }
            final List<Track> doneTracks = done
                .map((SongView v) => downloads.trackFor(v))
                .toList(growable: false);
            return ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: Text(
                    strings.downloadsSummary(
                      snapshot.stats.downloadCount,
                      formatBytes(snapshot.stats.downloadBytes),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (running.isNotEmpty)
                  _JobGroup(
                    title: strings.dlDownloading,
                    jobs: running,
                    downloads: downloads,
                  ),
                if (waiting.isNotEmpty)
                  _JobGroup(
                    title: strings.dlWaiting,
                    jobs: waiting,
                    downloads: downloads,
                  ),
                if (failed.isNotEmpty)
                  _JobGroup(
                    title: strings.dlFailed,
                    jobs: failed,
                    downloads: downloads,
                  ),
                if (done.isNotEmpty) ...<Widget>[
                  _GroupTitle(title: strings.dlDone),
                  ...done.asMap().entries.map((MapEntry<int, SongView> entry) {
                    final int index = entry.key;
                    final SongView view = entry.value;
                    final Track track = doneTracks[index];
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
                            : () => playTracks(port!, snap, doneTracks, index),
                        trailing: _DownloadedMenu(
                          downloads: downloads,
                          view: view,
                        ),
                      ),
                    );
                  }),
                ],
              ],
            );
          },
    );
  }
}

/// Judul kelompok.
class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// Satu kelompok job unduhan.
class _JobGroup extends StatelessWidget {
  const _JobGroup({
    required this.title,
    required this.jobs,
    required this.downloads,
  });

  final String title;
  final List<DownloadJobView> jobs;
  final DownloadService downloads;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _GroupTitle(title: title),
        for (final DownloadJobView view in jobs)
          _JobRow(view: view, downloads: downloads),
      ],
    );
  }
}

/// Satu baris job: judul, status/progress, tombol aksi.
class _JobRow extends StatelessWidget {
  const _JobRow({required this.view, required this.downloads});

  final DownloadJobView view;
  final DownloadService downloads;

  String _statusText(AppLocalizations strings) {
    final DownloadJob job = view.job;
    switch (job.status) {
      case DownloadJobStatus.running:
        final int? total = job.totalBytes;
        if (total != null && total > 0) {
          return strings.dlProgressOf(
            formatBytes(job.bytesDownloaded),
            formatBytes(total),
          );
        }
        return strings.dlDownloading;
      case DownloadJobStatus.paused:
        return strings.dlPaused;
      case DownloadJobStatus.failed:
        return switch (job.errorMessage) {
          DownloadFailure.storageFull => strings.dlStorageFullJob,
          DownloadFailure.network => strings.dlNetworkJobFailed,
          DownloadFailure.unplayable => strings.dlUnplayableJobFailed,
          _ => strings.downloadFailed,
        };
      default:
        // Antrean: jangan ulangi kata "Menunggu" (sudah menjadi judul
        // kelompok) — tampilkan perkiraan ukuran unduhan, info yang
        // berguna bagi pengguna.
        final int? total = job.totalBytes;
        if (total != null && total > 0) {
          return strings.dlAboutSize(formatBytes(total));
        }
        return strings.dlWaiting;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final DownloadJob job = view.job;
    final bool running = job.status == DownloadJobStatus.running;
    final bool paused = job.status == DownloadJobStatus.paused;
    final bool failed = job.status == DownloadJobStatus.failed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      view.song.song.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusText(strings),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: failed
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              if (running)
                IconButton(
                  onPressed: () => downloads.pause(job.songId),
                  tooltip: strings.dlPauseDownload,
                  icon: const Icon(Icons.pause),
                ),
              if (paused || failed)
                IconButton(
                  onPressed: () => downloads.resumeJob(job.songId),
                  tooltip: strings.dlResumeDownload,
                  icon: const Icon(Icons.play_arrow),
                ),
              IconButton(
                onPressed: () => downloads.cancel(job.songId),
                tooltip: strings.dlCancelDownload,
                icon: const Icon(Icons.close, color: AppColors.textMuted),
              ),
            ],
          ),
          if (running) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(
              value: view.progress,
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// Menu lagu terunduh: putar dan hapus unduhan.
class _DownloadedMenu extends StatelessWidget {
  const _DownloadedMenu({required this.downloads, required this.view});

  final DownloadService downloads;
  final SongView view;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
      onSelected: (String value) async {
        if (value != 'delete') return;
        final bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(strings.deleteDownloadTitle),
              content: Text(
                strings.dlDeleteDownloadBody(view.song.title),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(strings.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(strings.delete),
                ),
              ],
            );
          },
        );
        if (confirmed == true) {
          await downloads.deleteDownload(view.id);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(strings.dlRemoveDownload),
        ),
      ],
    );
  }
}
