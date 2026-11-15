/// Bottom sheet "Tambah ke playlist": daftar playlist + buat baru.
///
/// Mengetuk playlist menambahkan lagu lalu menutup sheet dengan SnackBar
/// konfirmasi ("Ditambahkan ke ...") atau info bila lagu sudah ada.
/// "Playlist baru" membuka dialog buat playlist, lalu lagu ditambahkan
/// ke playlist yang baru dibuat itu.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/data/database.dart';
import 'package:laras/features/library/paged_list.dart';
import 'package:laras/features/library/playlist_form_dialog.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

/// Tampilkan sheet untuk menambahkan [songId] ke playlist.
Future<void> showAddToPlaylistSheet(
  BuildContext context, {
  required LibraryService service,
  required String songId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.elevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (BuildContext sheetContext) {
      // Tinggi tetap 60% layar: daftar di dalam sheet punya scroll-nya
      // sendiri, jadi sheet tidak perlu bisa diseret.
      return SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.6,
        child: _AddToPlaylistSheet(service: service, songId: songId),
      );
    },
  );
}

class _AddToPlaylistSheet extends StatelessWidget {
  const _AddToPlaylistSheet({required this.service, required this.songId});

  final LibraryService service;
  final String songId;

  Future<void> _addTo(
    BuildContext context,
    int playlistId,
    String playlistName,
  ) async {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final bool added = await service.addSongToPlaylist(playlistId, songId);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added ? strings.addedToPlaylist(playlistName) : strings.alreadyInPlaylist,
        ),
      ),
    );
  }

  Future<void> _createAndAdd(BuildContext context) async {
    final PlaylistFormResult? result = await showPlaylistFormDialog(
      context,
      isEditing: false,
    );
    if (result == null || !context.mounted) return;
    final int id = await service.createPlaylist(
      result.name,
      description: result.description,
    );
    if (!context.mounted) return;
    await _addTo(context, id, result.name);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Text(
            strings.addToPlaylist,
            style: theme.textTheme.titleMedium,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(strings.createPlaylist),
          onTap: () => _createAndAdd(context),
        ),
        const Divider(height: 1),
        Expanded(
          child: PagedList<PlaylistWithCount>(
            loadPage: (PlaylistWithCount? after) =>
                service.playlistsPage(after: after),
            itemBuilder:
                (
                  BuildContext context,
                  PlaylistWithCount item,
                  int index,
                  List<PlaylistWithCount> items,
                ) {
                  return ListTile(
                    leading: Container(
                      width: AppSizes.touchTarget,
                      height: AppSizes.touchTarget,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppRadius.coverSmall),
                        ),
                      ),
                      child: const Icon(
                        Icons.queue_music_outlined,
                        color: AppColors.textMuted,
                      ),
                    ),
                    title: Text(
                      item.playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      strings.playlistSongsCount(item.songCount),
                    ),
                    onTap: () =>
                        _addTo(context, item.playlist.id, item.playlist.name),
                  );
                },
            emptyIcon: Icons.queue_music_outlined,
            emptyTitle: strings.playlistsEmptyTitle,
            emptyBody: strings.playlistsEmptyBody,
          ),
        ),
      ],
    );
  }
}
