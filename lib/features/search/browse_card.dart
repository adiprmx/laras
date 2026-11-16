/// Kartu browse: sampul persegi + judul + keterangan, untuk deretan
/// horizontal di seksi Jelajah dan halaman detail browse.
///
/// Satu kartu dipakai di semua tempat (beranda, halaman artis, album,
/// playlist) supaya tampilannya konsisten. Tanpa sampul, tampil
/// placeholder not balok dari [AlbumCover] — bukan kotak kosong.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/album_cover.dart';
import 'package:laras/core/widgets/pressable.dart';

/// Lebar kartu browse di deretan horizontal (A12: kartu 158 dp di layar
/// 360 dp untuk grid 2 kolom; deretan horizontal memakai 140 dp supaya
/// kartu berikut mengintip dan memberi tahu bisa di-scroll).
const double kBrowseCardWidth = 140;

class BrowseCard extends StatelessWidget {
  const BrowseCard({
    super.key,
    required this.title,
    this.subtitle,
    this.artUri,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Uri? artUri;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? subtitle = this.subtitle;
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: kBrowseCardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AlbumCover(
              artUri: artUri,
              size: kBrowseCardWidth,
              radius: AppRadius.coverLarge,
              memCacheWidth: 280,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              title,
              style: theme.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Baris album/artis/playlist di daftar hasil pencarian dan daftar penuh:
/// sampul + judul + keterangan + panah.
class BrowseResultRow extends StatelessWidget {
  const BrowseResultRow({
    super.key,
    required this.title,
    this.subtitle,
    this.artUri,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Uri? artUri;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? subtitle = this.subtitle;
    return ListTile(
      leading: AlbumCover(artUri: artUri, size: 48),
      title: Text(
        title,
        style: theme.textTheme.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
