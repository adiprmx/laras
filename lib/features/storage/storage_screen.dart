/// Layar Penyimpanan (P5): pemakaian ruang yang jujur.
///
/// Menampilkan total unduhan, total ruang lagu yang pernah diputar
/// beserta batasnya, dan sisa ruang HP — semuanya angka nyata dari
/// database (unduhan + cache) dan sistem (sisa ruang). Kata "cache"
/// tidak pernah tampil di layar (PRD B8.3).
///
/// Aksi: kosongkan ruang lagu yang pernah diputar (tidak menyentuh
/// unduhan), hapus unduhan per lagu, hapus semua unduhan. Semua aksi
/// hapus memakai dialog konfirmasi yang menyebut angka nyata.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/empty_state.dart';
import 'package:laras/core/widgets/loading_rows.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/features/library/song_row.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  Future<_StorageData?>? _future;
  SongView? _lastLoaded;
  bool _hasMore = true;
  final List<SongView> _downloaded = <SongView>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  /// Muat ringkasan + halaman pertama lagu terunduh. Halaman digabung
  /// ke [_downloaded] di sini (bukan di build) supaya build tetap murni.
  Future<_StorageData?> _load() async {
    final DownloadService? downloads = DownloadsScope.downloadsOf(context);
    final StreamCacheService? cache = DownloadsScope.maybeOf(context)?.cache;
    final LibraryService? library = LibraryScope.maybeOf(context);
    if (downloads == null || library == null) return null;
    final StorageStats stats = await downloads.storageStats();
    final int? free = await downloads.freeSpaceBytes();
    final int cacheLimit = cache?.cacheLimitBytes ?? kDefaultCacheLimitBytes;
    final List<SongView> page = await library.downloadedSongsPage();
    _downloaded
      ..clear()
      ..addAll(page);
    _lastLoaded = page.isEmpty ? null : page.last;
    _hasMore = page.length >= kPageSize;
    return _StorageData(
      stats: stats,
      freeBytes: free,
      cacheLimitBytes: cacheLimit,
    );
  }

  void _refresh() {
    setState(() {
      _lastLoaded = null;
      _hasMore = true;
      _downloaded.clear();
      _future = _load();
    });
  }

  Future<void> _loadMore() async {
    final LibraryService? library = LibraryScope.maybeOf(context);
    if (library == null || !_hasMore) return;
    final List<SongView> page = await library.downloadedSongsPage(
      after: _lastLoaded,
    );
    if (!mounted) return;
    setState(() {
      _downloaded.addAll(page);
      if (page.isNotEmpty) _lastLoaded = page.last;
      _hasMore = page.length >= kPageSize;
    });
  }

  Future<void> _clearCache() async {
    final StreamCacheService? cache = DownloadsScope.maybeOf(context)?.cache;
    if (cache == null) return;
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.dlClearCacheTitle),
          content: Text(strings.dlClearCacheBody),
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
    if (confirmed != true || !mounted) return;
    await cache.clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.playedSongsSpaceCleared)),
    );
    _refresh();
  }

  Future<void> _deleteAll() async {
    final DownloadService? downloads = DownloadsScope.downloadsOf(context);
    if (downloads == null) return;
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final StorageStats stats = await downloads.storageStats();
    if (!mounted) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.dlDeleteAllTitle),
          content: Text(
            strings.dlDeleteAllBody(
              stats.downloadCount,
              formatBytes(stats.downloadBytes),
            ),
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
    if (confirmed != true || !mounted) return;
    await downloads.deleteAllDownloads();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.dlAllDownloadsDeleted)),
    );
    _refresh();
  }

  Future<void> _deleteOne(SongView view) async {
    final DownloadService? downloads = DownloadsScope.downloadsOf(context);
    if (downloads == null) return;
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.deleteDownloadTitle),
          content: Text(strings.dlDeleteDownloadBody(view.song.title)),
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
    if (confirmed != true || !mounted) return;
    await downloads.deleteDownload(view.id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.dlStorageTitle)),
      body: FutureBuilder<_StorageData?>(
        future: _future,
        builder:
            (BuildContext context, AsyncSnapshot<_StorageData?> shot) {
              if (shot.connectionState == ConnectionState.waiting &&
                  _downloaded.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: LoadingRows(count: 5),
                );
              }
              final _StorageData? data = shot.data;
              if (data == null) {
                return EmptyState(
                  icon: Icons.storage_outlined,
                  title: strings.libraryFailed,
                  body: strings.downloadsEmptyBody,
                );
              }
              final StorageStats stats = data.stats;
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                children: <Widget>[
                  _StatRow(
                    label: strings.dlDownloadedSongs,
                    value: strings.downloadsSummary(
                      stats.downloadCount,
                      formatBytes(stats.downloadBytes),
                    ),
                  ),
                  _StatRow(
                    label: strings.playedSongsSpace,
                    value:
                        '${formatBytes(stats.playedSongsBytes)} '
                        '(${strings.dlCacheLimit(formatBytes(data.cacheLimitBytes))})',
                  ),
                  _StatRow(
                    label: strings.dlFreeSpaceRow,
                    value: data.freeBytes == null
                        ? strings.cannotCalculate
                        : formatBytes(data.freeBytes!),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: stats.playedSongsBytes > 0
                        ? _clearCache
                        : null,
                    child: Text(strings.clearPlayedSongsSpace),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: stats.downloadCount > 0 ? _deleteAll : null,
                    child: Text(strings.dlDeleteAllDownloads),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    strings.dlDownloadedSongs,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_downloaded.isEmpty)
                    Text(
                      strings.downloadsEmptyTitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    for (final SongView view in _downloaded)
                      SongRow(
                        title: view.song.title,
                        subtitle: view.artistNames.isEmpty
                            ? formatBytes(view.song.fileSizeBytes ?? 0)
                            : '${view.artistsLabel} · '
                                  '${formatBytes(view.song.fileSizeBytes ?? 0)}',
                        artUri: view.toTrack().artUri,
                        trailing: IconButton(
                          onPressed: () => _deleteOne(view),
                          tooltip: strings.dlRemoveDownload,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  if (_hasMore && _downloaded.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: TextButton(
                        onPressed: _loadMore,
                        child: Text(strings.loadMore),
                      ),
                    ),
                  ],
                ],
              );
            },
      ),
    );
  }
}

/// Data ringkasan penyimpanan (sekali muat).
class _StorageData {
  const _StorageData({
    required this.stats,
    required this.freeBytes,
    required this.cacheLimitBytes,
  });

  final StorageStats stats;
  final int? freeBytes;
  final int cacheLimitBytes;
}

/// Satu baris statistik: label kiri, nilai kanan.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
