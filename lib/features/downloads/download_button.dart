/// Tombol unduh di baris lagu dan layar pemutar (P5).
///
/// Design read: Operate-mode utility, bahasa monokrom hitam/putih yang
/// sama dengan tombol hati di sebelahnya (ikon outline, 48 dp, tanpa
/// badge atau hiasan). Satu ikon per keadaan, tanpa teks:
///
/// * Belum diunduh: `download_outlined` abu-abu -> ketuk membuka dialog
///   pilih kualitas.
/// * Mengunduh/menunggu: cincin progress (nilai nyata bila total
///   diketahui) -> ketuk membuka tab Unduhan.
/// * Sudah diunduh: `download_done` putih -> ketuk membuka dialog hapus.
/// * Gagal: kembali ke ikon unduh (status lagu direset saat job gagal);
///   ketuk mencoba lagi dan melanjutkan dari `.part` yang tertinggal.
///
/// Sembunyi total bila layanan unduhan tidak tersedia (database gagal
/// dibuka) — tidak ada tombol mati yang tampil.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/track.dart';

import 'downloads_screen.dart';

/// Tombol unduh untuk satu lagu.
class DownloadButton extends StatelessWidget {
  const DownloadButton({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final DownloadService? downloads = DownloadsScope.downloadsOf(context);
    final LibraryService? library = LibraryScope.maybeOf(context);
    if (downloads == null || library == null) {
      return const SizedBox.shrink();
    }
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return StreamBuilder<int>(
      stream: library.watchDownloadState(track.videoId),
      initialData: DownloadState.notDownloaded,
      builder: (BuildContext context, AsyncSnapshot<int> shot) {
        final int state = shot.data ?? DownloadState.notDownloaded;
        switch (state) {
          case DownloadState.downloaded:
            return IconButton(
              onPressed: () => _confirmDelete(context, downloads),
              tooltip: strings.dlRemoveDownload,
              icon: const Icon(
                Icons.download_done,
                color: AppColors.accent,
              ),
            );
          case DownloadState.downloading:
            return _DownloadingIndicator(
              downloads: downloads,
              videoId: track.videoId,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        const DownloadsScreen(),
                  ),
                );
              },
            );
          default:
            return IconButton(
              onPressed: () => showDownloadQualityDialog(
                context,
                track: track,
                downloads: downloads,
              ),
              tooltip: strings.download,
              icon: const Icon(
                Icons.download_outlined,
                color: AppColors.textMuted,
              ),
            );
        }
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DownloadService downloads,
  ) async {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.deleteDownloadTitle),
          content: Text(strings.dlDeleteDownloadBody(track.title)),
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
    if (confirmed == true && context.mounted) {
      await downloads.deleteDownload(track.videoId);
    }
  }
}

/// Cincin progress kecil (20 dp) untuk lagu yang sedang diunduh.
class _DownloadingIndicator extends StatelessWidget {
  const _DownloadingIndicator({
    required this.downloads,
    required this.videoId,
    required this.onTap,
  });

  final DownloadService downloads;
  final String videoId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DownloadsSnapshot>(
      stream: downloads.stateStream,
      // Snapshot terakhir sebagai data awal (stream broadcast tidak
      // mengulang emisi lama untuk pendengar baru).
      initialData: downloads.currentSnapshot,
      builder: (BuildContext context, AsyncSnapshot<DownloadsSnapshot> shot) {
        double? progress;
        final DownloadsSnapshot? snapshot = shot.data;
        if (snapshot != null) {
          for (final DownloadJobView view in snapshot.jobs) {
            if (view.job.songId == videoId) {
              progress = view.progress;
              break;
            }
          }
        }
        return IconButton(
          onPressed: onTap,
          tooltip: AppLocalizations.of(context)!.tabDownloads,
          icon: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        );
      },
    );
  }
}

/// Dialog pilih kualitas unduhan: 3 opsi kanonis (Terbaik, Seimbang,
/// Hemat data) dengan penjelasan + perkiraan ukuran dari durasi nyata
/// lagu. Opsi yang tidak muat di sisa ruang (perkiraan + 100 MB buffer)
/// tidak bisa dipilih, dengan peringatan yang jelas.
Future<void> showDownloadQualityDialog(
  BuildContext context, {
  required Track track,
  required DownloadService downloads,
}) async {
  final AppLocalizations strings = AppLocalizations.of(context)!;
  DownloadQuality selected = downloads.defaultQuality;
  final Duration? duration = track.duration;
  final int? freeBytes = await downloads.freeSpaceBytes();
  if (!context.mounted) return;
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          bool fits(DownloadQuality quality) {
            if (freeBytes == null || duration == null) return true;
            return freeBytes >=
                quality.estimateBytes(duration) + kFreeSpaceBufferBytes;
          }

          Widget option(DownloadQuality quality) {
            final String label = switch (quality) {
              DownloadQuality.best => strings.qualityBest,
              DownloadQuality.balanced => strings.qualityBalanced,
              DownloadQuality.dataSaver => strings.qualityDataSaver,
            };
            final String desc = switch (quality) {
              DownloadQuality.best => strings.qualityBestDesc,
              DownloadQuality.balanced => strings.qualityBalancedDesc,
              DownloadQuality.dataSaver => strings.qualityDataSaverDesc,
            };
            final String size = duration == null
                ? ''
                : ' (${strings.dlAboutSize(formatBytes(quality.estimateBytes(duration)))})';
            return RadioListTile<DownloadQuality>(
              title: Text('$label$size'),
              subtitle: Text(desc),
              value: quality,
              enabled: fits(quality),
            );
          }

          return AlertDialog(
            title: Text(strings.dlDownloadQualityTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    track.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<DownloadQuality>(
                    groupValue: selected,
                    onChanged: (DownloadQuality? value) {
                      if (value != null) setState(() => selected = value);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        option(DownloadQuality.best),
                        option(DownloadQuality.balanced),
                        option(DownloadQuality.dataSaver),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    freeBytes == null
                        ? strings.dlNoFreeSpaceInfo
                        : strings.freeSpace(formatBytes(freeBytes)),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!fits(selected))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        strings.notEnoughSpace,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.error),
                      ),
                    ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: fits(selected)
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                child: Text(strings.download),
              ),
            ],
          );
        },
      );
    },
  );
  if (confirmed == true && context.mounted) {
    final bool enqueued = await downloads.enqueue(track, quality: selected);
    if (enqueued && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.dlQueued)),
      );
    }
  }
}
