import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

/// Mini-player 64 dp yang mengambang di atas tab bawah.
///
/// Hanya tampil bila ada lagu yang sedang diputar atau dijeda. Tidak bisa
/// dihapus dengan geser ke samping. Ketuk sampul atau teks membuka Player
/// layar penuh (P2); tombol putar dan berikutnya bekerja tanpa membuka Player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.title,
    required this.artist,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
    required this.onNext,
  });

  final String title;
  final String? artist;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final String? artist = this.artist;
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
        decoration: const BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
        child: Row(
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
                    Container(
                      width: AppSizes.touchTarget,
                      height: AppSizes.touchTarget,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppRadius.coverSmall),
                        ),
                      ),
                      child: const Icon(
                        Icons.music_note_outlined,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (artist != null)
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
            IconButton(
              onPressed: onPlayPause,
              tooltip: isPlaying ? strings.pause : strings.play,
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              onPressed: onNext,
              tooltip: strings.nextSong,
              icon: const Icon(Icons.skip_next),
            ),
          ],
        ),
      ),
    );
  }
}
