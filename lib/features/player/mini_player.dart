/// Mini-player 64 dp yang mengambang di atas tab bawah (Rombak UI-2).
///
/// Hanya tampil bila ada lagu yang sedang diputar atau dijeda. Tidak bisa
/// dihapus dengan geser ke samping. Ketuk sampul atau teks membuka Player
/// layar penuh; tombol sebelumnya, putar/jeda, dan berikutnya bekerja
/// tanpa membuka Player. Garis tipis di tepi bawah menunjukkan progres
/// lagu (kosong bila durasi belum diketahui).
///
/// Tombol putar berupa lingkaran putih (aksen) dengan ikon hitam —
/// titik aksi utama yang terlihat sekilas; ikon putar/jeda/ulangi
/// berganti dengan crossfade, judul berganti dengan crossfade bila
/// lagu berubah. Bayangan lembut + garis tipis menandai mini-player
/// melayang di atas konten (R-12: motif naik hanya di permukaan yang
/// benar-benar melayang).
///
/// State error (P0): bila [failure] tidak null, baris artis diganti pesan
/// singkat sesuai penyebab ("Tidak ada internet" / "Internet lambat" /
/// "Tidak bisa diputar") dan tombol putar berubah menjadi tombol coba lagi
/// (ikon segar, label "Coba lagi"). Tanpa ini, lagu yang gagal putar tampil
/// persis seperti lagu yang dijeda - pengguna tidak tahu ada masalah dan
/// tidak tahu harus apa (insiden P0 16 Nov 2026).
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/album_cover.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.title,
    required this.artist,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    this.position = Duration.zero,
    this.duration,
    this.artUri,
    this.isFavorite,
    this.onToggleFavorite,
    this.failure,
  });

  final String title;
  final String? artist;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  /// Posisi putar saat ini.
  final Duration position;

  /// Durasi lagu, null bila belum diketahui.
  final Duration? duration;

  /// Sampul lagu; null menampilkan ikon not balok.
  final Uri? artUri;

  /// Status favorit lagu saat ini; null berarti tombol hati disembunyikan
  /// (tidak ada library).
  final bool? isFavorite;

  /// Aksi tombol hati; null menyembunyikan tombolnya.
  final VoidCallback? onToggleFavorite;

  /// Kegagalan putar lagu ini, bila ada. Non-null berarti mini-player
  /// tampil dalam state error (pesan + tombol coba lagi).
  final PlaybackFailure? failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final String? artist = this.artist;
    final Duration? duration = this.duration;
    final PlaybackFailure? failure = this.failure;
    final double progress =
        duration != null && duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    // Margin di luar Padding supaya key 'mini-player' menandai kotak 64 dp
    // itu sendiri, bukan kotak + margin (72 dp) — kontrak tinggi 64 dp
    // jadi bisa diuji langsung.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        0,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Container(
        key: const Key('mini-player'),
        height: AppSizes.miniPlayer,
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadius.card),
          ),
          border: Border.all(color: AppColors.hairline),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadius.card),
          ),
          child: Stack(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AppRadius.card),
                      ),
                      child: Row(
                        children: <Widget>[
                          const SizedBox(width: AppSpacing.xs),
                          AlbumCover(
                            artUri: artUri,
                            size: AppSizes.touchTarget,
                            radius: 8,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Text(
                                    title,
                                    key: ValueKey<String>(title),
                                    style: theme.textTheme.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (failure != null)
                                  Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.error_outline,
                                        size: 14,
                                        color: AppColors.error,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          playbackFailureShortMessage(
                                            strings,
                                            failure,
                                          ),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: AppColors.error,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  )
                                else if (artist != null)
                                  Text(
                                    artist,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onToggleFavorite != null)
                    IconButton(
                      onPressed: onToggleFavorite,
                      tooltip: isFavorite == true
                          ? strings.favoriteRemove
                          : strings.favoriteAdd,
                      icon: Icon(
                        isFavorite == true
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: isFavorite == true
                            ? AppColors.accent
                            : AppColors.textMuted,
                      ),
                    ),
                  IconButton(
                    onPressed: onPrevious,
                    tooltip: strings.previousSong,
                    icon: const Icon(Icons.skip_previous),
                  ),
                  IconButton.filled(
                    onPressed: onPlayPause,
                    tooltip: failure != null
                        ? strings.retry
                        : isPlaying
                        ? strings.pause
                        : strings.play,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.textOnAccent,
                    ),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        failure != null
                            ? Icons.refresh
                            : isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        key: ValueKey<String>(
                          failure != null
                              ? 'refresh'
                              : isPlaying
                              ? 'pause'
                              : 'play',
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onNext,
                    tooltip: strings.nextSong,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.pressed,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
