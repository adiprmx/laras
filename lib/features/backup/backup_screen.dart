/// Layar Salinan data (P8, PRD B7.2/B7.4/B10.3).
///
/// Di Pengaturan, kelompok "Akun dan data": penjelasan jujur isi
/// salinan, ringkasan isi salinan saat ini, tombol ekspor (lembar
/// berbagi Android), tombol impor (pemilih file + dialog ringkasan +
/// opsi pengaturan), dan jalan masuk impor Spotify.
library;

import 'package:flutter/material.dart';

import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/data/database.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

import 'backup_file_channel.dart';
import 'backup_service.dart';
import 'import_report.dart';
import 'import_report_sheet.dart';
import 'spotify_import.dart';
import 'spotify_import_screen.dart';

/// Layar Salinan data. [backup] wajib ada (baris Pengaturan
/// disembunyikan bila service tidak tersedia); [spotify] null berarti
/// entri impor Spotify disembunyikan.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.backup, this.spotify});

  final BackupService backup;
  final SpotifyImportService? spotify;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _exporting = false;
  bool _importing = false;

  /// Snapshot isi salinan saat ini. Disimpan di state (bukan dibuat di
  /// build): FutureBuilder dengan future baru tiap build akan
  /// me-rebuild tanpa henti.
  late Future<BackupData> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = widget.backup.buildBackupData();
  }

  BackupService get _backup => widget.backup;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Pesan untuk [BackupException] berdasarkan jenisnya.
  String _backupErrorMessage(AppLocalizations strings, BackupException e) {
    switch (e.kind) {
      case BackupErrorKind.tooLarge:
        return strings.backupTooLarge;
      case BackupErrorKind.invalidJson:
      case BackupErrorKind.invalidStructure:
        return strings.backupInvalid;
      case BackupErrorKind.notBackup:
        return strings.backupNotBackup;
      case BackupErrorKind.newerVersion:
        return strings.backupNewerVersion;
    }
  }

  Future<void> _export() async {
    if (_exporting || _importing) return;
    setState(() => _exporting = true);
    final BackupExportOutcome outcome;
    try {
      outcome = await _backup.exportAndShare();
    } on Object {
      if (!mounted) return;
      setState(() => _exporting = false);
      _showSnack(AppLocalizations.of(context)!.backupExportFailed);
      return;
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    final AppLocalizations strings = AppLocalizations.of(context)!;
    switch (outcome) {
      case BackupExportOutcome.shared:
        _showSnack(strings.backupExported);
      case BackupExportOutcome.failed:
        _showSnack(strings.backupShareFailed);
      case BackupExportOutcome.tooLarge:
        _showSnack(strings.backupExportTooLarge);
    }
  }

  Future<void> _import() async {
    if (_exporting || _importing) return;
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final PickedFile? picked;
    try {
      picked = await _backup.pickFile();
    } on BackupException catch (e) {
      _showSnack(_backupErrorMessage(strings, e));
      return;
    } on BackupFileException {
      _showSnack(strings.backupPickFailed);
      return;
    }
    if (picked == null) return; // Pengguna membatalkan pemilih file.
    final BackupData data;
    try {
      data = _backup.previewImport(picked.bytes);
    } on BackupException catch (e) {
      if (!mounted) return;
      _showSnack(_backupErrorMessage(strings, e));
      return;
    }
    if (!mounted) return;
    final bool? confirmed = await _showPreviewDialog(data);
    if (confirmed == null || !mounted) return;
    setState(() => _importing = true);
    final ImportReport report;
    try {
      report = await _backup.importBackup(
        data,
        applySettings: confirmed,
      );
    } on Object {
      if (!mounted) return;
      setState(() => _importing = false);
      _showSnack(strings.backupInvalid);
      return;
    }
    if (!mounted) return;
    setState(() => _importing = false);
    await showImportReportSheet(context, report);
    // Ringkasan isi salinan berubah sesudah impor: muat ulang.
    if (mounted) {
      setState(() {
        _snapshotFuture = _backup.buildBackupData();
      });
    }
  }

  /// Dialog ringkasan sebelum impor (B10.3): jumlah isi file, tanggal,
  /// versi app pembuat, dan opsi pengaturan. Mengembalikan pilihan
  /// pengaturan (true = pulihkan juga pengaturan) atau null bila batal.
  Future<bool?> _showPreviewDialog(BackupData data) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    bool applySettings = true;
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return AlertDialog(
            title: Text(strings.backupPreviewTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SummaryLine(
                    strings.backupPreviewSongs(data.songs.length),
                  ),
                  _SummaryLine(
                    strings.backupPreviewPlaylists(data.playlists.length),
                  ),
                  _SummaryLine(
                    strings.backupPreviewFavorites(data.favoriteCount),
                  ),
                  _SummaryLine(
                    strings.backupPreviewHistory(data.playEvents.length),
                  ),
                  _SummaryLine(
                    strings.backupPreviewSearches(data.searchHistory.length),
                  ),
                  _SummaryLine(
                    strings.backupPreviewQueue(data.queue.length),
                  ),
                  _SummaryLine(
                    strings.backupPreviewDownloaded(
                      data.downloadedSongIds.length,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SummaryLine(
                    strings.backupPreviewMadeOn(
                      formatBackupDate(data.exportedAt),
                    ),
                  ),
                  _SummaryLine(
                    strings.backupPreviewFromApp(data.appVersion),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      strings.backupApplySettings,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    value: applySettings,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        applySettings = value ?? true;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(applySettings),
                child: Text(strings.backupRestore),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final bool busy = _exporting || _importing;
    final SpotifyImportService? spotify = widget.spotify;
    return Scaffold(
      appBar: AppBar(title: Text(strings.backupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text(
            strings.backupIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            strings.backupCurrentTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FutureBuilder<BackupData>(
            future: _snapshotFuture,
            builder: (
              BuildContext context,
              AsyncSnapshot<BackupData> shot,
            ) {
              final BackupData? data = shot.data;
              if (shot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: LinearProgressIndicator(),
                );
              }
              if (data == null) return const SizedBox.shrink();
              final bool empty =
                  data.songs.isEmpty &&
                  data.playlists.isEmpty &&
                  data.playEvents.isEmpty &&
                  data.searchHistory.isEmpty &&
                  data.queue.isEmpty;
              if (empty) {
                return Text(
                  strings.backupEmptyNote,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SummaryLine(strings.backupPreviewSongs(data.songs.length)),
                  _SummaryLine(
                    strings.backupPreviewPlaylists(data.playlists.length),
                  ),
                  _SummaryLine(
                    strings.backupPreviewFavorites(data.favoriteCount),
                  ),
                  _SummaryLine(
                    strings.backupPreviewHistory(data.playEvents.length),
                  ),
                  _SummaryLine(
                    strings.backupPreviewSearches(data.searchHistory.length),
                  ),
                  _SummaryLine(
                    strings.backupPreviewQueue(data.queue.length),
                  ),
                  _SummaryLine(
                    strings.backupPreviewDownloaded(
                      data.downloadedSongIds.length,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: busy ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
            label: Text(
              _exporting ? strings.backupExporting : strings.backupExport,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: busy ? null : _import,
            icon: _importing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open_outlined),
            label: Text(
              _importing ? strings.backupImporting : strings.backupImport,
            ),
          ),
          if (spotify != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: AppSizes.settingsRow,
              title: Text(
                strings.spotifyTitle,
                style: theme.textTheme.bodyLarge,
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
              onTap: busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            SpotifyImportScreen(
                              spotify: spotify,
                              files: _backup.files,
                            ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
