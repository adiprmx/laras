/// Sampul album: gambar dari jaringan (di-cache di disk) dengan
/// placeholder monokrom yang rapi saat belum termuat atau gagal.
///
/// Satu-satunya jalan menampilkan sampul di app: beranda, library,
/// mini-player, dan layar Player memakai widget yang sama supaya perilaku
/// muat/gagalnya konsisten. Tanpa URL, tampil ikon not balok di atas
/// permukaan abu — bukan kotak kosong.
library;

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';

class AlbumCover extends StatelessWidget {
  const AlbumCover({
    super.key,
    this.artUri,
    this.size = 48,
    this.radius = AppRadius.coverSmall,
    this.iconSize,
    this.memCacheWidth,
  });

  /// URL sampul, null bila lagu tidak punya sampul.
  final Uri? artUri;

  /// Lebar dan tinggi kotak sampul.
  final double size;

  /// Radius sudut.
  final double radius;

  /// Ukuran ikon placeholder. Default separuh [size].
  final double? iconSize;

  /// Lebar maksimum gambar yang disimpan di cache memori (hemat RAM
  /// untuk sampul kecil di daftar).
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final Uri? artUri = this.artUri;
    final Widget placeholder = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Icon(
        Icons.music_note_outlined,
        size: iconSize ?? size / 2,
        color: AppColors.textMuted,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      child: artUri == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: artUri.toString(),
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: memCacheWidth,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (BuildContext context, String url) => placeholder,
              // errorBuilder CE memakai signature ImageErrorWidgetBuilder
              // standar Flutter (context, error, stackTrace).
              errorBuilder:
                  (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) => placeholder,
            ),
    );
  }
}
