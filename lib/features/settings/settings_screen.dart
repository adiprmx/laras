/// Layar Pengaturan (P6, tugas 7) — menggantikan stub "segera hadir".
///
/// Lima kelompok: Pemutaran, Unduhan dan penyimpanan, Layanan, Akun
/// dan data (P8: salinan data + hapus data), App. Kelompok yang
/// layanannya tidak tersedia (tes tanpa scope, atau database gagal
/// dibuka) disembunyikan — tanpa tombol mati.
library;

import 'package:flutter/material.dart';

import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/downloads/download_quality.dart';
import 'package:laras/downloads/downloads_scope.dart';
import 'package:laras/downloads/format_bytes.dart';
import 'package:laras/extractor/canary.dart';
import 'package:laras/features/backup/backup_scope.dart';
import 'package:laras/features/backup/backup_screen.dart';
import 'package:laras/features/backup/backup_service.dart';
import 'package:laras/features/backup/spotify_import.dart';
import 'package:laras/features/onboarding/onboarding_flow.dart';
import 'package:laras/features/storage/storage_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/resilience/app_settings.dart';
import 'package:laras/resilience/check_updates_action.dart';
import 'package:laras/resilience/data_wipe.dart';
import 'package:laras/resilience/resilience_scope.dart';
import 'package:laras/resilience/service_status.dart';

import 'about_screen.dart';
import 'faq_screen.dart';
import 'report_problem.dart';
import 'service_status_screen.dart';
import 'wipe_flow.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final AppSettings? settings = ResilienceScope.settingsOf(context);
    final ServiceStatusService? service =
        ResilienceScope.serviceStatusOf(context);
    final bool hasDownloads = DownloadsScope.downloadsOf(context) != null;
    final BackupService? backup = BackupScope.backupOf(context);
    final SpotifyImportService? spotify = BackupScope.spotifyOf(context);
    final DataWipeService? wipe = ResilienceScope.dataWipeOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        children: <Widget>[
          if (settings != null) ...<Widget>[
            _GroupHeader(title: strings.playbackSettings),
            _DataSaverRow(settings: settings),
          ],
          if (settings != null && hasDownloads) ...<Widget>[
            _GroupHeader(title: strings.downloadStorageSettings),
            _QualityRow(settings: settings),
            _CacheLimitRow(settings: settings),
            _WifiOnlyRow(settings: settings),
            _NavRow(
              title: strings.manageStorage,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const StorageScreen(),
                ),
              ),
            ),
          ],
          if (service != null) ...<Widget>[
            _GroupHeader(title: strings.settingsServiceGroup),
            _ServiceStatusRow(service: service),
            _CheckUpdatesRow(service: service),
          ],
          // P8 (B7.1): kelompok Akun dan data — salinan data + hapus
          // data (hapus data pindah dari kelompok App ke sini).
          if (backup != null || wipe != null) ...<Widget>[
            _GroupHeader(title: strings.settingsAccountGroup),
            if (backup != null)
              _NavRow(
                title: strings.backupTitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => BackupScreen(
                      backup: backup,
                      spotify: spotify,
                    ),
                  ),
                ),
              ),
            if (wipe != null)
              _NavRow(
                title: strings.wipeData,
                danger: true,
                onTap: () => showWipeFlow(
                  context,
                  wipe,
                  backupService: backup,
                ),
              ),
          ],
          _GroupHeader(title: strings.settingsAppGroup),
          _NavRow(
            title: strings.aboutLicenses,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const AboutScreen(),
              ),
            ),
          ),
          _NavRow(
            title: strings.faqTitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const FaqScreen(),
              ),
            ),
          ),
          // P6 (verdict owner 17:56 WIB): buka ulang pengenalan.
          // Alur pengenalan milik Tim Rombak UI-2; entri ini memanggil
          // kontrak publik mereka (saat ini masih stub — koordinator
          // memverifikasi integrasi).
          _NavRow(
            title: strings.showOnboardingAgain,
            onTap: () => OnboardingFlow.show(context),
          ),
          if (ResilienceScope.externalLinksOf(context) != null)
            _NavRow(
              title: strings.reportProblem,
              onTap: () => openReportProblem(context),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.title,
    this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      minTileHeight: AppSizes.settingsRow,
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: danger ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textMuted,
      ),
      onTap: onTap,
    );
  }
}

