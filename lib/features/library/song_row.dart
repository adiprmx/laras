/// Baris lagu bersama: dipakai beranda (lagu pilihan), tab Lagu,
/// Favorit, Riwayat, detail playlist, detail artis/album, dan antrean
/// Player.
///
/// Hierarki: sampul 56 dp, judul 16 semibold, subjudul (artis atau
/// durasi) 14 abu, durasi angka tabular di kanan, aksi di ujung kanan.
/// Baris yang sedang diputar mendapat latar permukaan + batang equalizer
/// di judul, jadi status putar terbaca tanpa membaca teks. Baris yang
/// sedang disiapkan menampilkan spinner kecil di slot aksi. Seluruh
/// baris bisa diketuk (efek tekan), bukan hanya tombolnya.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/album_cover.dart';
import 'package:laras/core/widgets/equalizer_bars.dart';
import 'package:laras/core/widgets/pressable.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

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
    this.isUnplayable = false,
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

  /// Benar bila lagu ini sedang berbunyi (batang equalizer di judul).
  final bool isPlaying;

  /// Benar bila lagu ini sedang disiapkan (spinner di slot aksi).
  final bool isBusy;

  /// Benar bila lagu terbukti tidak bisa diputar (P6, B4.7): baris
  /// tampil redup + label "Tidak bisa diputar" di subjudul. Baris tetap
  /// bisa diketuk (ketukan mencoba resolve; bila berhasil, tanda
  /// dibersihkan).
  final bool isUnplayable;

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
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final String? subtitle = isUnplayable
        ? (this.subtitle == null
              ? strings.cannotPlayLabel
              : '${this.subtitle} • ${strings.cannotPlayLabel}')
        : this.subtitle;
    final Duration? duration = this.duration;
    final Widget? trailing = this.trailing;
    // Latar baris yang sedang diputar berubah dengan animasi implisit
    // (finite, tes-aman): perpindahan lagu terasa, bukan sekadar
    // berganti teks.
    final Widget row = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      height: AppSizes.songRow,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: <Widget>[
          AlbumCover(
            artUri: artUri,
            size: 56,
            radius: 10,
            memCacheWidth: 112,
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
                        padding: EdgeInsets.only(right: AppSpacing.xs),
                        child: EqualizerBars(),
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
    );
    return Pressable(
      onTap: onTap,
      child: isUnplayable ? Opacity(opacity: 0.55, child: row) : row,
    );
  }
}

/// Tombol putar bundar putih (ikon hitam): aksi putar utama di baris lagu,
/// di kepala seksi, dan di kartu hero. Area sentuh 48 dp (atau sebesar
/// lingkaran bila [size] lebih besar), lingkaran visual [size] dp.
/// Ikon putar/jeda berganti dengan crossfade (transisi status, bukan
/// pergantian mendadak).
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
    final double box = math.max(AppSizes.touchTarget, size);
    return Pressable(
      onTap: onPressed,
      scale: 0.92,
      child: SizedBox(
        width: box,
        height: box,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                key: ValueKey<bool>(isPlaying),
                color: AppColors.textOnAccent,
                size: size * 0.55,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
