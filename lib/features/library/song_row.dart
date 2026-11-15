/// Baris lagu bersama: dipakai beranda (lagu pilihan), tab Lagu,
/// Favorit, Riwayat, detail playlist, dan detail artis/album.
///
/// Hierarki: sampul 48 dp, judul 16 semibold, subjudul (artis atau
/// durasi) 14 abu, durasi angka tabular di kanan, aksi di ujung kanan.
/// Baris yang sedang diputar menandai judulnya dengan ikon equalizer
/// kecil; baris yang sedang disiapkan menampilkan spinner kecil di slot
/// aksi. Seluruh baris bisa diketuk (efek tekan), bukan hanya tombolnya.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/album_cover.dart';
import 'package:laras/core/widgets/pressable.dart';

/// Satu baris lagu setinggi 64 dp.
class SongRow extends StatelessWidget {
  const SongRow({
    super.key,
    required this.title,
    this.subtitle,
    this.artUri,
    this.duration,
    this.isCurrent = false,
    this.isPlaying = false,
    this.isBusy = false,
    this.onTap,
    this.trailing,
  });

  /// Judul lagu (baris pertama, tebal).
  final String title;

  /// Artis (atau keterangan lain) di baris kedua. Null berarti satu baris.
  final String? subtitle;

  /// URL sampul, null bila tidak ada.
  final Uri? artUri;

  /// Durasi lagu, tampil sebagai angka di kanan (null bila tak diketahui).
  final Duration? duration;

  /// Benar bila lagu ini yang sedang dimuat/diputar di pemutar.
  final bool isCurrent;

  /// Benar bila lagu ini sedang berbunyi (ikon equalizer di judul).
  final bool isPlaying;

  /// Benar bila lagu ini sedang disiapkan (spinner di slot aksi).
  final bool isBusy;

  /// Ketuk di mana saja pada baris. Null berarti baris tidak bisa diketuk.
  final VoidCallback? onTap;

  /// Aksi di ujung kanan (tombol putar, hati, menu). Null berarti kosong.
  final Widget? trailing;

  static String _format(Duration value) {
    final int total = value.inSeconds;
    final int minutes = total ~/ 60;
    final int seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? subtitle = this.subtitle;
    final Duration? duration = this.duration;
    final Widget? trailing = this.trailing;
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        height: AppSizes.songRow,
        child: Row(
          children: <Widget>[
            AlbumCover(
              artUri: artUri,
              size: AppSizes.touchTarget,
              memCacheWidth: 96,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (isCurrent && isPlaying)
                        const Padding(
                          padding: EdgeInsets.only(right: AppSpacing.xxs),
                          child: Icon(
                            Icons.equalizer,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (duration != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Text(
                _format(duration),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (isBusy)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: trailing,
              ),
          ],
        ),
      ),
    );
  }
}

/// Tombol putar bundar putih (ikon hitam): aksi putar utama di baris lagu
/// dan di kepala seksi. Area sentuh 48 dp, lingkaran visual 40 dp.
class RoundPlayButton extends StatelessWidget {
  const RoundPlayButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.size = 40,
  });

  final bool isPlaying;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      scale: 0.92,
      child: SizedBox(
        width: AppSizes.touchTarget,
        height: AppSizes.touchTarget,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: AppColors.textOnAccent,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
