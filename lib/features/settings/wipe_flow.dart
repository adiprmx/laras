/// Alur "Hapus semua data" (B7.3/L7, P6).
///
/// Dua konfirmasi bertingkat, lalu penghapusan, lalu layar selesai
/// dengan tombol "Tutup aplikasi" (restart adalah satu-satunya jalan
/// aman karena layanan memegang database yang sudah ditutup).
///
/// P8: dialog konfirmasi pertama punya tombol "Simpan salinan dulu"
/// (bila [BackupService] tersedia). Menekan tombol itu mengekspor
/// backup lewat lembar berbagi lalu KEMBALI ke dialog — penghapusan
/// TIDAK lanjut otomatis; pengguna memutuskan sesudah ekspor (batal
/// atau gagal pun tidak mengubah keputusan penghapusan).
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/features/backup/backup_service.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/resilience/data_wipe.dart';

/// Jalankan alur hapus semua data.
///
/// [onExitApp] disuntik untuk tes; di produksi menutup aplikasi
/// ([exit]). [backupService] null berarti tombol "Simpan salinan
/// dulu" disembunyikan (tes tanpa scope backup).
Future<void> showWipeFlow(
  BuildContext context,
  DataWipeService wipe, {
  VoidCallback? onExitApp,
  BackupService? backupService,
}) async {
  final AppLocalizations strings = AppLocalizations.of(context)!;
  // Loop konfirmasi pertama: pilihan "salinan dulu" mengekspor lalu
  // kembali ke dialog ini; penghapusan hanya lanjut bila pengguna
  // menekan tombol hapus.
  while (true) {
    final _FirstChoice? first = await _confirmFirst(
      context,
      strings,
      showBackupButton: backupService != null,
    );
    if (first == null || first == _FirstChoice.cancel) return;
    if (first == _FirstChoice.backup) {
      final BackupExportOutcome outcome =
          await backupService!.exportAndShare();
      if (!context.mounted) return;
      final String message = switch (outcome) {
        BackupExportOutcome.shared => strings.backupExported,
        BackupExportOutcome.failed => strings.backupShareFailed,
        BackupExportOutcome.tooLarge => strings.backupExportTooLarge,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      continue;
    }
    break;
  }
  if (!context.mounted) return;
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

/// Pilihan di dialog konfirmasi pertama hapus data.
enum _FirstChoice { cancel, delete, backup }

Future<_FirstChoice?> _confirmFirst(
  BuildContext context,
  AppLocalizations strings, {
  required bool showBackupButton,
}) {
  return showDialog<_FirstChoice>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(strings.wipeDataTitle1),
      content: Text(strings.wipeDataBody1),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(_FirstChoice.cancel),
          child: Text(strings.cancel),
        ),
        if (showBackupButton)
          TextButton(
            onPressed: () => Navigator.of(context).pop(_FirstChoice.backup),
            child: Text(strings.wipeSaveBackupFirst),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_FirstChoice.delete),
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