class _DataSaverRow extends StatelessWidget {
  const _DataSaverRow({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: settings.dataSaver,
      builder: (BuildContext context, bool value, Widget? child) {
        return SwitchListTile(
          title: Text(
            strings.qualityDataSaver,
            style: theme.textTheme.bodyLarge,
          ),
          subtitle: Text(
            strings.dataSaverDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          value: value,
          onChanged: (bool next) => settings.setDataSaver(next),
        );
      },
    );
  }
}

class _WifiOnlyRow extends StatelessWidget {
  const _WifiOnlyRow({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: settings.wifiOnly,
      builder: (BuildContext context, bool value, Widget? child) {
        return SwitchListTile(
          title: Text(
            strings.wifiOnlyDownloads,
            style: theme.textTheme.bodyLarge,
          ),
          subtitle: Text(
            strings.wifiOnlyDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          value: value,
          onChanged: (bool next) async {
            await settings.setWifiOnly(next);
            if (!context.mounted) return;
            // Terapkan langsung ke unduhan yang sedang berjalan.
            await DownloadsScope.downloadsOf(context)?.recheckWifiGate();
          },
        );
      },
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return ValueListenableBuilder<String>(
      valueListenable: settings.defaultQuality,
      builder: (BuildContext context, String value, Widget? child) {
        return _NavRow(
          title: strings.downloadQuality,
          subtitle: _qualityLabel(strings, value),
          onTap: () => _showQualityDialog(context, value),
        );
      },
    );
  }

  Future<void> _showQualityDialog(
    BuildContext context,
    String current,
  ) async {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final String? chosen = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(strings.downloadQuality),
        content: RadioGroup<String>(
          groupValue: current,
          onChanged: (String? value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final String option in <String>[
                kQualityBest,
                kQualityBalanced,
                kQualityDataSaver,
              ])
                RadioListTile<String>(
                  title: Text(_qualityLabel(strings, option)),
                  subtitle: Text(_qualityDesc(strings, option)),
                  value: option,
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.cancel),
          ),
        ],
      ),
    );
    if (chosen == null || chosen == current || !context.mounted) return;
    await settings.setDefaultQuality(chosen);
    if (!context.mounted) return;
    DownloadsScope.downloadsOf(context)?.defaultQuality =
        _qualityFromString(chosen);
  }

  static String _qualityLabel(AppLocalizations strings, String value) {
    switch (value) {
      case kQualityBalanced:
        return strings.qualityBalanced;
      case kQualityDataSaver:
        return strings.qualityDataSaver;
      case kQualityBest:
      default:
        return strings.qualityBest;
    }
  }

  static String _qualityDesc(AppLocalizations strings, String value) {
    switch (value) {
      case kQualityBalanced:
        return strings.qualityBalancedDesc;
      case kQualityDataSaver:
        return strings.qualityDataSaverDesc;
      case kQualityBest:
      default:
        return strings.qualityBestDesc;
    }
  }

  static DownloadQuality _qualityFromString(String value) {
    switch (value) {
      case kQualityBalanced:
        return DownloadQuality.balanced;
      case kQualityDataSaver:
        return DownloadQuality.dataSaver;
      case kQualityBest:
      default:
        return DownloadQuality.best;
    }
  }
}

class _CacheLimitRow extends StatelessWidget {
  const _CacheLimitRow({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final bool hasCache = DownloadsScope.maybeOf(context)?.cache != null;
    if (!hasCache) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: settings.cacheLimitBytes,
      builder: (BuildContext context, int value, Widget? child) {
        return _NavRow(
          title: strings.playedSongsSpace,
          subtitle: formatBytes(value),
          onTap: () => _showLimitDialog(context, value),
        );
      },
    );
  }

  Future<void> _showLimitDialog(BuildContext context, int current) async {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final int? chosen = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(strings.playedSongsSpace),
        content: RadioGroup<int>(
          groupValue: current,
          onChanged: (int? value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final int option in kCacheLimitOptions)
                RadioListTile<int>(
                  title: Text(formatBytes(option)),
                  value: option,
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.cancel),
          ),
        ],
      ),
    );
    if (chosen == null || chosen == current || !context.mounted) return;
    await settings.setCacheLimitBytes(chosen);
    if (!context.mounted) return;
    await DownloadsScope.maybeOf(context)?.cache?.setCacheLimitBytes(chosen);
  }
}

class _ServiceStatusRow extends StatelessWidget {
  const _ServiceStatusRow({required this.service});

  final ServiceStatusService service;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return ValueListenableBuilder<ServiceStatusSnapshot>(
      valueListenable: service.status,
      builder: (
        BuildContext context,
        ServiceStatusSnapshot snap,
        Widget? child,
      ) {
        final String label = switch (snap.status) {
          CanaryStatus.ok => strings.serviceNormal,
          CanaryStatus.degraded => strings.serviceDegraded,
          CanaryStatus.broken => strings.serviceBroken,
        };
        final String checked = snap.checkedAt == null
            ? strings.serviceNeverChecked
            : strings.serviceCheckedAt(formatCheckedTime(snap.checkedAt!));
        return _NavRow(
          title: strings.serviceStatus,
          subtitle: '$label — $checked',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) =>
                  ServiceStatusScreen(service: service),
            ),
          ),
        );
      },
    );
  }
}

class _CheckUpdatesRow extends StatelessWidget {
  const _CheckUpdatesRow({required this.service});

  final ServiceStatusService service;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return ValueListenableBuilder<ServiceStatusSnapshot>(
      valueListenable: service.status,
      builder: (
        BuildContext context,
        ServiceStatusSnapshot snap,
        Widget? child,
      ) {
        return ListTile(
          minTileHeight: AppSizes.settingsRow,
          title: Text(
            snap.checking ? strings.checking : strings.checkForUpdates,
          ),
          trailing: snap.checking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: snap.checking
              ? null
              : () => runCheckForUpdates(context, service),
        );
      },
    );
  }
}
