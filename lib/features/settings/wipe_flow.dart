/// Alur "Hapus semua data" (B7.3/L7, P6).
///
/// Dua konfirmasi bertingkat, lalu penghapusan, lalu layar selesai
/// dengan tombol "Tutup aplikasi" (restart adalah satu-satunya jalan
/// aman karena layanan memegang database yang sudah ditutup).
///
/// CATATAN P8: tombol "Simpan salinan dulu" di dialog konfirmasi pertama
/// adalah tugas P8 (backup belum ada di P6; tombol mati dilarang).
/// P8 menambahkan tombol itu di [_confirmFirst] + memanggil ekspor
/// sebelum [DataWipeService.wipeAll] dijalankan.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/resilience/data_wipe.dart';

/// Jalankan alur hapus semua data.
///
/// [onExitApp] disuntik untuk tes; di produksi menutup aplikasi
/// ([exit]).
Future<void> showWipeFlow(
  BuildContext context,
  DataWipeService wipe, {
  VoidCallback? onExitApp,
}) async {
  final AppLocalizations strings = AppLocalizations.of(context)!;
  final bool? first = await _confirmFirst(context, strings);
  if (first != true || !context.mounted) return;
  final bool? second = await _confirmSecond(context, strings);
  if (second != true || !context.mounted) return;
  // Dialog progres (tidak bisa ditutup) selama penghapusan berjalan.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: <Widget>[
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(strings.wipeDataWorking)),
          ],
        ),
      ),
    ),
  );
  final WipeResult result = await wipe.wipeAll();
  if (!context.mounted) return;
  Navigator.of(context).pop(); // Tutup dialog progres.
  Navigator.of(context).pushAndRemoveUntil<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => _WipeDoneScreen(
        result: result,
        onExitApp: onExitApp ?? () => exit(0),
      ),
    ),
    (_) => false,
  );
}

Future<bool?> _confirmFirst(BuildContext context, AppLocalizations strings) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(strings.wipeDataTitle1),
      content: Text(strings.wipeDataBody1),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.cancel),
        ),
        // P8 menambahkan tombol "Simpan salinan dulu" di sini.
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(strings.wipeData),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmSecond(BuildContext context, AppLocalizations strings) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(strings.wipeDataTitle2),
      content: Text(strings.wipeDataBody2),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.textPrimary,
          ),
          child: Text(strings.wipeDataConfirm),
        ),
      ],
    ),
  );
}

/// Layar selesai: app sudah tidak bisa dipakai lagi tanpa restart
/// (database tertutup, preferensi hilang), jadi satu-satunya aksi
/// adalah menutup aplikasi.
class _WipeDoneScreen extends StatelessWidget {
  const _WipeDoneScreen({required this.result, required this.onExitApp});

  final WipeResult result;
  final VoidCallback onExitApp;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  strings.wipeDataDone,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                if (!result.fullySucceeded) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    strings.wipeDataPartial,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: onExitApp,
                  child: Text(strings.wipeDataCloseApp),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
