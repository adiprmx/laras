/// Laporan hasil impor (P8, PRD B10.4): lembar bawah yang menampilkan
/// ringkasan berhasil / sudah ada / gagal beserta alasan per lagu yang
/// gagal.
///
/// Laporan TIDAK disimpan permanen: sesudah ditutup, laporan hilang
/// (datanya tetap tersimpan). Tombol tambahan, bila relevan:
/// - "Lihat playlist" (impor Spotify yang membuat playlist).
/// - "Unduh ulang lagu yang dulu sudah diunduh" (impor backup yang
///   membawa daftar unduhan; memasukkan lagu ke antrean unduhan dan
///   menghormati saklar WiFi saja lewat DownloadService).
library;

import 'package:flutter/material.dart';

import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads_scope.dart';
import 'package:laras/features/library/playlist_detail_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/track.dart';

import 'import_report.dart';

/// Tampilkan laporan hasil impor sebagai lembar bawah.
Future<void> showImportReportSheet(
  BuildContext context,
  ImportReport report,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => _ImportReportSheet(report: report),
  );
}

/// Alasan gagal -> string bahasa sehari-hari.
String importFailureReasonText(
  AppLocalizations strings,
  ImportFailureReason reason,
) {
  switch (reason) {
    case ImportFailureReason.notFound:
      return strings.importFailNotFound;
    case ImportFailureReason.skipped:
      return strings.importFailSkipped;
    case ImportFailureReason.cancelled:
      return strings.importFailCancelled;
    case ImportFailureReason.queueFull:
      return strings.importFailQueueFull;
    case ImportFailureReason.searchFailed:
      return strings.importFailSearchFailed;
    case ImportFailureReason.network:
      return strings.importFailNetwork;
  }
}

class _ImportReportSheet extends StatefulWidget {
  const _ImportReportSheet({required this.report});

  final ImportReport report;

  @override
  State<_ImportReportSheet> createState() => _ImportReportSheetState();
}

class _ImportReportSheetState extends State<_ImportReportSheet> {
  bool _redownloadQueued = false;
  bool _redownloading = false;

  ImportReport get _report => widget.report;

  Future<void> _redownload() async {
    if (_redownloading || _redownloadQueued) return;
    final library = LibraryScope.maybeOf(context);
    final downloads = DownloadsScope.downloadsOf(context);
    if (library == null || downloads == null) return;
    setState(() => _redownloading = true);
    final List<SongView> songs = await library.songsByIds(
      _report.downloadedSongIds,
    );
    final List<Track> tracks = songs
        .map((SongView s) => s.toTrack())
        .toList(growable: false);
    await downloads.enqueueMany(tracks);
    if (!mounted) return;
    setState(() {
      _redownloading = false;
      _redownloadQueued = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.importRedownloadQueued),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final ImportReport report = _report;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text(
                  strings.importReportTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Text(
                  strings.importReportSummary(
                    report.succeeded,
                    report.alreadyExisted,
                    report.failed,
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: report.hasFailures
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Text(
                              strings.importReportFailedTitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Expanded(
                            child: ListView.builder(
                              itemCount: report.failures.length,
                              itemBuilder:
                                  (BuildContext context, int index) {
                                final ImportFailure failure =
                                    report.failures[index];
                                return ListTile(
                                  title: Text(
                                    failure.label,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  subtitle: Text(
                                    importFailureReasonText(
                                      strings,
                                      failure.reason,
                                    ),
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(
                            strings.importReportAllOk,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.success,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (report.playlistId != null)
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) =>
                                  PlaylistDetailScreen(
                                    playlistId: report.playlistId!,
                                  ),
                            ),
                          );
                        },
                        child: Text(strings.importReportViewPlaylist),
                      ),
                    if (report.downloadedSongIds.isNotEmpty) ...<Widget>[
                      if (report.playlistId != null)
                        const SizedBox(height: AppSpacing.sm),
                      FilledButton.tonal(
                        onPressed: _redownloadQueued || _redownloading
                            ? null
                            : _redownload,
                        child: _redownloading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _redownloadQueued
                                    ? strings.importRedownloadQueued
                                    : strings.importRedownload,
                              ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(strings.importReportDone),
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
