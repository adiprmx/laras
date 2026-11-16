/// Aksi "Periksa pembaruan" bersama (P6, tugas 4).
///
/// Dipakai banner beranda, Pengaturan, layar status layanan, dan
/// kegagalan browse: satu jalur yang sama menjalankan cek lalu
/// menampilkan hasilnya dengan jujur lewat snackbar.
library;

import 'package:flutter/material.dart';

import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/resilience/service_status.dart';

/// Jalankan "Periksa pembaruan" dan tampilkan hasilnya.
Future<void> runCheckForUpdates(
  BuildContext context,
  ServiceStatusService service,
) async {
  final AppLocalizations strings = AppLocalizations.of(context)!;
  final UpdateCheckResult result = await service.checkForUpdates();
  if (!context.mounted) return;
  final String message = switch (result) {
    UpdateCheckResult.upToDateOk => strings.updateUpToDate,
    UpdateCheckResult.updatedOk => strings.updateApplied,
    UpdateCheckResult.stillBroken => strings.updateStillBroken,
    UpdateCheckResult.noInternet => strings.statusNeedsInternet,
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
