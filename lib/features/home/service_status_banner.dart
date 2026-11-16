/// Banner status layanan di beranda (P6, tugas 3).
///
/// Tiga tingkat:
/// - ok: tidak ada banner (SizedBox.shrink);
/// - degraded: banner tipis (peringatan kuning);
/// - broken: banner jelas (merah) + tombol "Periksa pembaruan".
library;

import 'package:flutter/material.dart';

import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/extractor/canary.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/resilience/check_updates_action.dart';
import 'package:laras/resilience/service_status.dart';

class ServiceStatusBanner extends StatelessWidget {
  const ServiceStatusBanner({super.key, required this.service});

  final ServiceStatusService service;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return ValueListenableBuilder<ServiceStatusSnapshot>(
      valueListenable: service.status,
      builder:
          (BuildContext context, ServiceStatusSnapshot snap, Widget? child) {
            if (snap.status == CanaryStatus.ok) return const SizedBox.shrink();
            final bool broken = snap.status == CanaryStatus.broken;
            return Container(
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.card),
                ),
                border: Border.all(
                  color: broken ? AppColors.error : AppColors.warning,
                  width: 1,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    broken ? Icons.error_outline : Icons.warning_amber,
                    color: broken ? AppColors.error : AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      broken
                          ? strings.serviceBrokenBanner
                          : strings.serviceDegradedBanner,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (broken)
                    TextButton(
                      onPressed: snap.checking
                          ? null
                          : () => runCheckForUpdates(context, service),
                      child: Text(
                        snap.checking
                            ? strings.checking
                            : strings.checkForUpdates,
                      ),
                    ),
                ],
              ),
            );
          },
    );
  }
}
