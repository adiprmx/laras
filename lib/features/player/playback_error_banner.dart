/// Banner kegagalan putar bersama: dipakai Player layar penuh dan Beranda.
///
/// Tampil saat lagu gagal diputar: pesan bahasa sehari-hari sesuai penyebab
/// (tanpa internet / internet lambat / tidak bisa diputar) + tombol
/// "Coba lagi". Bila penyebabnya menyarankan pembaruan (P6: YouTube
/// berubah), tombol "Periksa pembaruan" tampil di samping "Coba lagi".
/// Tampilannya mengikuti banner error Player yang sudah ada (permukaan
/// `surface`, sudut kartu, teks + tombol) supaya konsisten di semua
/// permukaan.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player.dart';
import 'package:laras/resilience/cause_messages.dart';

class PlaybackErrorBanner extends StatelessWidget {
  const PlaybackErrorBanner({
    super.key,
    required this.failure,
    required this.onRetry,
    this.onCheckUpdates,
  });

  final PlaybackFailure failure;
  final VoidCallback onRetry;

  /// Dipanggil saat tombol "Periksa pembaruan" ditekan. Tombol hanya
  /// tampil bila callback ini tidak null DAN penyebab kegagalan
  /// menyarankan pembaruan ([causeSuggestsUpdate]).
  final VoidCallback? onCheckUpdates;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final bool showUpdate =
        onCheckUpdates != null &&
        failure.cause != null &&
        causeSuggestsUpdate(failure.cause!);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              playbackFailureMessage(strings, failure),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (showUpdate)
            TextButton(
              onPressed: onCheckUpdates,
              child: Text(strings.checkForUpdates),
            ),
          TextButton(onPressed: onRetry, child: Text(strings.retry)),
        ],
      ),
    );
  }
}
