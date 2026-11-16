/// Layar status layanan (P6, tugas 1/3/4).
///
/// Menampilkan status kanari saat ini (Normal / Terganggu / Bermasalah),
/// penjelasan singkat, waktu periksa terakhir, dan tombol
/// "Periksa pembaruan".
library;

import 'package:flutter/material.dart';

import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/extractor/canary.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/resilience/check_updates_action.dart';
import 'package:laras/resilience/service_status.dart';

class ServiceStatusScreen extends StatelessWidget {
  const ServiceStatusScreen({super.key, required this.service});

  final ServiceStatusService service;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.serviceStatus)),
      body: ValueListenableBuilder<ServiceStatusSnapshot>(
        valueListenable: service.status,
        builder:
            (BuildContext context, ServiceStatusSnapshot snap, Widget? child) {
              final (String, Color, IconData) label = switch (snap.status) {
                CanaryStatus.ok => (
                  strings.serviceNormal,
                  AppColors.success,
                  Icons.check_circle,
                ),
                CanaryStatus.degraded => (
                  strings.serviceDegraded,
                  AppColors.warning,
                  Icons.warning_amber,
                ),
                CanaryStatus.broken => (
                  strings.serviceBroken,
                  AppColors.error,
                  Icons.error_outline,
                ),
              };
              final String checked = snap.checkedAt == null
                  ? strings.serviceNeverChecked
                  : strings.serviceCheckedAt(
                      formatCheckedTime(snap.checkedAt!),
                    );
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(label.$3, color: label.$2, size: 28),
                      const SizedBox(width: AppSpacing.sm),
                      Text(label.$1, style: theme.textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    strings.serviceExplanation,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    checked,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: snap.checking
                          ? null
                          : () => runCheckForUpdates(context, service),
                      child: Text(
                        snap.checking
                            ? strings.checking
                            : strings.checkForUpdates,
                      ),
                    ),
                  ),
                ],
              );
            },
      ),
    );
  }
}

/// "pukul 10.15" — format manual (tanpa intl, seperti layar lain).
/// Dipakai layar status dan baris status di Pengaturan.
String formatCheckedTime(DateTime time) {
  final String minute = time.minute.toString().padLeft(2, '0');
  return 'pukul ${time.hour}.$minute';
}
